# Project Request Protocol: Slot Nonce Validator

## Project Overview

### Purpose
Create a CLI script that validates nonce consistency between slot servers and the AO testnet router by comparing nonce values from two different sources for a list of process IDs.

### Context
The system needs to verify that process states are synchronized across the distributed slot server infrastructure and the AO testnet router. Each process has a nonce value that should match between the slot server's compute endpoint and the router's latest state endpoint.

### Scope
- Read process ID to slot server mappings from `process-map.json`
- Query two HTTP endpoints per process:
  1. Slot server: `https://{target}/{process-id}~process@1.0/compute/at-slot`
  2. AO router: `https://su-router.ao-testnet.xyz/{process-id}/latest`
- Extract nonce values from both responses
- Compare and log differences

## Technical Requirements

### Input Data
- **File**: `process-map.json`
- **Format**: JSON object with key-value pairs
  - Key: Process ID (string)
  - Value: Target slot server URL (string)
- **Example**:
  ```json
  {
    "4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs": "https://state-2.forward.computer"
  }
  ```

### API Endpoints

#### Endpoint 1: Slot Server
- **URL Pattern**: `https://{target}/{process-id}~process@1.0/compute/at-slot`
- **Method**: GET
- **Response**: JSON object containing slot/state information
- **Required Field**: Nonce value (exact path to be determined from API response)

#### Endpoint 2: AO Router
- **URL Pattern**: `https://su-router.ao-testnet.xyz/{process-id}/latest`
- **Method**: GET
- **Response**: JSON object with structure:
  ```json
  {
    "assignment": {
      "tags": [
        { "name": "nonce", "value": "123456" },
        ...
      ]
    }
  }
  ```
- **Required Field**: `assignment.tags.find(tag => tag.name === "nonce").value`

### Runtime Requirements
- **Runtime**: Hype (Lua runtime)
- **Required Module**: HTTP module for making requests
- **Script Type**: CLI executable

### Output Requirements
- Log comparison results for each process
- Display:
  - Process ID
  - Slot server nonce
  - Router nonce
  - Difference/match status
- Format: Human-readable console output

## Solution Proposals

### Solution 1: Sequential Processing with Basic Error Handling

**Architecture**:
```lua
-- Read process-map.json
-- For each process:
--   1. Fetch from slot server
--   2. Parse slot server nonce
--   3. Fetch from AO router
--   4. Parse router nonce
--   5. Compare and log result
```

**Implementation Approach**:
- Single-threaded sequential processing
- Basic try-catch for HTTP errors
- Simple text-based logging
- Store results in array for final summary

**Pros**:
- Simple to implement and understand
- Easy to debug with clear execution flow
- Minimal complexity in error handling
- Predictable memory usage

**Cons**:
- Very slow for 130+ processes (serial HTTP requests)
- No retry mechanism for failed requests
- No progress indication for long-running execution
- Network timeouts can cause complete failure
- Estimated runtime: ~260+ seconds (2 requests × 130 processes × 1s each)

### Solution 2: Concurrent Processing with Promise-like Pattern

**Architecture**:
```lua
-- Read process-map.json
-- Create coroutines for all processes
-- For each process (concurrent):
--   1. Fetch both endpoints in parallel
--   2. Parse both nonces
--   3. Compare and collect result
-- Aggregate and display all results
```

**Implementation Approach**:
- Use Lua coroutines for concurrent HTTP requests
- Batch requests (e.g., 10 concurrent at a time)
- Structured error handling per process
- Progress reporting (completed/total)
- Retry logic for failed requests (max 3 attempts)

**Pros**:
- Significantly faster execution (10-20x improvement)
- Failed processes don't block others
- Better user experience with progress reporting
- Efficient resource utilization
- Estimated runtime: ~15-20 seconds with 10 concurrent requests

**Cons**:
- More complex coroutine management
- Requires understanding of async patterns in Lua
- Potential for resource exhaustion if not properly throttled
- More complex error state management

### Solution 3: Concurrent with Structured Results & Analytics

**Architecture**:
```lua
-- Read process-map.json
-- Create concurrent workers (configurable concurrency)
-- For each process (concurrent):
--   1. Fetch both endpoints with retry + backoff
--   2. Parse and validate responses
--   3. Compare nonces with detailed analysis
-- Generate structured report:
--   - Summary statistics
--   - Mismatches by server
--   - Error breakdown
--   - JSON export option
```

**Implementation Approach**:
- Coroutine-based worker pool with configurable size
- Exponential backoff retry strategy
- Structured result objects (success/failure/mismatch)
- Multiple output formats (console, JSON, CSV)
- Detailed analytics and grouping by slot server

**Pros**:
- Production-ready with comprehensive error handling
- Rich analytics and reporting capabilities
- Configurable concurrency for different environments
- Export capabilities for further analysis
- Retry logic prevents transient failures
- Best observability into system state

**Cons**:
- Most complex implementation
- Requires more extensive testing
- Higher initial development time
- May be over-engineered for simple validation

## Best Solution

**Selected: Solution 2 - Concurrent Processing with Promise-like Pattern**

### Rationale
Solution 2 provides the optimal balance between performance, complexity, and maintainability:

1. **Performance**: With 130 processes in the map, sequential processing (Solution 1) would take 4+ minutes. Concurrent processing reduces this to 15-20 seconds, which is acceptable for a CLI tool.

2. **Complexity**: While more complex than Solution 1, Solution 2 uses well-established patterns (coroutines) without the over-engineering of Solution 3. The codebase remains maintainable and debuggable.

3. **User Experience**: Progress reporting and concurrent execution provide immediate feedback, making the tool feel responsive and professional.

4. **Reliability**: Built-in retry logic handles transient network failures without adding excessive complexity.

5. **Scalability**: The solution can easily handle the current 130 processes and scale to more without significant refactoring.

Solution 3's additional features (analytics, multiple export formats) are valuable but unnecessary for the core validation use case. They can be added incrementally if needed.

## Implementation Steps

### Phase 1: Project Setup
1. **Initialize project structure**
   - Create `validate-nonces.lua` script
   - Set up shebang for hype runtime
   - Add execution permissions

2. **Implement JSON parsing**
   - Create function to read and parse `process-map.json`
   - Validate JSON structure
   - Handle file read errors

### Phase 2: HTTP Client Functions
3. **Implement HTTP request functions**
   - Create `fetchSlotNonce(target, processId)` function
   - Create `fetchRouterNonce(processId)` function
   - Add timeout configuration (default: 10s)
   - Implement basic error handling

4. **Implement response parsing**
   - Create `parseSlotResponse(response)` to extract nonce
   - Create `parseRouterResponse(response)` to extract nonce from tags array
   - Handle malformed JSON responses

### Phase 3: Concurrent Processing
5. **Implement coroutine-based concurrency**
   - Create worker pool with configurable concurrency (default: 10)
   - Implement coroutine spawning for each process
   - Add throttling mechanism to prevent resource exhaustion

6. **Implement retry logic**
   - Add retry wrapper with max 3 attempts
   - Implement exponential backoff (1s, 2s, 4s)
   - Track retry attempts per process

### Phase 4: Comparison & Output
7. **Implement comparison logic**
   - Create `compareNonces(processId, slotNonce, routerNonce)` function
   - Generate structured result objects
   - Categorize results: match, mismatch, error

8. **Implement output formatting**
   - Create progress reporter (completed/total)
   - Format results for console display:
     - Color coding (green=match, red=mismatch, yellow=error)
     - Aligned columns for readability
   - Generate summary statistics

### Phase 5: Testing & Validation
9. **Test with subset of processes**
   - Test with 5 processes first
   - Verify HTTP calls are correct
   - Validate parsing logic

10. **Test error scenarios**
    - Test with invalid process IDs
    - Test with unreachable endpoints
    - Test with malformed responses
    - Verify retry logic works

11. **Full integration test**
    - Run against all 130 processes in `process-map.json`
    - Verify performance meets targets (<30s)
    - Validate output accuracy

### Phase 6: Documentation & CLI
12. **Add CLI enhancements**
    - Add `--concurrency` flag to control parallel requests
    - Add `--verbose` flag for detailed logging
    - Add `--help` flag for usage information
    - Add `--only-mismatches` flag to filter output

13. **Create documentation**
    - Add usage examples to README
    - Document expected output format
    - Add troubleshooting guide

## Success Criteria

### Functional Requirements
- ✅ Successfully reads and parses `process-map.json`
- ✅ Makes HTTP requests to both endpoints for all processes
- ✅ Correctly extracts nonce values from both response formats
- ✅ Accurately compares nonces and identifies mismatches
- ✅ Displays results in clear, readable format

### Performance Requirements
- ✅ Completes validation of all 130 processes in under 30 seconds
- ✅ Handles network failures gracefully with retries
- ✅ Provides progress feedback during execution

### Reliability Requirements
- ✅ Handles HTTP errors without crashing
- ✅ Handles malformed JSON responses
- ✅ Handles missing nonce fields in responses
- ✅ Retries failed requests up to 3 times

### Usability Requirements
- ✅ Clear progress indication during execution
- ✅ Color-coded output for easy visual scanning
- ✅ Summary statistics at completion
- ✅ CLI flags for common options

### Code Quality Requirements
- ✅ Clean, readable code with clear function names
- ✅ Appropriate error messages for common failures
- ✅ Documented functions and modules
- ✅ Follows Lua best practices
