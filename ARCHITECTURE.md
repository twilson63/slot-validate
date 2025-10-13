# Slot Nonce Validator - Technical Architecture

## System Overview

The Slot Nonce Validator is a concurrent HTTP validation tool built on the Hype Lua runtime. It validates nonce consistency across distributed slot servers by making parallel requests to multiple endpoints and aggregating results.

### High-Level Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                    Slot Nonce Validator                       │
│                                                               │
│  ┌─────────────┐    ┌──────────────┐    ┌────────────────┐  │
│  │ CLI Parser  │───▶│ JSON Loader  │───▶│ Worker Pool    │  │
│  │ (Arguments) │    │ (Data Input) │    │ (Concurrency)  │  │
│  └─────────────┘    └──────────────┘    └────────┬───────┘  │
│                                                   │           │
│                          ┌────────────────────────┘           │
│                          │                                    │
│  ┌───────────────────────▼──────────────────────────────┐    │
│  │           HTTP Client with Retry Logic               │    │
│  │  ┌──────────────┐          ┌──────────────┐         │    │
│  │  │ Slot Server  │          │  AO Router   │         │    │
│  │  │   Fetcher    │          │   Fetcher    │         │    │
│  │  └──────┬───────┘          └──────┬───────┘         │    │
│  └─────────┼──────────────────────────┼─────────────────┘    │
│            │                          │                       │
│  ┌─────────▼──────────────────────────▼─────────────────┐    │
│  │            Result Aggregator                          │    │
│  │  • Collect responses                                  │    │
│  │  • Compare nonces                                     │    │
│  │  • Track errors                                       │    │
│  │  • Calculate statistics                               │    │
│  └─────────────────────────┬─────────────────────────────┘    │
│                            │                                  │
│  ┌─────────────────────────▼─────────────────────────────┐    │
│  │           Output Formatter                            │    │
│  │  • Progress display                                   │    │
│  │  • Result formatting                                  │    │
│  │  • Summary generation                                 │    │
│  └───────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────┘
```

## Component Breakdown

### 1. CLI Parser & Argument Handler

**Purpose**: Parse command-line arguments and validate configuration

**Inputs**:
- Command-line arguments from user
- Default configuration values

**Outputs**:
- Configuration object with validated parameters

**Logic**:
```lua
-- Parse arguments
local config = {
    concurrency = 10,           -- Default concurrent requests
    verbose = false,            -- Detailed logging
    only_mismatches = false,    -- Filter output
    help = false                -- Show help
}

-- Parse --key=value and --flag formats
for _, arg in ipairs(args) do
    if arg:match("^--concurrency=(%d+)$") then
        config.concurrency = tonumber(arg:match("(%d+)"))
    elseif arg == "--verbose" then
        config.verbose = true
    -- ... more options
    end
end

-- Validate ranges
if config.concurrency < 1 or config.concurrency > 50 then
    error("Concurrency must be between 1 and 50")
end
```

**Error Handling**:
- Invalid argument format → Show help and exit
- Out-of-range values → Display error with valid range
- Unknown flags → Warning (non-fatal)

---

### 2. JSON Loader

**Purpose**: Load and parse the process-to-server mapping file

**Inputs**:
- File path: `process-map.json`

**Outputs**:
- Table of process mappings: `{ [process_id] = server_url }`

**Implementation**:
```lua
function load_process_map(filepath)
    -- Read file
    local file = io.open(filepath, "r")
    if not file then
        error("File not found: " .. filepath)
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Parse JSON
    local data = json.decode(content)
    
    -- Validate structure
    if type(data) ~= "table" then
        error("Invalid JSON: expected object")
    end
    
    -- Validate entries
    local count = 0
    for process_id, server_url in pairs(data) do
        if type(process_id) ~= "string" or type(server_url) ~= "string" then
            error("Invalid entry: both keys and values must be strings")
        end
        count = count + 1
    end
    
    return data, count
end
```

**Error Handling**:
- File not found → Exit with error
- Invalid JSON syntax → Show parse error with line number
- Invalid structure → Explain expected format
- Empty file → Warning and exit

---

### 3. HTTP Client with Retry Logic

**Purpose**: Fetch nonce values from slot servers and AO router with automatic retry

**Components**:

#### 3.1 Slot Server Fetcher

**Endpoint Format**:
```
https://{server}/{process_id}~process@1.0/compute/at-slot
```

**Response Format**: Plain text integer
```
14204
```

**Implementation**:
```lua
function fetch_slot_nonce(server_url, process_id)
    local url = string.format(
        "%s/%s~process@1.0/compute/at-slot",
        server_url,
        process_id
    )
    
    local response = http.get(url, {
        timeout = 10000,  -- 10 second timeout
        follow_redirects = false
    })
    
    if response.status ~= 200 then
        return nil, string.format("HTTP %d", response.status)
    end
    
    local nonce = tonumber(response.body)
    if not nonce then
        return nil, "Invalid nonce format"
    end
    
    return nonce, nil
end
```

#### 3.2 AO Router Fetcher

**Endpoint Format**:
```
https://su-router.ao-testnet.xyz/{process_id}/latest
```

**Response Format**: JSON object
```json
{
  "assignment": {
    "tags": [
      {"name": "Nonce", "value": "14204"},
      ...
    ]
  }
}
```

**Implementation**:
```lua
function fetch_router_nonce(process_id)
    local url = string.format(
        "https://su-router.ao-testnet.xyz/%s/latest",
        process_id
    )
    
    local response = http.get(url, {
        timeout = 10000,
        follow_redirects = true  -- Handle 307 redirects
    })
    
    if response.status ~= 200 then
        return nil, string.format("HTTP %d", response.status)
    end
    
    local data = json.decode(response.body)
    
    -- Navigate to assignment.tags array
    if not data.assignment or not data.assignment.tags then
        return nil, "Missing assignment data"
    end
    
    -- Find Nonce tag
    for _, tag in ipairs(data.assignment.tags) do
        if tag.name == "Nonce" then
            local nonce = tonumber(tag.value)
            if not nonce then
                return nil, "Invalid nonce value"
            end
            return nonce, nil
        end
    end
    
    return nil, "Nonce tag not found"
end
```

#### 3.3 Retry Wrapper

**Strategy**: Exponential backoff with max retries

**Implementation**:
```lua
function with_retry(func, max_attempts, backoff_ms)
    max_attempts = max_attempts or 3
    backoff_ms = backoff_ms or 1000
    
    for attempt = 1, max_attempts do
        local result, error = func()
        
        if result then
            return result, nil
        end
        
        -- Don't retry on final attempt
        if attempt < max_attempts then
            -- Exponential backoff: 1s, 2s, 4s
            local wait = backoff_ms * (2 ^ (attempt - 1))
            sleep(wait)
        end
    end
    
    return nil, error
end
```

**Error Handling**:
- Network timeout → Retry with backoff
- HTTP 5xx errors → Retry
- HTTP 4xx errors → No retry (client error)
- Parse errors → No retry (data issue)

---

### 4. Coroutine Worker Pool

**Purpose**: Manage concurrent HTTP requests with controlled parallelism

**Architecture**:
```
┌────────────────────────────────────────────┐
│          Worker Pool Manager               │
│  ┌──────────────────────────────────────┐  │
│  │  Work Queue (Process IDs)            │  │
│  │  [pid1, pid2, pid3, ..., pid130]     │  │
│  └─────────────┬────────────────────────┘  │
│                │                            │
│    ┌───────────┼───────────┐               │
│    │           │           │               │
│    ▼           ▼           ▼               │
│  ┌───┐       ┌───┐       ┌───┐            │
│  │ W1│       │ W2│  ...  │WN │  Workers   │
│  └─┬─┘       └─┬─┘       └─┬─┘            │
│    │           │           │               │
│    ▼           ▼           ▼               │
│  [HTTP]     [HTTP]      [HTTP]             │
│    │           │           │               │
│    └───────────┴───────────┘               │
│                │                            │
│         ┌──────▼───────┐                   │
│         │ Result Queue │                   │
│         └──────────────┘                   │
└────────────────────────────────────────────┘
```

**Implementation**:
```lua
function create_worker_pool(concurrency)
    local workers = {}
    local results = {}
    local active = 0
    
    return {
        spawn = function(task)
            -- Wait if at capacity
            while active >= concurrency do
                coroutine.yield()
            end
            
            active = active + 1
            
            local worker = coroutine.create(function()
                local result = task()
                table.insert(results, result)
                active = active - 1
            end)
            
            table.insert(workers, worker)
            coroutine.resume(worker)
        end,
        
        wait_all = function()
            -- Resume all workers until complete
            while active > 0 do
                for _, worker in ipairs(workers) do
                    if coroutine.status(worker) ~= "dead" then
                        coroutine.resume(worker)
                    end
                end
                coroutine.yield()
            end
            return results
        end
    }
end
```

**Concurrency Model**:
- **Cooperative multitasking**: Lua coroutines
- **Throttling**: Limit active workers to `--concurrency` value
- **Non-blocking I/O**: HTTP requests yield during network wait
- **Fair scheduling**: Round-robin worker resumption

---

### 5. Result Aggregator

**Purpose**: Collect, compare, and categorize validation results

**Data Structures**:
```lua
-- Individual result
local result = {
    process_id = "4hXj_E...",
    server_url = "https://state-2.forward.computer",
    slot_nonce = 14204,
    router_nonce = 14204,
    status = "match",  -- "match", "mismatch", "error"
    error = nil,       -- Error message if status = "error"
    difference = 0     -- slot_nonce - router_nonce
}

-- Aggregate statistics
local stats = {
    total = 130,
    matches = 125,
    mismatches = 3,
    errors = 2,
    start_time = os.time(),
    end_time = os.time()
}
```

**Comparison Logic**:
```lua
function compare_nonces(process_id, server_url, slot_nonce, router_nonce)
    local result = {
        process_id = process_id,
        server_url = server_url,
        slot_nonce = slot_nonce,
        router_nonce = router_nonce
    }
    
    -- Handle errors
    if not slot_nonce or not router_nonce then
        result.status = "error"
        result.error = "Failed to fetch nonce"
        return result
    end
    
    -- Compare values
    if slot_nonce == router_nonce then
        result.status = "match"
        result.difference = 0
    else
        result.status = "mismatch"
        result.difference = slot_nonce - router_nonce
    end
    
    return result
end
```

**Grouping & Analysis**:
```lua
function analyze_results(results)
    local by_server = {}
    local by_status = {match = {}, mismatch = {}, error = {}}
    
    for _, result in ipairs(results) do
        -- Group by server
        if not by_server[result.server_url] then
            by_server[result.server_url] = {
                total = 0,
                matches = 0,
                mismatches = 0,
                errors = 0
            }
        end
        by_server[result.server_url].total = 
            by_server[result.server_url].total + 1
        by_server[result.server_url][result.status .. "es"] = 
            by_server[result.server_url][result.status .. "es"] + 1
        
        -- Group by status
        table.insert(by_status[result.status], result)
    end
    
    return by_server, by_status
end
```

---

### 6. Output Formatter

**Purpose**: Display progress and results in human-readable format

**Components**:

#### 6.1 Progress Display

```lua
function update_progress(completed, total)
    local percent = math.floor((completed / total) * 100)
    local bar_width = 40
    local filled = math.floor((completed / total) * bar_width)
    
    local bar = string.rep("=", filled) .. string.rep(" ", bar_width - filled)
    
    io.write(string.format(
        "\rProgress: [%s] %d/%d (%d%%)",
        bar, completed, total, percent
    ))
    io.flush()
end
```

#### 6.2 Result Formatting

**Match Display**:
```
✓ 4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs
  Slot Server: 14204
  AO Router:   14204
  Status:      MATCH
```

**Mismatch Display**:
```
✗ DM3FoZUq_yebASPhgd8pEIRIzDW6muXEhxz5-JwbZwo
  Server:      https://state-2.forward.computer
  Slot Nonce:  8523
  Router Nonce: 8520
  Difference:  +3 (slot ahead)
  Status:      MISMATCH
```

**Error Display**:
```
⚠ qNvAoz0TgcH7DMg8BCVn8jF32QH5L6T29VjHxhHqqGE
  Server:      https://state-2.forward.computer
  Slot Nonce:  ERROR (timeout)
  Router Nonce: 5642
  Status:      ERROR
```

#### 6.3 Summary Generation

```lua
function generate_summary(stats, execution_time)
    print("\n\nSummary:")
    print("--------")
    print(string.format("Total Processes:  %d", stats.total))
    print(string.format("Matches:          %d (%.1f%%)",
        stats.matches, (stats.matches / stats.total) * 100))
    print(string.format("Mismatches:       %d (%.1f%%)",
        stats.mismatches, (stats.mismatches / stats.total) * 100))
    print(string.format("Errors:           %d (%.1f%%)",
        stats.errors, (stats.errors / stats.total) * 100))
    print(string.format("Execution Time:   %.1fs", execution_time))
    
    -- Exit code based on results
    if stats.mismatches > 0 then
        os.exit(1)  -- Mismatches detected
    elseif stats.errors > 0 then
        os.exit(2)  -- Errors occurred
    else
        os.exit(0)  -- Success
    end
end
```

---

## Data Flow Diagram

### Request-Response Flow

```
User Input
    │
    ├─▶ CLI Args ──▶ Config Validation
    └─▶ process-map.json ──▶ JSON Parser
                               │
    ┌──────────────────────────┘
    │
    ▼
Process Queue: [PID1, PID2, ..., PID130]
    │
    ├─────┬─────┬─────┬─────┐ Worker Pool
    │     │     │     │     │  (Concurrency=10)
    ▼     ▼     ▼     ▼     ▼
  ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐
  │ W1│ │ W2│ │ W3│ │...│ │W10│
  └─┬─┘ └─┬─┘ └─┬─┘ └─┬─┘ └─┬─┘
    │     │     │     │     │
    ├─────┴─────┴─────┴─────┘
    │
    ▼
For each PID:
    │
    ├─▶ Slot Server Request ─────┐
    │   GET /{PID}~process@...    │
    │   ↓                          │
    │   Response: "14204"          │ Parallel
    │                              │ Execution
    └─▶ Router Request ────────────┤
        GET /latest               │
        ↓                          │
        Response: JSON ───────────┘
        Parse: assignment.tags
        │
        ▼
    Compare Nonces
        │
        ├─▶ Match     ──┐
        ├─▶ Mismatch  ──┼─▶ Result Queue
        └─▶ Error     ──┘
                │
                ▼
    Aggregate Results
        │
        ├─▶ Calculate Statistics
        ├─▶ Group by Server
        └─▶ Group by Status
                │
                ▼
    Format & Display
        │
        ├─▶ Progress Bar
        ├─▶ Result Details
        └─▶ Summary Stats
                │
                ▼
            Exit Code
```

---

## API Endpoint Details

### Slot Server Endpoint

**URL Pattern**:
```
https://{server}/{process_id}~process@1.0/compute/at-slot
```

**Method**: `GET`

**Headers**:
```
Accept: text/plain
```

**Response**:
- **Status**: 200 OK
- **Content-Type**: `text/plain`
- **Body**: Plain integer (5-10 bytes)
  ```
  14204
  ```

**Error Responses**:
- `404 Not Found`: Process doesn't exist on this server
- `500 Internal Server Error`: Server issue
- `503 Service Unavailable`: Server overloaded
- Timeout: Network issue or server unresponsive

**Performance**:
- Average response time: 50-150ms
- Response size: ~5 bytes
- Efficiency: Optimal for nonce-only queries

---

### AO Router Endpoint

**URL Pattern**:
```
https://su-router.ao-testnet.xyz/{process_id}/latest
```

**Method**: `GET`

**Headers**:
```
Accept: application/json
```

**Response Behavior**:
1. **Initial Response**: `307 Temporary Redirect`
   - Redirects to specific SU server: `https://su201.ao-testnet.xyz/{process_id}/latest`
   
2. **Final Response** (after redirect): `200 OK`
   - **Content-Type**: `application/json`
   - **Body**: Full assignment data (~3.5 KB)

**Response Structure**:
```json
{
  "message": {
    "id": "...",
    "tags": [...]
  },
  "assignment": {
    "id": "...",
    "tags": [
      {"name": "Process", "value": "..."},
      {"name": "Nonce", "value": "14204"},
      {"name": "Block-Height", "value": "..."},
      {"name": "Timestamp", "value": "..."}
    ]
  }
}
```

**Nonce Extraction Path**:
```
.assignment.tags[] | select(.name == "Nonce") | .value
```

**Error Responses**:
```json
{
  "error": "NotFound(\"Process scheduler not found\")"
}
```

**Performance**:
- Average response time: 100-300ms (includes redirect)
- Response size: ~3.5 KB
- Overhead: 200x larger than slot server response

---

## Error Handling Strategy

### Error Categories

| Category | Strategy | Retry | User Impact |
|----------|----------|-------|-------------|
| Network Timeout | Exponential backoff retry | Yes (3x) | Transient - should recover |
| HTTP 5xx Server Error | Exponential backoff retry | Yes (3x) | Server issue - may recover |
| HTTP 4xx Client Error | No retry, log error | No | Invalid request - permanent |
| JSON Parse Error | No retry, log error | No | Data corruption - permanent |
| Missing Nonce Field | No retry, log error | No | API change - permanent |
| File Not Found | Immediate exit | No | Configuration error - fatal |

### Retry Configuration

```lua
local RETRY_CONFIG = {
    max_attempts = 3,
    base_backoff_ms = 1000,
    backoff_multiplier = 2,
    max_backoff_ms = 8000,
    retryable_status_codes = {500, 502, 503, 504}
}
```

### Error Propagation

```
Low-Level Error
    │
    ├─▶ HTTP Error ──▶ Retry Logic ──▶ Success or Fail
    │                                    │
    │                                    ▼
    └─▶ Parse Error ─────────────────▶ Fail
                                        │
                                        ▼
                                   Worker Result
                                        │
                                        ├─▶ Status: "error"
                                        └─▶ Error Message
                                             │
                                             ▼
                                        Result Display
                                             │
                                             ├─▶ ⚠ Warning Icon
                                             ├─▶ Error Details
                                             └─▶ Included in Stats
                                                  │
                                                  ▼
                                             Exit Code: 2
```

---

## Performance Considerations

### Concurrency Tuning

**Formula for Optimal Concurrency**:
```
optimal_concurrency = min(
    process_count / target_time,
    max_server_capacity,
    system_resource_limit
)
```

**Example**:
- 130 processes
- Target: 20 seconds
- Avg request time: 200ms
- Optimal: 130 / (20 / 0.2) = 130 / 100 = ~13 concurrent requests

**Trade-offs**:
| Concurrency | Execution Time | Memory | Server Load |
|-------------|----------------|--------|-------------|
| 5 | 35-40s | Low | Very Low |
| 10 (default) | 20-25s | Low | Low |
| 20 | 15-18s | Medium | Medium |
| 30 | 12-15s | Medium | High |
| 50 | 10-12s | High | Very High |

### Memory Usage

**Per-Process Overhead**:
- Result object: ~200 bytes
- HTTP buffers: ~4 KB per active request
- Total: `(process_count × 200) + (concurrency × 4096)` bytes

**Example** (130 processes, concurrency=10):
```
(130 × 200) + (10 × 4096) = 26KB + 40KB = 66KB
```

**Peak Memory**: ~5-10 MB (includes Lua runtime and libraries)

### Network Optimization

**Bandwidth Usage**:
- Slot server response: ~5 bytes
- Router response: ~3.5 KB
- Total per process: ~3.5 KB × 2 requests = ~7 KB
- Total: 130 × 7 KB = **~910 KB**

**Optimization Strategies**:
1. **Connection Reuse**: HTTP keep-alive for same servers
2. **DNS Caching**: Cache DNS lookups for slot servers
3. **Parallel Requests**: Two requests per process simultaneously
4. **Request Pipelining**: Queue multiple processes per connection

---

## Scalability Analysis

### Horizontal Scaling

**Single Instance Limits**:
- Process count: ~1,000 processes in 2-3 minutes
- Concurrency: Practical limit ~50 (network/server constraints)
- Memory: Scales linearly with process count

**Multi-Instance Strategy**:
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Instance 1 │     │  Instance 2 │     │  Instance N │
│  PID 1-43   │     │  PID 44-86  │     │  PID 87-130 │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┴───────────────────┘
                           │
                      Aggregate Results
```

### Vertical Scaling

**Increasing Concurrency**:
```lua
-- Auto-tune based on process count
local concurrency = math.min(
    math.ceil(process_count / 10),  -- 1 worker per 10 processes
    50                               -- Max 50 workers
)
```

**Benefits**:
- Faster execution for large process sets
- Better resource utilization on powerful machines

**Limitations**:
- Server rate limiting
- Network bandwidth
- Diminishing returns beyond 30-50 concurrent

---

## Security Considerations

### Input Validation

1. **Process IDs**: Validate format (base64-like, 43 characters)
2. **Server URLs**: Validate HTTPS scheme, trusted domains
3. **File Paths**: Prevent path traversal attacks
4. **Arguments**: Sanitize all CLI inputs

### Network Security

1. **HTTPS Only**: Enforce TLS for all requests
2. **Certificate Validation**: Verify SSL certificates
3. **Timeout Enforcement**: Prevent indefinite hangs
4. **Rate Limiting**: Respect server rate limits

### Data Privacy

1. **No Sensitive Data**: Tool reads only public endpoints
2. **No Credentials**: No authentication required
3. **Logging**: Avoid logging full responses (privacy)

---

## Future Enhancements

### Planned Features

1. **Export Formats**:
   - JSON output: `--output=results.json`
   - CSV export: `--output=results.csv`
   - Machine-readable format for CI/CD

2. **Advanced Analytics**:
   - Trend analysis over time
   - Server health scoring
   - Nonce drift detection

3. **Real-time Monitoring**:
   - Continuous validation mode
   - Alert on mismatches
   - Integration with monitoring systems

4. **Performance Optimizations**:
   - HTTP/2 support
   - Connection pooling
   - Smart retry strategies

5. **Configuration File**:
   - `.nonce-validator.conf` for persistent settings
   - Server whitelisting
   - Custom timeout values

---

## References

- [Hype Runtime Documentation](https://hype.forward.computer)
- [AO Testnet Router API](https://ao-testnet.xyz)
- [Lua Coroutines Guide](https://www.lua.org/manual/5.4/manual.html#2.6)
- [HTTP Status Codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)
