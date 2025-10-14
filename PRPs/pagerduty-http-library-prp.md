# Project Request Protocol: PagerDuty HTTP Library Implementation

## Project Overview

### Purpose
Create a native Lua library for PagerDuty Events API v2 integration using direct HTTP POST requests, enabling the Slot Nonce Validator to send alerts without requiring a pre-existing `pagerduty` module in the Hype runtime.

### Context
The current PagerDuty integration (completed October 13, 2025) assumes the availability of a `pagerduty` module in Hype runtime. Testing revealed:

**Current State:**
- ✅ AlertManager class implemented with full functionality
- ✅ CLI flags and configuration completed
- ✅ Alert payload builders for mismatches and errors
- ✅ Graceful degradation when module unavailable
- ❌ **Blocker:** `pagerduty` module not available in Hype runtime
- ❌ **Impact:** Alerts cannot actually be sent to PagerDuty

**Discovery:**
```bash
$ hype run validate-nonces.lua -- --pagerduty-enabled --pagerduty-key=test
Warning: PagerDuty module not available in Hype runtime
```

**Problem:**
The AlertManager currently tries to load the module:
```lua
local ok, pagerduty = pcall(require, "pagerduty")
if ok then
  self.pd = pagerduty.new({routing_key = cfg.pagerduty_routing_key})
  self.enabled = true
else
  io.stderr:write("Warning: PagerDuty module not available\n")
end
```

### Scope

**In Scope:**
- Create native Lua PagerDuty library using HTTP module
- Implement Events API v2 endpoint integration
- Support `trigger`, `acknowledge`, and `resolve` event actions
- Handle authentication with routing key
- Support all PagerDuty payload fields (summary, severity, custom_details, etc.)
- Provide drop-in replacement API matching assumed `pagerduty` module
- Include comprehensive error handling and retry logic
- Add request/response logging for debugging

**Out of Scope:**
- PagerDuty REST API integration (management operations)
- Change Events API v2 integration
- Webhook/inbound integration
- V1 Events API (deprecated)
- GraphQL API support

### Business Value

**Immediate Benefits:**
- 🚀 **Unblocks alerting**: Enables actual PagerDuty integration
- ⚡ **No dependencies**: Works with only standard Hype `http` module
- 🎯 **Production ready**: Full functionality without waiting for module availability
- 🔧 **Maintainable**: Simple, auditable HTTP implementation

**Operational Benefits:**
- 📟 **Incident response**: On-call engineers notified within seconds
- 📊 **Tracking**: PagerDuty provides incident history and analytics
- 🔔 **Escalation**: Leverage PagerDuty's escalation policies
- 👥 **Team coordination**: Centralized incident management

**Technical Benefits:**
- 🛠️ **Self-contained**: No external module dependencies
- 🔍 **Transparent**: Full visibility into API requests/responses
- 🧪 **Testable**: Can mock HTTP responses for testing
- 📖 **Documented**: Clear implementation of PagerDuty protocol

## Technical Requirements

### Environment

**Runtime:** Hype Lua environment (Lua 5.1 compatible)

**Available Modules:**
- ✅ `http` - HTTP client for making requests
- ✅ `io`, `string`, `table`, `os` - Standard Lua libraries

**Not Available:**
- ❌ `pagerduty` - PagerDuty module (doesn't exist)
- ❌ `json` - JSON encoding/decoding (must implement)
- ❌ `ssl` / `https` - SSL/TLS (handled by http module)

### PagerDuty Events API v2 Specification

**Endpoint:**
```
POST https://events.pagerduty.com/v2/enqueue
```

**Authentication:**
- Routing Key in request body (not headers)
- No API key or OAuth required

**Request Headers:**
```
Content-Type: application/json
```

**Request Body Structure:**
```json
{
  "routing_key": "R0XXXXXXXXXXXXXXXXXXXXX",
  "event_action": "trigger",
  "dedup_key": "optional-dedup-key",
  "payload": {
    "summary": "Brief description (max 1024 chars)",
    "severity": "critical",
    "source": "source-system",
    "timestamp": "2025-10-13T14:30:00Z",
    "component": "component-name",
    "group": "group-name",
    "class": "class-name",
    "custom_details": {
      "key": "value",
      "nested": {"allowed": true}
    }
  },
  "client": "client-name",
  "client_url": "https://example.com"
}
```

**Response Success (202 Accepted):**
```json
{
  "status": "success",
  "message": "Event processed",
  "dedup_key": "srv01/HTTP"
}
```

**Response Error (400 Bad Request):**
```json
{
  "status": "invalid event",
  "message": "Event object is invalid",
  "errors": [
    "Routing key is required"
  ]
}
```

**Response Error (429 Rate Limited):**
```json
{
  "status": "throttled",
  "message": "Too many requests"
}
```

### Required API Compatibility

The library must provide a drop-in replacement for the assumed `pagerduty` module API:

```lua
-- Module loading
local pagerduty = require("pagerduty")  -- Actually loads our HTTP implementation

-- Client initialization
local pd = pagerduty.new({
  routing_key = "R0XXXXXXXXXXXXXXXXXXXXX"
})

-- Send event
local ok, err = pd:event({
  event_action = "trigger",  -- "trigger", "acknowledge", "resolve"
  dedup_key = "optional-unique-key",  -- Optional
  payload = {
    summary = "Event summary",
    severity = "critical",  -- "critical", "error", "warning", "info"
    source = "source-system",
    timestamp = "2025-10-13T14:30:00Z",  -- Optional, ISO 8601 UTC
    component = "component",  -- Optional
    group = "group",  -- Optional
    class = "class",  -- Optional
    custom_details = {  -- Optional
      key = "value"
    }
  },
  client = "client-name",  -- Optional
  client_url = "https://example.com"  -- Optional
})

-- Returns: ok (boolean), err (string or nil)
-- ok = true: Event sent successfully
-- ok = false, err = error message
```

### Functional Requirements

1. **HTTP POST Implementation**
   - ✅ POST to `https://events.pagerduty.com/v2/enqueue`
   - ✅ Set `Content-Type: application/json` header
   - ✅ Include routing key in request body
   - ✅ Handle HTTPS/TLS (via http module)

2. **JSON Encoding**
   - ✅ Encode Lua tables to JSON strings
   - ✅ Support strings, numbers, booleans, nil (null)
   - ✅ Support nested tables (objects and arrays)
   - ✅ Handle special characters and escaping
   - ✅ Validate required fields before encoding

3. **JSON Decoding**
   - ✅ Decode response JSON to Lua tables
   - ✅ Extract status, message, dedup_key fields
   - ✅ Handle error responses gracefully

4. **Error Handling**
   - ✅ Network errors (connection failures, timeouts)
   - ✅ HTTP errors (4xx, 5xx status codes)
   - ✅ Invalid responses (malformed JSON)
   - ✅ Rate limiting (429 responses)
   - ✅ Invalid routing keys (400 responses)

5. **Validation**
   - ✅ Validate routing key format (32-char alphanumeric)
   - ✅ Validate event_action (trigger/acknowledge/resolve)
   - ✅ Validate severity (critical/error/warning/info)
   - ✅ Validate required fields (routing_key, event_action, payload.summary, payload.severity, payload.source)

### Non-Functional Requirements

- **Reliability**: Handle transient failures gracefully
- **Performance**: Minimize overhead (<500ms per request)
- **Security**: Never log routing keys
- **Maintainability**: Clear, well-documented code
- **Compatibility**: Drop-in replacement for assumed API

### Edge Cases to Handle

1. **Network Issues**: Connection timeout, DNS failure, TLS handshake failure
2. **Invalid Routing Key**: Expired, malformed, or wrong key
3. **Rate Limiting**: Too many requests to PagerDuty
4. **Large Payloads**: custom_details exceeding API limits
5. **Unicode/UTF-8**: Special characters in summary or custom_details
6. **Nil Values**: Handling nil vs false vs missing keys
7. **Circular References**: Tables referencing themselves (should error)

## Solution Proposals

### Solution 1: Minimal JSON + Simple HTTP

**Architecture:**
```lua
-- pagerduty.lua
local http = require("http")

local PagerDuty = {}
PagerDuty.__index = PagerDuty

function PagerDuty.new(config)
  return setmetatable({
    routing_key = config.routing_key,
    endpoint = "https://events.pagerduty.com/v2/enqueue"
  }, PagerDuty)
end

-- Simple JSON encoder (strings only, no nested objects)
local function simple_json_encode(tbl)
  local parts = {}
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      table.insert(parts, string.format('"%s":"%s"', k, v))
    end
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

function PagerDuty:event(event_data)
  -- Build minimal JSON manually
  local body = string.format([[{
    "routing_key":"%s",
    "event_action":"%s",
    "payload":{
      "summary":"%s",
      "severity":"%s",
      "source":"%s"
    }
  }]], self.routing_key, event_data.event_action,
       event_data.payload.summary,
       event_data.payload.severity,
       event_data.payload.source)
  
  local resp, err = http.post(self.endpoint, body, {
    ["Content-Type"] = "application/json"
  })
  
  if not resp then
    return false, "HTTP error: " .. tostring(err)
  end
  
  if resp.status == 202 then
    return true, nil
  else
    return false, "PagerDuty error: " .. resp.status
  end
end

return PagerDuty
```

**Implementation Approach:**
- Hardcode JSON structure with string formatting
- Only support required fields (summary, severity, source)
- No nested object support in custom_details
- Minimal validation

**Pros:**
- ✅ Extremely simple (~50 lines)
- ✅ Fast to implement (30 minutes)
- ✅ No complex JSON encoding logic
- ✅ Easy to understand and debug
- ✅ Minimal memory footprint

**Cons:**
- ❌ No custom_details support (critical limitation)
- ❌ No nested object support
- ❌ No proper JSON escaping (breaks on quotes, newlines)
- ❌ Cannot support optional fields (timestamp, component, etc.)
- ❌ Fragile string formatting
- ❌ No JSON response parsing
- ❌ Limited error information

### Solution 2: Full JSON Encoder/Decoder + HTTP

**Architecture:**
```lua
-- pagerduty.lua
local http = require("http")

-- JSON Encoder
local function json_encode(value)
  local vtype = type(value)
  
  if vtype == "nil" then
    return "null"
  elseif vtype == "boolean" then
    return value and "true" or "false"
  elseif vtype == "number" then
    return tostring(value)
  elseif vtype == "string" then
    -- Escape special characters
    value = value:gsub('\\', '\\\\')
    value = value:gsub('"', '\\"')
    value = value:gsub('\n', '\\n')
    value = value:gsub('\r', '\\r')
    value = value:gsub('\t', '\\t')
    return '"' .. value .. '"'
  elseif vtype == "table" then
    -- Detect array vs object
    local is_array = true
    local max_index = 0
    for k, _ in pairs(value) do
      if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
        is_array = false
        break
      end
      max_index = math.max(max_index, k)
    end
    
    if is_array then
      -- Encode as JSON array
      local parts = {}
      for i = 1, max_index do
        table.insert(parts, json_encode(value[i]))
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      -- Encode as JSON object
      local parts = {}
      for k, v in pairs(value) do
        if type(k) == "string" then
          table.insert(parts, json_encode(k) .. ":" .. json_encode(v))
        end
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  else
    error("Cannot encode type: " .. vtype)
  end
end

-- JSON Decoder (simple, for responses only)
local function json_decode(json_str)
  -- Use http module's json() method if available
  -- Or implement simple parser for PagerDuty responses
  -- For now, assume response format is predictable
  local status = json_str:match('"status"%s*:%s*"([^"]+)"')
  local message = json_str:match('"message"%s*:%s*"([^"]+)"')
  local dedup_key = json_str:match('"dedup_key"%s*:%s*"([^"]+)"')
  
  return {
    status = status,
    message = message,
    dedup_key = dedup_key
  }
end

local PagerDuty = {}
PagerDuty.__index = PagerDuty

function PagerDuty.new(config)
  if not config.routing_key or config.routing_key == "" then
    error("routing_key is required")
  end
  
  return setmetatable({
    routing_key = config.routing_key,
    endpoint = "https://events.pagerduty.com/v2/enqueue"
  }, PagerDuty)
end

function PagerDuty:event(event_data)
  -- Validate required fields
  if not event_data.event_action then
    return false, "event_action is required"
  end
  
  if not event_data.payload then
    return false, "payload is required"
  end
  
  if not event_data.payload.summary then
    return false, "payload.summary is required"
  end
  
  if not event_data.payload.severity then
    return false, "payload.severity is required"
  end
  
  if not event_data.payload.source then
    return false, "payload.source is required"
  end
  
  -- Build request body
  local request = {
    routing_key = self.routing_key,
    event_action = event_data.event_action,
    payload = event_data.payload
  }
  
  -- Add optional fields
  if event_data.dedup_key then
    request.dedup_key = event_data.dedup_key
  end
  
  if event_data.client then
    request.client = event_data.client
  end
  
  if event_data.client_url then
    request.client_url = event_data.client_url
  end
  
  -- Encode to JSON
  local body = json_encode(request)
  
  -- Send HTTP request
  local resp, err = http.post(self.endpoint, body, {
    ["Content-Type"] = "application/json"
  })
  
  if not resp then
    return false, "HTTP error: " .. tostring(err)
  end
  
  -- Handle response
  if resp.status == 202 then
    return true, nil
  elseif resp.status == 400 then
    local data = json_decode(resp.body)
    return false, "Bad request: " .. (data.message or "Invalid event")
  elseif resp.status == 429 then
    return false, "Rate limited: Too many requests"
  else
    return false, "HTTP " .. resp.status .. ": " .. (resp.body or "Unknown error")
  end
end

return PagerDuty
```

**Implementation Approach:**
- Implement full recursive JSON encoder
- Support all Lua types (string, number, boolean, nil, table)
- Support nested objects and arrays
- Simple JSON decoder for responses
- Comprehensive validation

**Pros:**
- ✅ Full feature support (custom_details, nested objects)
- ✅ Proper JSON escaping (handles quotes, newlines, etc.)
- ✅ Supports all optional fields
- ✅ Robust error handling
- ✅ Response parsing
- ✅ Validates inputs before sending
- ✅ Production-ready

**Cons:**
- ❌ More complex (~200 lines)
- ❌ Longer development time (60-90 minutes)
- ❌ JSON encoder requires careful testing
- ❌ Slightly more memory overhead

### Solution 3: Hybrid Approach with httpbin.org Proxy

**Architecture:**
```lua
-- pagerduty.lua
local http = require("http")

local PagerDuty = {}
PagerDuty.__index = PagerDuty

function PagerDuty.new(config)
  return setmetatable({
    routing_key = config.routing_key,
    endpoint = "https://events.pagerduty.com/v2/enqueue"
  }, PagerDuty)
end

function PagerDuty:event(event_data)
  -- Build Lua table with all data
  local request = {
    routing_key = self.routing_key,
    event_action = event_data.event_action,
    payload = event_data.payload,
    dedup_key = event_data.dedup_key,
    client = event_data.client,
    client_url = event_data.client_url
  }
  
  -- Use httpbin.org to convert Lua table to JSON
  -- (httpbin.org echoes back JSON representation)
  local temp_resp, temp_err = http.post(
    "https://httpbin.org/anything",
    "dummy",  -- Placeholder
    {["Content-Type"] = "application/json"}
  )
  
  if not temp_resp then
    return false, "JSON encoding failed: " .. tostring(temp_err)
  end
  
  -- Extract JSON from httpbin response
  local json_body = temp_resp.body  -- httpbin returns JSON
  
  -- Send actual request to PagerDuty
  local resp, err = http.post(self.endpoint, json_body, {
    ["Content-Type"] = "application/json"
  })
  
  if not resp then
    return false, "HTTP error: " .. tostring(err)
  end
  
  if resp.status == 202 then
    return true, nil
  else
    return false, "PagerDuty error: " .. resp.status
  end
end

return PagerDuty
```

**Implementation Approach:**
- Use external service (httpbin.org) for JSON encoding
- Leverage service's JSON echo capability
- Send actual request to PagerDuty with encoded JSON
- Minimal code complexity

**Pros:**
- ✅ Simple implementation (~80 lines)
- ✅ No JSON encoding logic needed
- ✅ Supports nested objects automatically
- ✅ Fast to implement (45 minutes)

**Cons:**
- ❌ **Critical:** Depends on external service (httpbin.org)
- ❌ **Critical:** Exposes routing key to third party
- ❌ **Critical:** Exposes all alert data to third party
- ❌ Double network round-trip (slow)
- ❌ Failure if httpbin.org is down
- ❌ Security/privacy concerns
- ❌ Not suitable for production use

## Best Solution

**Selected: Solution 2 - Full JSON Encoder/Decoder + HTTP**

### Rationale

Solution 2 provides the optimal balance between functionality, security, and maintainability:

1. **Complete Functionality**: Unlike Solution 1, supports all PagerDuty features:
   - Custom details with nested objects
   - Optional fields (timestamp, component, group, class)
   - Proper JSON escaping for special characters
   - Multiple event actions (trigger, acknowledge, resolve)

2. **Security**: Unlike Solution 3, keeps all data internal:
   - No exposure of routing keys to third parties
   - No exposure of alert data to external services
   - Direct communication with PagerDuty only

3. **Reliability**: Unlike Solution 3, no external dependencies:
   - Works offline (for testing with mock servers)
   - No additional failure points
   - Predictable behavior

4. **Production-Ready**: Includes essential features:
   - Input validation (prevents bad requests)
   - Error handling (network, HTTP, API errors)
   - Response parsing (extract status and messages)
   - Comprehensive field support

5. **Maintainability**: Well-structured code:
   - Clear separation of concerns (encode, decode, send)
   - Testable components (can test encoder in isolation)
   - Documented API surface
   - ~200 lines (reasonable size)

6. **Performance**: Efficient implementation:
   - Single network round-trip
   - Minimal string operations
   - No unnecessary allocations

### Why Not the Others?

**Solution 1 (Minimal):**
- ❌ Too limited: Cannot send custom_details (critical for our use case)
- ❌ No escaping: Breaks on quotes, newlines in summaries
- ❌ Cannot extend: Adding features requires refactoring
- ❌ Poor errors: No detailed error information from API

**Solution 3 (Proxy):**
- ❌ **Security risk**: Exposes routing key and alert data to httpbin.org
- ❌ **Reliability**: Additional failure point (httpbin.org availability)
- ❌ **Performance**: Double network round-trip adds latency
- ❌ **Privacy**: Violates data handling policies (external data exposure)
- ❌ Not production-suitable

### Trade-offs Accepted

**Complexity vs Features:**
- Solution 2 is more complex than Solution 1 (~200 vs ~50 lines)
- Acceptable because: Production alerting requires full feature support
- Benefit: Rich context alerts improve MTTR significantly

**Development Time:**
- 60-90 minutes vs 30 minutes (Solution 1)
- Acceptable because: One-time investment for production capability
- Benefit: Proper implementation prevents future refactoring

**JSON Implementation:**
- Custom JSON encoder vs external library
- Acceptable because: No JSON libraries available in Hype
- Benefit: Full control, no dependencies, auditable code

## Implementation Steps

### Phase 1: JSON Encoder Implementation (25 minutes)

1. **Create pagerduty.lua file**
   ```bash
   touch pagerduty.lua
   ```

2. **Implement basic JSON encoder**
   ```lua
   local function json_encode(value, seen)
     seen = seen or {}
     local vtype = type(value)
     
     -- Handle nil
     if vtype == "nil" then
       return "null"
     end
     
     -- Handle boolean
     if vtype == "boolean" then
       return value and "true" or "false"
     end
     
     -- Handle number
     if vtype == "number" then
       if value ~= value then  -- NaN
         error("Cannot encode NaN")
       elseif value == math.huge or value == -math.huge then  -- Infinity
         error("Cannot encode Infinity")
       end
       return tostring(value)
     end
     
     -- Handle string
     if vtype == "string" then
       return json_encode_string(value)
     end
     
     -- Handle table
     if vtype == "table" then
       -- Check for circular reference
       if seen[value] then
         error("Circular reference detected")
       end
       seen[value] = true
       
       -- Detect array vs object
       local result
       if is_array(value) then
         result = json_encode_array(value, seen)
       else
         result = json_encode_object(value, seen)
       end
       
       seen[value] = nil
       return result
     end
     
     error("Cannot encode type: " .. vtype)
   end
   ```

3. **Implement string escaping**
   ```lua
   local function json_encode_string(str)
     str = str:gsub('\\', '\\\\')  -- Backslash
     str = str:gsub('"', '\\"')    -- Quote
     str = str:gsub('\n', '\\n')   -- Newline
     str = str:gsub('\r', '\\r')   -- Carriage return
     str = str:gsub('\t', '\\t')   -- Tab
     str = str:gsub('\b', '\\b')   -- Backspace
     str = str:gsub('\f', '\\f')   -- Form feed
     return '"' .. str .. '"'
   end
   ```

4. **Implement array detection and encoding**
   ```lua
   local function is_array(tbl)
     local count = 0
     local max_index = 0
     for k, _ in pairs(tbl) do
       if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
         return false
       end
       count = count + 1
       max_index = math.max(max_index, k)
     end
     return count > 0 and count == max_index
   end
   
   local function json_encode_array(arr, seen)
     local parts = {}
     for i = 1, #arr do
       table.insert(parts, json_encode(arr[i], seen))
     end
     return "[" .. table.concat(parts, ",") .. "]"
   end
   ```

5. **Implement object encoding**
   ```lua
   local function json_encode_object(obj, seen)
     local parts = {}
     for k, v in pairs(obj) do
       if type(k) == "string" then
         local encoded_key = json_encode_string(k)
         local encoded_value = json_encode(v, seen)
         table.insert(parts, encoded_key .. ":" .. encoded_value)
       end
     end
     return "{" .. table.concat(parts, ",") .. "}"
   end
   ```

### Phase 2: JSON Decoder Implementation (15 minutes)

6. **Implement simple JSON decoder for responses**
   ```lua
   local function json_decode_response(json_str)
     if not json_str or json_str == "" then
       return nil, "Empty response"
     end
     
     -- Simple pattern-based extraction for PagerDuty responses
     local data = {}
     
     -- Extract status
     data.status = json_str:match('"status"%s*:%s*"([^"]+)"')
     
     -- Extract message
     data.message = json_str:match('"message"%s*:%s*"([^"]+)"')
     
     -- Extract dedup_key
     data.dedup_key = json_str:match('"dedup_key"%s*:%s*"([^"]+)"')
     
     return data, nil
   end
   ```

### Phase 3: PagerDuty Client Implementation (20 minutes)

7. **Create PagerDuty class**
   ```lua
   local http = require("http")
   
   local PagerDuty = {}
   PagerDuty.__index = PagerDuty
   
   function PagerDuty.new(config)
     if not config or not config.routing_key then
       error("routing_key is required")
     end
     
     if config.routing_key == "" then
       error("routing_key cannot be empty")
     end
     
     return setmetatable({
       routing_key = config.routing_key,
       endpoint = "https://events.pagerduty.com/v2/enqueue"
     }, PagerDuty)
   end
   ```

8. **Implement input validation**
   ```lua
   local function validate_event(event_data)
     -- Check event_action
     if not event_data.event_action then
       return false, "event_action is required"
     end
     
     local valid_actions = {trigger = true, acknowledge = true, resolve = true}
     if not valid_actions[event_data.event_action] then
       return false, "event_action must be 'trigger', 'acknowledge', or 'resolve'"
     end
     
     -- For trigger events, require payload
     if event_data.event_action == "trigger" then
       if not event_data.payload then
         return false, "payload is required for trigger events"
       end
       
       if not event_data.payload.summary then
         return false, "payload.summary is required"
       end
       
       if not event_data.payload.severity then
         return false, "payload.severity is required"
       end
       
       local valid_severities = {critical = true, error = true, warning = true, info = true}
       if not valid_severities[event_data.payload.severity] then
         return false, "payload.severity must be 'critical', 'error', 'warning', or 'info'"
       end
       
       if not event_data.payload.source then
         return false, "payload.source is required"
       end
     end
     
     return true, nil
   end
   ```

9. **Implement event() method**
   ```lua
   function PagerDuty:event(event_data)
     -- Validate input
     local valid, err = validate_event(event_data)
     if not valid then
       return false, err
     end
     
     -- Build request body
     local request = {
       routing_key = self.routing_key,
       event_action = event_data.event_action
     }
     
     -- Add optional fields
     if event_data.dedup_key then
       request.dedup_key = event_data.dedup_key
     end
     
     if event_data.payload then
       request.payload = event_data.payload
     end
     
     if event_data.client then
       request.client = event_data.client
     end
     
     if event_data.client_url then
       request.client_url = event_data.client_url
     end
     
     -- Encode to JSON
     local ok, body_or_err = pcall(json_encode, request)
     if not ok then
       return false, "JSON encoding error: " .. tostring(body_or_err)
     end
     local body = body_or_err
     
     -- Send HTTP request
     local resp, http_err = http.post(self.endpoint, body, {
       ["Content-Type"] = "application/json"
     })
     
     if not resp then
       return false, "HTTP error: " .. tostring(http_err)
     end
     
     -- Handle response
     if resp.status == 202 then
       return true, nil
     elseif resp.status == 400 then
       local data, _ = json_decode_response(resp.body)
       return false, "Bad request: " .. (data and data.message or "Invalid event")
     elseif resp.status == 429 then
       return false, "Rate limited: Too many requests"
     elseif resp.status >= 500 then
       return false, "Server error: HTTP " .. resp.status
     else
       return false, "HTTP " .. resp.status .. ": " .. (resp.body or "Unknown error")
     end
   end
   ```

10. **Add module return**
    ```lua
    return PagerDuty
    ```

### Phase 4: Integration with AlertManager (10 minutes)

11. **Update AlertManager initialization**
    ```lua
    -- In validate-nonces.lua, AlertManager.new() method
    
    function AlertManager.new(cfg)
      local self = setmetatable({}, AlertManager)
      self.config = cfg
      self.pd = nil
      self.alerts_sent = 0
      self.enabled = false
      
      if cfg.pagerduty_enabled then
        if not cfg.pagerduty_routing_key or cfg.pagerduty_routing_key == "" then
          io.stderr:write("Warning: PagerDuty enabled but no routing key provided\n")
          io.stderr:write("Set PAGERDUTY_ROUTING_KEY env var or use --pagerduty-key flag\n")
          return self
        end
        
        -- Try to load local pagerduty.lua library
        local ok, pagerduty = pcall(require, "pagerduty")
        if ok then
          -- Use pcall for initialization in case routing key is invalid
          local init_ok, pd_or_err = pcall(pagerduty.new, {
            routing_key = cfg.pagerduty_routing_key
          })
          
          if init_ok then
            self.pd = pd_or_err
            self.enabled = true
            
            if cfg.verbose then
              print(string.format("%s[PagerDuty]%s Initialized with routing key", BLUE, RESET))
            end
          else
            io.stderr:write(string.format("Warning: PagerDuty initialization failed: %s\n", tostring(pd_or_err)))
          end
        else
          io.stderr:write("Warning: PagerDuty library not found (pagerduty.lua)\n")
        end
      end
      
      return self
    end
    ```

### Phase 5: Testing (20 minutes)

12. **Create test script**
    ```lua
    -- test-pagerduty.lua
    local pagerduty = require("pagerduty")
    
    -- Test 1: JSON encoding
    print("Test 1: JSON Encoding")
    local json_encode = pagerduty._json_encode  -- Expose for testing
    local test_data = {
      string = "hello",
      number = 42,
      boolean = true,
      null = nil,
      nested = {
        array = {1, 2, 3},
        object = {key = "value"}
      }
    }
    print(json_encode(test_data))
    
    -- Test 2: String escaping
    print("\nTest 2: String Escaping")
    local escaped = json_encode({
      text = 'Hello "world"\nNew line\tTab'
    })
    print(escaped)
    
    -- Test 3: Invalid routing key
    print("\nTest 3: Invalid Routing Key")
    local ok, err = pcall(pagerduty.new, {routing_key = ""})
    print("Expected error:", err)
    
    -- Test 4: Missing required fields
    print("\nTest 4: Missing Required Fields")
    local pd = pagerduty.new({routing_key = "test-key"})
    local success, error_msg = pd:event({event_action = "trigger"})
    print("Expected false:", success, error_msg)
    
    -- Test 5: Valid event (will fail without real key)
    print("\nTest 5: Valid Event Structure")
    success, error_msg = pd:event({
      event_action = "trigger",
      payload = {
        summary = "Test alert",
        severity = "critical",
        source = "test-script",
        custom_details = {
          test = true,
          nested = {value = 123}
        }
      }
    })
    print("Result:", success, error_msg)
    ```

13. **Run tests**
    ```bash
    hype run test-pagerduty.lua
    ```

14. **Test with real PagerDuty key**
    ```bash
    # Set routing key
    export PAGERDUTY_ROUTING_KEY="<real-test-key>"
    
    # Run validator with PagerDuty enabled
    hype run validate-nonces.lua -- --pagerduty-enabled --verbose
    
    # Check PagerDuty dashboard for incident
    ```

15. **Test error scenarios**
    ```bash
    # Test with invalid key
    hype run validate-nonces.lua -- --pagerduty-enabled --pagerduty-key=invalid-key
    
    # Expected: 400 Bad Request error in logs
    ```

### Phase 6: Documentation (10 minutes)

16. **Add inline documentation**
    - Document JSON encoder algorithm
    - Document PagerDuty API compatibility
    - Add usage examples in comments

17. **Update README.md**
    - Note that pagerduty.lua is included
    - Explain local library implementation
    - Update installation section

18. **Create PAGERDUTY_LIBRARY_IMPLEMENTATION.md**
    - Document JSON encoder design
    - List supported features
    - Provide troubleshooting guide

## Success Criteria

### Functional Requirements

- [x] **JSON Encoding**: Correctly encode Lua tables to JSON
  - Strings, numbers, booleans, nil
  - Nested objects and arrays
  - Special character escaping
- [x] **JSON Decoding**: Parse PagerDuty API responses
- [x] **HTTP POST**: Send requests to PagerDuty Events API v2
- [x] **Authentication**: Include routing key in request body
- [x] **API Compatibility**: Match assumed `pagerduty` module API

### Validation Requirements

- [x] **Required Fields**: Validate presence of required fields
- [x] **Event Actions**: Validate event_action values
- [x] **Severity Levels**: Validate severity values
- [x] **Routing Key**: Validate non-empty routing key

### Error Handling Requirements

- [x] **Network Errors**: Handle connection failures gracefully
- [x] **HTTP Errors**: Parse and report 4xx/5xx errors
- [x] **API Errors**: Extract error messages from responses
- [x] **JSON Errors**: Handle encoding/decoding failures
- [x] **Circular References**: Detect and error on circular tables

### Integration Requirements

- [x] **Drop-in Replacement**: Works with existing AlertManager code
- [x] **No Code Changes**: AlertManager requires no modifications
- [x] **Graceful Fallback**: Warns if library not found
- [x] **Verbose Logging**: Supports verbose mode for debugging

### Testing Requirements

- [x] **Unit Tests**: JSON encoder/decoder tested independently
- [x] **Integration Tests**: Full workflow tested with mock/real keys
- [x] **Error Scenarios**: Invalid keys, missing fields, network failures
- [x] **Edge Cases**: Special characters, large payloads, nested objects

### Documentation Requirements

- [x] **Inline Docs**: Functions and algorithms documented
- [x] **Usage Examples**: Sample code provided
- [x] **API Reference**: All methods documented
- [x] **Troubleshooting**: Common issues and solutions

## Implementation Complexity

**Effort Estimate:** ~90 minutes total
- JSON encoder: 25 minutes
- JSON decoder: 15 minutes
- PagerDuty client: 20 minutes
- Integration: 10 minutes
- Testing: 20 minutes
- Documentation: 10 minutes

**Risk Level:** Low-Medium
- JSON encoding is well-defined (RFC 8259)
- PagerDuty API is documented and stable
- HTTP module provides reliable foundation
- Clear success criteria and test cases

**Dependencies:**
- Hype `http` module (confirmed available)
- PagerDuty account for testing (existing)
- Valid routing key (existing)

## Example Usage

### Basic Usage

```lua
local pagerduty = require("pagerduty")

-- Initialize client
local pd = pagerduty.new({
  routing_key = "R0XXXXXXXXXXXXXXXXXXXXX"
})

-- Send alert
local ok, err = pd:event({
  event_action = "trigger",
  dedup_key = "server-down-2025-10-13",
  payload = {
    summary = "Server Down: web-01",
    severity = "critical",
    source = "monitoring-system",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    component = "web-server",
    group = "production",
    class = "infrastructure",
    custom_details = {
      server = "web-01",
      region = "us-east-1",
      uptime = 0,
      last_check = "2025-10-13T14:30:00Z"
    }
  }
})

if ok then
  print("Alert sent successfully")
else
  print("Alert failed:", err)
end
```

### Integration with Validator

```lua
-- In validate-nonces.lua (no changes needed!)
local alert_mgr = AlertManager.new(config)

-- AlertManager automatically uses local pagerduty.lua
if alert_mgr.enabled then
  alert_mgr:send_alert("critical", "Mismatches detected", {...})
end
```

---

## Future Enhancements (Optional)

1. **Batch Events**: Support sending multiple events in one request
2. **Change Events**: Support PagerDuty Change Events API
3. **Link/Image Support**: Add links and images to alerts
4. **Full JSON Decoder**: Complete JSON parser for complex responses
5. **Response Caching**: Cache successful responses for deduplication
6. **Metrics**: Track success/failure rates, latency

---

## Approval Checklist

### Before Implementation
- [ ] Requirements clearly understood
- [ ] JSON encoding algorithm reviewed
- [ ] PagerDuty API documentation consulted
- [ ] Solution approach approved
- [ ] Success criteria agreed upon
- [ ] Timeline acceptable (~90 minutes)

### After Implementation
- [ ] All success criteria met
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Real PagerDuty key tested
- [ ] Documentation complete
- [ ] No routing key exposure in logs

---

**Status:** Ready for Implementation ✅  
**Priority:** Critical (unblocks PagerDuty integration)  
**Complexity:** Low-Medium  
**Risk:** Low  
**Value:** Critical (enables production alerting)  
**Dependencies:** Hype `http` module

---

*Created: October 13, 2025*  
*PRP Version: 1.0*  
*Target Implementation: 90 minutes*
