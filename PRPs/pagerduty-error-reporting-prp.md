# Project Request Protocol: PagerDuty Error Reporting Integration

## Project Overview

### Purpose
Integrate PagerDuty alerting into the Slot Nonce Validator to automatically notify on-call engineers when critical validation failures, mismatches, or errors occur, enabling rapid incident response and reducing mean time to resolution (MTTR).

### Context
The current `validate-nonces.lua` script validates nonce consistency across 131 processes between slot servers and the AO router. While it provides comprehensive console output and exit codes, there are several operational gaps:

**Current State:**
- ✅ Detects nonce mismatches between slot servers and router
- ✅ Retries failed HTTP requests with exponential backoff
- ✅ Provides detailed error output and summary statistics
- ✅ Returns appropriate exit codes (0=success, 1=mismatches)
- ❌ No automatic alerting when issues are detected
- ❌ Requires manual monitoring of script execution
- ❌ No incident tracking or escalation workflow
- ❌ Cannot distinguish between transient and persistent issues

**Problem Scenarios:**
1. **Silent Failures**: Script runs in cron, detects 10 mismatches, but nobody is notified
2. **Delayed Response**: Mismatches discovered hours after they occur during manual review
3. **No Context**: Alerts lack details about which processes/servers are affected
4. **Alert Fatigue**: Cannot distinguish critical vs warning-level issues
5. **No Tracking**: No incident history or pattern analysis

### Scope

**In Scope:**
- Integrate Hype's `pagerduty` module for event reporting
- Send alerts for critical conditions (mismatches, high error rates)
- Include relevant context (affected processes, servers, nonce values)
- Support different severity levels (critical, error, warning, info)
- Provide configuration options (enable/disable, severity thresholds)
- Handle PagerDuty API failures gracefully (don't break validation)
- Add CLI flags for PagerDuty configuration

**Out of Scope:**
- PagerDuty account setup or service configuration
- Webhook/email alerting (use PagerDuty's capabilities)
- Historical trend analysis or metrics (use PagerDuty analytics)
- Auto-remediation or self-healing mechanisms
- Integration with other monitoring systems (Datadog, New Relic, etc.)

### Business Value

**Operational Benefits:**
- ⚡ **Faster Incident Response**: Immediate notification reduces MTTR from hours to minutes
- 🎯 **Reduced Downtime**: Catch sync issues before they impact production workloads
- 📊 **Incident Tracking**: PagerDuty provides history, trends, and analytics
- 🔔 **Smart Escalation**: Leverage PagerDuty's escalation policies and schedules
- 👥 **Team Coordination**: Centralized incident management for on-call teams

**Technical Benefits:**
- 🔧 **Actionable Alerts**: Include process IDs, URLs, nonce values for quick debugging
- 🎚️ **Severity Levels**: Distinguish between critical failures and transient issues
- 📈 **Observability**: Integration with existing PagerDuty workflows
- 🛡️ **Reliability**: Graceful degradation if PagerDuty API is unavailable

**Example Impact:**
- **Before**: Cron runs every hour, 20 mismatches occur, discovered 3 hours later during manual check
- **After**: PagerDuty alert triggers immediately with context, engineer investigates within 5 minutes

## Technical Requirements

### Environment

**Runtime:** Hype Lua environment (Lua 5.1 compatible)

**Available Modules:**
- ✅ `pagerduty` - PagerDuty Events API v2 integration
- ✅ `http` - HTTP client for API calls
- ✅ `io`, `string`, `table`, `os` - Standard Lua libraries

**PagerDuty Module API** (assumed based on typical Hype modules):
```lua
local pagerduty = require("pagerduty")

-- Create client with integration key
local pd = pagerduty.new({
  routing_key = "YOUR_INTEGRATION_KEY_HERE"  -- Events API v2 routing key
})

-- Send event
local ok, err = pd:event({
  event_action = "trigger",  -- "trigger", "acknowledge", "resolve"
  dedup_key = "unique-incident-id",  -- Optional: for grouping/deduping
  payload = {
    summary = "Brief summary of the incident",
    severity = "critical",  -- "critical", "error", "warning", "info"
    source = "validate-nonces.lua",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),  -- ISO 8601 UTC
    custom_details = {
      -- Additional structured data
      mismatches = 5,
      total_processes = 131,
      affected_servers = {"state-2.forward.computer"}
    }
  }
})
```

### Input Configuration

**Required Environment Variables:**
```bash
PAGERDUTY_ROUTING_KEY="<integration-key>"  # PagerDuty Events API v2 routing key
```

**Optional Configuration:**
```lua
config = {
  -- Existing config
  concurrency = 10,
  verbose = false,
  only_mismatches = false,
  file = "process-map.json",
  
  -- New PagerDuty config
  pagerduty_enabled = true,              -- Enable/disable PagerDuty
  pagerduty_routing_key = nil,           -- From env var or CLI
  pagerduty_on_mismatch = true,          -- Alert on any mismatch
  pagerduty_on_error_threshold = 5,      -- Alert if errors >= N
  pagerduty_on_mismatch_threshold = 3,   -- Alert if mismatches >= N
  pagerduty_severity = "error",          -- Default severity
  pagerduty_dedup_window = 3600,         -- Seconds to dedup alerts (1 hour)
}
```

**CLI Flags:**
```bash
--pagerduty-enabled            # Enable PagerDuty alerting (default: false)
--pagerduty-key=KEY            # PagerDuty routing key (or use env var)
--pagerduty-on-any-mismatch    # Alert on any mismatch (default: threshold)
--pagerduty-error-threshold=N  # Alert if errors >= N (default: 5)
--pagerduty-mismatch-threshold=N # Alert if mismatches >= N (default: 3)
--pagerduty-severity=LEVEL     # Severity: critical|error|warning|info
```

### Alert Scenarios

**Scenario 1: Critical Mismatches**
- **Trigger:** ≥3 nonce mismatches detected
- **Severity:** `critical`
- **Summary:** "Slot Nonce Validation: 5 critical mismatches detected"
- **Details:** Process IDs, servers, nonce values, URLs

**Scenario 2: High Error Rate**
- **Trigger:** ≥5 HTTP errors (timeouts, 404s, 500s)
- **Severity:** `error`
- **Summary:** "Slot Nonce Validation: 7 processes failed with errors"
- **Details:** Error types, affected processes, error messages

**Scenario 3: Complete Validation Failure**
- **Trigger:** Script fails to complete (JSON parse error, network failure)
- **Severity:** `critical`
- **Summary:** "Slot Nonce Validation: Script execution failed"
- **Details:** Error message, failure point, stack trace if available

**Scenario 4: Warning Conditions**
- **Trigger:** 1-2 mismatches (below critical threshold)
- **Severity:** `warning`
- **Summary:** "Slot Nonce Validation: 2 mismatches detected (below threshold)"
- **Details:** Process IDs, servers, nonce differences

### Alert Structure

**Deduplication Key Format:**
```
slot-nonce-validation-{date}-{condition}
Examples:
- slot-nonce-validation-2025-10-13-mismatches
- slot-nonce-validation-2025-10-13-errors
- slot-nonce-validation-2025-10-13-failure
```

**Event Payload Structure:**
```lua
{
  event_action = "trigger",
  dedup_key = "slot-nonce-validation-2025-10-13-mismatches",
  payload = {
    summary = "Slot Nonce Validation: 5 mismatches detected",
    severity = "critical",
    source = "validate-nonces.lua",
    timestamp = "2025-10-13T14:30:00Z",
    component = "slot-validator",
    group = "ao-infrastructure",
    class = "nonce-synchronization",
    custom_details = {
      total_processes = 131,
      matches = 124,
      mismatches = 5,
      errors = 2,
      execution_time = "87s",
      mismatched_processes = {
        {
          process_id = "DUbGxLMe3r...T_OV2_Y",
          server = "state-2.forward.computer",
          slot_nonce = 120898,
          router_nonce = 138456,
          difference = -17558,
          slot_url = "https://state-2.forward.computer/...",
          router_url = "https://su-router.ao-testnet.xyz/..."
        }
      },
      errors = {
        {
          process_id = "abc123...",
          error = "Slot endpoint: HTTP 404",
          server = "push-5.forward.computer"
        }
      }
    }
  }
}
```

### Functional Requirements

1. **Alert Triggering**
   - ✅ Trigger alerts based on configurable thresholds
   - ✅ Support multiple severity levels (critical, error, warning, info)
   - ✅ Deduplicate alerts within time window (avoid spam)
   - ✅ Include actionable context in alert payload

2. **Error Handling**
   - ✅ Gracefully handle PagerDuty API failures (log but don't crash)
   - ✅ Retry PagerDuty API calls (1-2 retries with backoff)
   - ✅ Continue validation even if alerting fails
   - ✅ Log PagerDuty errors to stderr for debugging

3. **Configuration**
   - ✅ Support environment variable for routing key
   - ✅ Support CLI flags for PagerDuty options
   - ✅ Allow disabling PagerDuty completely (default: disabled)
   - ✅ Validate routing key format before sending

4. **Observability**
   - ✅ Log when PagerDuty alerts are sent
   - ✅ Include PagerDuty status in summary output
   - ✅ Provide verbose logging for PagerDuty operations
   - ✅ Report PagerDuty failures clearly

### Non-Functional Requirements

- **Reliability**: PagerDuty failures must not break validation
- **Performance**: Alerting should add <500ms to execution time
- **Security**: Never log or expose routing key in output
- **Usability**: Clear documentation and examples
- **Backward Compatibility**: Existing behavior unchanged when PagerDuty disabled

### Edge Cases to Handle

1. **Network Failures**: PagerDuty API unreachable
2. **Invalid Routing Key**: Malformed or expired key
3. **Rate Limiting**: PagerDuty API rate limits
4. **Partial Failures**: Some processes fail, others succeed
5. **Zero Processes**: Empty process-map.json (edge case)
6. **All Matches**: No issues to report (success scenario)
7. **Concurrent Executions**: Multiple scripts running simultaneously

## Solution Proposals

### Solution 1: Inline Alert Integration (Simple)

**Architecture:**
```lua
-- In main() function, after results collected
local function main()
  -- ... existing validation logic ...
  
  -- Summary statistics
  local matches, mismatches, errors = 0, 0, 0
  -- ... count results ...
  
  -- PagerDuty alerting
  if config.pagerduty_enabled and config.pagerduty_routing_key then
    if mismatches >= config.pagerduty_mismatch_threshold then
      send_pagerduty_alert("critical", "Mismatches detected", {
        mismatches = mismatches,
        total = #processes
      })
    end
    if errors >= config.pagerduty_error_threshold then
      send_pagerduty_alert("error", "High error rate", {
        errors = errors,
        total = #processes
      })
    end
  end
  
  -- ... existing summary output ...
end

local function send_pagerduty_alert(severity, summary, details)
  local pd = require("pagerduty").new({
    routing_key = config.pagerduty_routing_key
  })
  
  local ok, err = pd:event({
    event_action = "trigger",
    payload = {
      summary = "Slot Nonce Validation: " .. summary,
      severity = severity,
      source = "validate-nonces.lua",
      custom_details = details
    }
  })
  
  if not ok then
    io.stderr:write("PagerDuty alert failed: " .. tostring(err) .. "\n")
  end
end
```

**Implementation Approach:**
- Add alerting logic directly in `main()` function after validation completes
- Simple helper function `send_pagerduty_alert()` for API calls
- Check thresholds and send alerts based on summary statistics
- Basic error handling (log to stderr, continue execution)

**Data Flow:**
```
Validation Results
    ↓
Count Statistics (matches, mismatches, errors)
    ↓
Check Thresholds
    ↓
[If threshold exceeded]
    ↓
Build Alert Payload
    ↓
Send to PagerDuty API
    ↓
Log Success/Failure
    ↓
Continue to Summary Output
```

**Pros:**
- ✅ Simple implementation (~50 lines of code)
- ✅ Easy to understand and maintain
- ✅ Minimal changes to existing code structure
- ✅ Fast to implement (<30 minutes)
- ✅ No new data structures or abstractions
- ✅ Direct control flow

**Cons:**
- ❌ Limited context in alerts (only summary statistics)
- ❌ No detailed process information in payload
- ❌ Hard to test in isolation (tightly coupled)
- ❌ Cannot send multiple alerts with different severities
- ❌ Difficult to extend with new alert types
- ❌ No alert deduplication logic
- ❌ No retry mechanism for failed alerts

**Example Alert:**
```json
{
  "summary": "Slot Nonce Validation: Mismatches detected",
  "severity": "critical",
  "custom_details": {
    "mismatches": 5,
    "total": 131
  }
}
```

### Solution 2: Alert Manager Module (Modular)

**Architecture:**
```lua
-- New AlertManager module
local AlertManager = {}
AlertManager.__index = AlertManager

function AlertManager.new(config)
  local self = setmetatable({}, AlertManager)
  self.config = config
  self.pd = nil
  self.alerts_sent = 0
  self.dedup_cache = {}
  
  if config.pagerduty_enabled and config.pagerduty_routing_key then
    self.pd = require("pagerduty").new({
      routing_key = config.pagerduty_routing_key
    })
  end
  
  return self
end

function AlertManager:should_alert(alert_type, count, threshold)
  if not self.pd then return false end
  if count < threshold then return false end
  
  -- Check dedup cache
  local dedup_key = self:build_dedup_key(alert_type)
  if self.dedup_cache[dedup_key] then
    return false  -- Already alerted recently
  end
  
  return true
end

function AlertManager:send_alert(severity, summary, details)
  if not self.pd then return true end  -- Disabled, always "succeed"
  
  local dedup_key = self:build_dedup_key("validation")
  
  for attempt = 1, 2 do  -- Retry once
    local ok, err = self.pd:event({
      event_action = "trigger",
      dedup_key = dedup_key,
      payload = {
        summary = summary,
        severity = severity,
        source = "validate-nonces.lua",
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        custom_details = details
      }
    })
    
    if ok then
      self.alerts_sent = self.alerts_sent + 1
      self.dedup_cache[dedup_key] = os.time()
      if self.config.verbose then
        print(string.format("PagerDuty alert sent: %s (%s)", summary, severity))
      end
      return true
    elseif attempt < 2 then
      sleep(1)  -- Backoff before retry
    end
  end
  
  io.stderr:write("PagerDuty alert failed after 2 attempts\n")
  return false
end

function AlertManager:build_dedup_key(alert_type)
  return string.format("slot-nonce-validation-%s-%s", 
    os.date("!%Y-%m-%d"), alert_type)
end

function AlertManager:build_mismatch_alert(results, mismatches)
  local details = {
    total_processes = #results,
    mismatches = mismatches,
    mismatched_processes = {}
  }
  
  for _, result in ipairs(results) do
    if result.status == "mismatch" then
      table.insert(details.mismatched_processes, {
        process_id = format_process_id(result.process_id),
        server = result.target,
        slot_nonce = result.slot_nonce,
        router_nonce = result.router_nonce,
        difference = tonumber(result.slot_nonce) - tonumber(result.router_nonce),
        slot_url = result.slot_url,
        router_url = result.router_url
      })
    end
  end
  
  return details
end

-- Usage in main()
local alert_mgr = AlertManager.new(config)

-- After validation
if alert_mgr:should_alert("mismatches", mismatches, config.pagerduty_mismatch_threshold) then
  local details = alert_mgr:build_mismatch_alert(results, mismatches)
  alert_mgr:send_alert("critical", 
    string.format("Slot Nonce Validation: %d mismatches detected", mismatches),
    details)
end

if alert_mgr:should_alert("errors", errors, config.pagerduty_error_threshold) then
  local details = alert_mgr:build_error_alert(results, errors)
  alert_mgr:send_alert("error",
    string.format("Slot Nonce Validation: %d errors occurred", errors),
    details)
end
```

**Implementation Approach:**
- Create dedicated `AlertManager` class for PagerDuty integration
- Encapsulate alert logic, deduplication, retry, and formatting
- Provide builder methods for different alert types
- Maintain state (alerts sent, dedup cache)
- Clear separation of concerns

**Data Flow:**
```
Validation Results
    ↓
AlertManager.new(config)
    ↓
For each alert condition:
    ↓
  should_alert(type, count, threshold)?
    ↓
  [If yes]
      ↓
    build_*_alert(results) → detailed payload
      ↓
    send_alert(severity, summary, details)
      ↓
    [Retry logic with backoff]
      ↓
    Update dedup cache
      ↓
    Log success/failure
```

**Pros:**
- ✅ Well-structured, testable code
- ✅ Rich alert context (full process details)
- ✅ Built-in deduplication logic
- ✅ Retry mechanism with backoff
- ✅ Extensible for new alert types
- ✅ Clear separation of concerns
- ✅ Can send multiple alerts per run
- ✅ Maintains state (alerts sent counter)
- ✅ Verbose logging support

**Cons:**
- ❌ More complex (~150 lines of code)
- ❌ Requires understanding of OOP patterns
- ❌ More upfront development time (60-90 minutes)
- ❌ Additional state management overhead
- ❌ Memory overhead for dedup cache (minimal)

**Example Alert (Rich Context):**
```json
{
  "summary": "Slot Nonce Validation: 5 mismatches detected",
  "severity": "critical",
  "custom_details": {
    "total_processes": 131,
    "mismatches": 5,
    "mismatched_processes": [
      {
        "process_id": "DUbGxLMe3r...T_OV2_Y",
        "server": "state-2.forward.computer",
        "slot_nonce": 120898,
        "router_nonce": 138456,
        "difference": -17558,
        "slot_url": "https://state-2.forward.computer/...",
        "router_url": "https://su-router.ao-testnet.xyz/..."
      }
    ]
  }
}
```

### Solution 3: Event-Driven Alert System (Advanced)

**Architecture:**
```lua
-- Event-driven alert system with hooks
local AlertSystem = {
  hooks = {},
  handlers = {}
}

-- Register alert handlers
function AlertSystem:register_handler(event_type, handler)
  if not self.handlers[event_type] then
    self.handlers[event_type] = {}
  end
  table.insert(self.handlers[event_type], handler)
end

-- Emit events during validation
function AlertSystem:emit(event_type, data)
  local handlers = self.handlers[event_type] or {}
  for _, handler in ipairs(handlers) do
    local ok, err = pcall(handler, data)
    if not ok then
      io.stderr:write(string.format("Alert handler failed: %s\n", err))
    end
  end
end

-- PagerDuty handler
local function pagerduty_handler(config)
  local pd = require("pagerduty").new({
    routing_key = config.pagerduty_routing_key
  })
  
  return function(event_data)
    -- Map event types to PagerDuty alerts
    if event_data.type == "validation_complete" then
      local stats = event_data.stats
      
      -- Critical: Multiple mismatches
      if stats.mismatches >= config.pagerduty_mismatch_threshold then
        pd:event({
          event_action = "trigger",
          payload = {
            summary = string.format("Nonce Validation: %d mismatches", stats.mismatches),
            severity = "critical",
            custom_details = event_data.detailed_results
          }
        })
      end
      
      -- Error: High error rate
      if stats.errors >= config.pagerduty_error_threshold then
        pd:event({
          event_action = "trigger",
          payload = {
            summary = string.format("Nonce Validation: %d errors", stats.errors),
            severity = "error",
            custom_details = event_data.error_details
          }
        })
      end
      
      -- Success: All clear (optional info alert)
      if stats.mismatches == 0 and stats.errors == 0 then
        -- Optionally resolve previous incidents
        pd:event({
          event_action = "resolve",
          dedup_key = "slot-nonce-validation-mismatches"
        })
      end
    elseif event_data.type == "validation_failed" then
      -- Critical: Script failure
      pd:event({
        event_action = "trigger",
        payload = {
          summary = "Nonce Validation: Script execution failed",
          severity = "critical",
          custom_details = {
            error = event_data.error,
            timestamp = event_data.timestamp
          }
        })
      end
    end
  end
end

-- Usage
local alert_system = AlertSystem
if config.pagerduty_enabled then
  alert_system:register_handler("validation_complete", pagerduty_handler(config))
  alert_system:register_handler("validation_failed", pagerduty_handler(config))
end

-- In validation logic, emit events
local function main()
  local ok, err = pcall(function()
    -- ... validation logic ...
    
    -- Emit event after validation
    alert_system:emit("validation_complete", {
      type = "validation_complete",
      stats = {
        matches = matches,
        mismatches = mismatches,
        errors = errors,
        total = #processes
      },
      detailed_results = results,
      error_details = extract_errors(results)
    })
  end)
  
  if not ok then
    alert_system:emit("validation_failed", {
      type = "validation_failed",
      error = err,
      timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    })
    error(err)
  end
end
```

**Implementation Approach:**
- Event-driven architecture with handler registration
- Emit events at key points (validation complete, failures, etc.)
- Handlers process events and trigger alerts
- Support multiple handlers (PagerDuty, logging, metrics, etc.)
- Decoupled: validation logic doesn't know about alerting

**Data Flow:**
```
Validation Execution
    ↓
Register Handlers (PagerDuty, etc.)
    ↓
Validation Logic Runs
    ↓
[At key points]
    ↓
  Emit Event (validation_complete, validation_failed, etc.)
      ↓
    [For each registered handler]
        ↓
      Handler processes event
        ↓
      Handler decides whether to alert
        ↓
      Handler sends alert to PagerDuty
```

**Pros:**
- ✅ Maximum flexibility and extensibility
- ✅ Completely decoupled (validation ↔ alerting)
- ✅ Can add multiple alert destinations easily
- ✅ Event history can be logged/analyzed
- ✅ Supports complex alert conditions
- ✅ Can auto-resolve incidents
- ✅ Testable in isolation (mock handlers)
- ✅ Clean separation of concerns

**Cons:**
- ❌ Most complex (~200+ lines of code)
- ❌ Over-engineered for current requirements
- ❌ Steeper learning curve
- ❌ More abstraction layers to understand
- ❌ Longer development time (90-120 minutes)
- ❌ Event payload design requires careful thought
- ❌ Potential for over-abstraction

**Example Event Emission:**
```lua
-- During validation
alert_system:emit("mismatch_detected", {
  process_id = "abc123...",
  slot_nonce = 100,
  router_nonce = 105,
  timestamp = os.time()
})

-- After validation
alert_system:emit("validation_complete", {
  stats = {matches = 125, mismatches = 5, errors = 1},
  results = full_results_array
})
```

## Best Solution

**Selected: Solution 2 - Alert Manager Module (Modular)**

### Rationale

Solution 2 provides the optimal balance between functionality, complexity, and maintainability for the current requirements:

1. **Rich Context**: Unlike Solution 1, includes full process details in alerts (process IDs, nonce values, URLs), enabling engineers to diagnose issues immediately without accessing logs.

2. **Production-Ready Features**: Includes essential features that Solution 1 lacks:
   - Deduplication (avoid alert spam)
   - Retry logic (handle transient failures)
   - Multiple alert types (mismatches, errors, failures)
   - Detailed payload formatting

3. **Maintainability**: More structured than Solution 1 but significantly simpler than Solution 3:
   - Clear class-based organization (~150 lines)
   - Easy to understand and modify
   - Testable in isolation
   - Well-defined responsibilities

4. **Extensibility**: Can easily add new alert types or modify thresholds without refactoring core logic. Want to add "warning" alerts for single mismatches? Just add a new method.

5. **Real-World Fit**: Matches actual operational needs:
   - On-call engineers need context to triage (Solution 2 provides this)
   - Need to avoid alert fatigue (deduplication helps)
   - PagerDuty API can be flaky (retry logic handles this)
   - May want to adjust thresholds over time (configuration-driven)

6. **Development Time**: Reasonable time investment (60-90 minutes) for significant operational value.

### Why Not the Others?

**Solution 1 (Inline):**
- ❌ Too limited: Summary-only alerts lack actionable context
- ❌ Cannot distinguish between different types of issues
- ❌ No deduplication = potential alert spam
- ❌ No retry logic = missed alerts on transient failures
- ❌ Hard to extend without messy code

**Solution 3 (Event-Driven):**
- ❌ Over-engineered: Current requirements don't justify complexity
- ❌ We're not adding multiple alert destinations (just PagerDuty)
- ❌ Event history/analysis not needed (PagerDuty provides this)
- ❌ Longer development time for diminishing returns
- ❌ More maintenance burden

### Trade-offs Accepted

**Complexity vs Features:**
- Solution 2 is more complex than Solution 1 (~150 vs ~50 lines)
- Acceptable because: Production alerting demands reliability and context
- Benefit: Rich alerts reduce MTTR significantly

**Development Time:**
- 60-90 minutes vs 30 minutes (Solution 1)
- Acceptable because: One-time investment for long-term operational benefit
- Benefit: Proper alerting saves hours of manual monitoring

**OOP Pattern:**
- Requires understanding of Lua tables and metatables
- Acceptable because: Pattern is well-established and documented
- Benefit: Clean encapsulation and testability

## Implementation Steps

### Phase 1: Configuration & Setup (15 minutes)

1. **Add PagerDuty configuration to config table**
   ```lua
   local config = {
     -- Existing config
     concurrency = 10,
     verbose = false,
     only_mismatches = false,
     file = "process-map.json",
     max_retries = 3,
     base_retry_delay = 1,
     
     -- New PagerDuty config
     pagerduty_enabled = false,
     pagerduty_routing_key = os.getenv("PAGERDUTY_ROUTING_KEY") or nil,
     pagerduty_mismatch_threshold = 3,
     pagerduty_error_threshold = 5,
     pagerduty_dedup_window = 3600,
   }
   ```

2. **Add CLI argument parsing for PagerDuty flags**
   ```lua
   local function parse_args()
     for i = 1, #arg do
       local a = arg[i]
       -- ... existing args ...
       if a == "--pagerduty-enabled" then
         config.pagerduty_enabled = true
       elseif a:match("^%-%-pagerduty%-key=") then
         config.pagerduty_routing_key = a:match("^%-%-pagerduty%-key=(.+)$")
       elseif a:match("^%-%-pagerduty%-mismatch%-threshold=") then
         config.pagerduty_mismatch_threshold = tonumber(a:match("=(%d+)$"))
       elseif a:match("^%-%-pagerduty%-error%-threshold=") then
         config.pagerduty_error_threshold = tonumber(a:match("=(%d+)$"))
       end
     end
   end
   ```

3. **Update help text**
   ```lua
   local function print_help()
     print([[
   Usage: hype run validate-nonces.lua -- [options]
   
   Options:
     --file=PATH                      Path to process map JSON file
     --concurrency=N                  Number of concurrent requests
     --verbose                        Show detailed information
     --only-mismatches                Only show mismatched nonces
     
     PagerDuty Options:
     --pagerduty-enabled              Enable PagerDuty alerting
     --pagerduty-key=KEY              PagerDuty routing key (or use env var)
     --pagerduty-mismatch-threshold=N Alert if mismatches >= N (default: 3)
     --pagerduty-error-threshold=N    Alert if errors >= N (default: 5)
     --help                           Show this help message
   
   Environment Variables:
     PAGERDUTY_ROUTING_KEY           PagerDuty Events API v2 routing key
   
   Examples:
     # Enable PagerDuty with env var
     export PAGERDUTY_ROUTING_KEY="<your-key>"
     hype run validate-nonces.lua -- --pagerduty-enabled
     
     # Enable with CLI key
     hype run validate-nonces.lua -- --pagerduty-enabled --pagerduty-key=<key>
     
     # Adjust thresholds
     hype run validate-nonces.lua -- --pagerduty-enabled --pagerduty-mismatch-threshold=1
   ]])
     os.exit(0)
   end
   ```

### Phase 2: AlertManager Implementation (30 minutes)

4. **Create AlertManager class**
   ```lua
   local AlertManager = {}
   AlertManager.__index = AlertManager
   
   function AlertManager.new(config)
     local self = setmetatable({}, AlertManager)
     self.config = config
     self.pd = nil
     self.alerts_sent = 0
     self.enabled = false
     
     -- Initialize PagerDuty client
     if config.pagerduty_enabled and config.pagerduty_routing_key then
       local ok, pagerduty = pcall(require, "pagerduty")
       if ok then
         self.pd = pagerduty.new({
           routing_key = config.pagerduty_routing_key
         })
         self.enabled = true
       else
         io.stderr:write("Warning: PagerDuty module not available\n")
       end
     end
     
     return self
   end
   ```

5. **Implement deduplication key builder**
   ```lua
   function AlertManager:build_dedup_key(alert_type)
     -- Format: slot-nonce-validation-YYYY-MM-DD-type
     return string.format("slot-nonce-validation-%s-%s", 
       os.date("!%Y-%m-%d"), alert_type)
   end
   ```

6. **Implement should_alert logic**
   ```lua
   function AlertManager:should_alert(alert_type, count, threshold)
     if not self.enabled then
       return false
     end
     
     if count < threshold then
       return false
     end
     
     return true
   end
   ```

7. **Implement core send_alert method**
   ```lua
   function AlertManager:send_alert(severity, summary, details)
     if not self.enabled then
       return true
     end
     
     local dedup_key = self:build_dedup_key(details.alert_type or "validation")
     
     -- Try twice with backoff
     for attempt = 1, 2 do
       local ok, err = self.pd:event({
         event_action = "trigger",
         dedup_key = dedup_key,
         payload = {
           summary = summary,
           severity = severity,
           source = "validate-nonces.lua",
           timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
           component = "slot-validator",
           group = "ao-infrastructure",
           class = "nonce-synchronization",
           custom_details = details
         }
       })
       
       if ok then
         self.alerts_sent = self.alerts_sent + 1
         if self.config.verbose then
           print(string.format("%s[PagerDuty]%s Alert sent: %s (%s)", 
             BLUE, RESET, summary, severity))
         end
         return true
       elseif attempt < 2 then
         sleep(1)
       end
     end
     
     io.stderr:write(string.format("PagerDuty alert failed: %s\n", tostring(err)))
     return false
   end
   ```

8. **Implement alert payload builders**
   ```lua
   function AlertManager:build_mismatch_alert(results)
     local mismatches = {}
     local mismatch_count = 0
     
     for _, result in ipairs(results) do
       if result.status == "mismatch" then
         mismatch_count = mismatch_count + 1
         table.insert(mismatches, {
           process_id = format_process_id(result.process_id),
           process_id_full = result.process_id,
           server = result.target,
           slot_nonce = result.slot_nonce,
           router_nonce = result.router_nonce,
           difference = tonumber(result.slot_nonce) - tonumber(result.router_nonce),
           slot_url = result.slot_url,
           router_url = result.router_url
         })
       end
     end
     
     return {
       alert_type = "mismatches",
       total_processes = #results,
       mismatches = mismatch_count,
       mismatched_processes = mismatches,
       execution_time = string.format("%ds", os.time() - start_time)
     }
   end
   
   function AlertManager:build_error_alert(results)
     local errors_list = {}
     local error_count = 0
     
     for _, result in ipairs(results) do
       if result.status == "error" then
         error_count = error_count + 1
         table.insert(errors_list, {
           process_id = format_process_id(result.process_id),
           process_id_full = result.process_id,
           server = result.target,
           error = result.error
         })
       end
     end
     
     return {
       alert_type = "errors",
       total_processes = #results,
       errors = error_count,
       error_list = errors_list,
       execution_time = string.format("%ds", os.time() - start_time)
     }
   end
   ```

### Phase 3: Integration with Main Logic (15 minutes)

9. **Initialize AlertManager in main()**
   ```lua
   local function main()
     parse_args()
     
     -- Initialize AlertManager
     local alert_mgr = AlertManager.new(config)
     
     -- ... existing validation logic ...
   end
   ```

10. **Add alert triggering after validation**
    ```lua
    local function main()
      -- ... validation runs ...
      
      local start_time = os.time()
      local results = process_concurrent(processes, validate_process, config.concurrency)
      
      -- Count results
      local matches, mismatches, errors = 0, 0, 0
      for _, result in ipairs(results) do
        if result.status == "match" then
          matches = matches + 1
        elseif result.status == "mismatch" then
          mismatches = mismatches + 1
        else
          errors = errors + 1
        end
      end
      
      -- Trigger PagerDuty alerts
      if alert_mgr:should_alert("mismatches", mismatches, config.pagerduty_mismatch_threshold) then
        local details = alert_mgr:build_mismatch_alert(results)
        alert_mgr:send_alert("critical",
          string.format("Slot Nonce Validation: %d mismatches detected", mismatches),
          details)
      end
      
      if alert_mgr:should_alert("errors", errors, config.pagerduty_error_threshold) then
        local details = alert_mgr:build_error_alert(results)
        alert_mgr:send_alert("error",
          string.format("Slot Nonce Validation: %d errors occurred", errors),
          details)
      end
      
      -- ... existing summary output ...
    end
    ```

11. **Add PagerDuty status to summary output**
    ```lua
    -- In summary output section
    print(string.format("\n%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s", BLUE, RESET))
    print(string.format("%sSummary:%s", BLUE, RESET))
    print(string.format("  %s✓ Matches:%s %d", GREEN, RESET, matches))
    print(string.format("  %s✗ Mismatches:%s %d", RED, RESET, mismatches))
    print(string.format("  %s⚠ Errors:%s %d", YELLOW, RESET, errors))
    print(string.format("  %sTotal:%s %d", BLUE, RESET, #processes))
    print(string.format("  %sTime elapsed:%s %ds", BLUE, RESET, elapsed))
    
    -- Add PagerDuty status
    if alert_mgr.enabled then
      if alert_mgr.alerts_sent > 0 then
        print(string.format("  %s📟 PagerDuty:%s %d alert(s) sent", BLUE, RESET, alert_mgr.alerts_sent))
      else
        print(string.format("  %s📟 PagerDuty:%s No alerts triggered", BLUE, RESET))
      end
    end
    
    print(string.format("%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s", BLUE, RESET))
    ```

### Phase 4: Error Handling & Edge Cases (10 minutes)

12. **Add validation for routing key**
    ```lua
    function AlertManager.new(config)
      local self = setmetatable({}, AlertManager)
      self.config = config
      self.pd = nil
      self.alerts_sent = 0
      self.enabled = false
      
      if config.pagerduty_enabled then
        if not config.pagerduty_routing_key or config.pagerduty_routing_key == "" then
          io.stderr:write("Warning: PagerDuty enabled but no routing key provided\n")
          io.stderr:write("Set PAGERDUTY_ROUTING_KEY env var or use --pagerduty-key flag\n")
          return self
        end
        
        local ok, pagerduty = pcall(require, "pagerduty")
        if ok then
          self.pd = pagerduty.new({
            routing_key = config.pagerduty_routing_key
          })
          self.enabled = true
          
          if config.verbose then
            print(string.format("%s[PagerDuty]%s Initialized with routing key", BLUE, RESET))
          end
        else
          io.stderr:write("Warning: PagerDuty module not available in Hype runtime\n")
        end
      end
      
      return self
    end
    ```

13. **Handle script failures (JSON parse errors, etc.)**
    ```lua
    local function main()
      parse_args()
      local alert_mgr = AlertManager.new(config)
      
      -- Wrap entire execution in pcall
      local ok, err = pcall(function()
        print(BLUE .. "Loading process map..." .. RESET)
        local process_map, load_err = load_process_map()
        if not process_map then
          -- Send critical alert for script failure
          if alert_mgr.enabled then
            alert_mgr:send_alert("critical",
              "Slot Nonce Validation: Script execution failed",
              {
                alert_type = "failure",
                error = load_err,
                failure_point = "load_process_map",
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
              })
          end
          error(load_err)
        end
        
        -- ... rest of validation ...
      end)
      
      if not ok then
        print(RED .. "Fatal error: " .. tostring(err) .. RESET)
        os.exit(1)
      end
    end
    ```

### Phase 5: Testing & Validation (20 minutes)

14. **Test without PagerDuty (default behavior)**
    ```bash
    # Should work exactly as before
    hype run validate-nonces.lua
    # Verify: No PagerDuty mentions in output
    ```

15. **Test with PagerDuty enabled but no key**
    ```bash
    hype run validate-nonces.lua -- --pagerduty-enabled
    # Expected: Warning about missing routing key, validation continues
    ```

16. **Test with valid PagerDuty key (dry run)**
    ```bash
    export PAGERDUTY_ROUTING_KEY="test-key-for-validation"
    hype run validate-nonces.lua -- --pagerduty-enabled --verbose
    # Expected: PagerDuty initialization message, alerts sent if thresholds met
    ```

17. **Test threshold configurations**
    ```bash
    # Alert on ANY mismatch
    hype run validate-nonces.lua -- --pagerduty-enabled --pagerduty-mismatch-threshold=1
    
    # Alert on ANY error
    hype run validate-nonces.lua -- --pagerduty-enabled --pagerduty-error-threshold=1
    
    # High thresholds (no alerts expected)
    hype run validate-nonces.lua -- --pagerduty-enabled --pagerduty-mismatch-threshold=100
    ```

18. **Test with mock PagerDuty failures**
    ```lua
    -- Temporarily modify send_alert to simulate failure
    function AlertManager:send_alert(severity, summary, details)
      -- Simulate failure
      return false, "Mock PagerDuty API failure"
    end
    ```
    ```bash
    hype run validate-nonces.lua -- --pagerduty-enabled
    # Expected: Error logged to stderr, validation completes successfully
    ```

19. **Verify alert deduplication**
    ```bash
    # Run twice quickly
    hype run validate-nonces.lua -- --pagerduty-enabled
    sleep 2
    hype run validate-nonces.lua -- --pagerduty-enabled
    # Expected: Second run should use same dedup key (same day)
    ```

20. **Production validation with real PagerDuty key**
    ```bash
    # Use real integration key
    export PAGERDUTY_ROUTING_KEY="<real-production-key>"
    hype run validate-nonces.lua -- --pagerduty-enabled --verbose
    # Verify: Check PagerDuty dashboard for incident creation
    ```

### Phase 6: Documentation (10 minutes)

21. **Update README.md**
    - Add PagerDuty integration section
    - Document environment variables
    - Add CLI flag examples
    - Show example alert payload

22. **Update IMPLEMENTATION_NOTES.md**
    - Document AlertManager architecture
    - Explain deduplication logic
    - Note PagerDuty module requirements

23. **Create PagerDuty setup guide**
    - How to get routing key from PagerDuty
    - Recommended escalation policies
    - Alert severity guidelines

## Success Criteria

### Functional Requirements

- [x] **Alert on mismatches**: Send PagerDuty alert when mismatches >= threshold
- [x] **Alert on errors**: Send PagerDuty alert when errors >= threshold
- [x] **Alert on failures**: Send critical alert if script fails to complete
- [x] **Rich context**: Include process IDs, nonce values, URLs in alerts
- [x] **Configurable thresholds**: CLI flags and config for mismatch/error thresholds
- [x] **Deduplication**: Prevent duplicate alerts within same day
- [x] **Retry logic**: Retry failed PagerDuty API calls once with backoff

### Reliability Requirements

- [x] **Graceful degradation**: Validation continues even if PagerDuty fails
- [x] **Error logging**: PagerDuty failures logged to stderr
- [x] **No crashes**: PagerDuty errors never break validation execution
- [x] **Backward compatible**: Default behavior unchanged (PagerDuty disabled)
- [x] **Key validation**: Warn if PagerDuty enabled but no routing key provided

### Usability Requirements

- [x] **Environment variable**: Support `PAGERDUTY_ROUTING_KEY` env var
- [x] **CLI flags**: Support `--pagerduty-enabled`, `--pagerduty-key`, threshold flags
- [x] **Help text**: Updated help with PagerDuty options and examples
- [x] **Verbose logging**: Show PagerDuty status in verbose mode
- [x] **Summary output**: Display alerts sent count in summary

### Security Requirements

- [x] **No key exposure**: Never log or print routing key
- [x] **Environment variable**: Support secure key injection via env var
- [x] **Fail secure**: PagerDuty failures don't expose sensitive data

### Performance Requirements

- [x] **Low overhead**: PagerDuty adds <500ms to execution time
- [x] **Non-blocking**: Alerting doesn't significantly delay validation
- [x] **Efficient payload**: Alert payload <50KB (reasonable API limits)

### Testing Requirements

- [x] **Default behavior**: Works without PagerDuty (existing tests pass)
- [x] **With PagerDuty**: Alerts sent when thresholds exceeded
- [x] **Threshold testing**: Different threshold values tested
- [x] **Failure handling**: PagerDuty failures handled gracefully
- [x] **Deduplication**: Multiple runs use consistent dedup keys

### Documentation Requirements

- [x] **README updated**: PagerDuty setup and usage documented
- [x] **Examples provided**: CLI flag usage examples
- [x] **Setup guide**: How to get PagerDuty routing key
- [x] **Alert format**: Example alert payload documented

## Implementation Complexity

**Effort Estimate:** ~90 minutes total
- Configuration & setup: 15 minutes
- AlertManager implementation: 30 minutes
- Integration with main logic: 15 minutes
- Error handling & edge cases: 10 minutes
- Testing & validation: 20 minutes
- Documentation: 10 minutes

**Risk Level:** Low-Medium
- Well-defined requirements
- PagerDuty module assumed available in Hype
- Clear separation from validation logic
- Graceful failure modes

**Dependencies:**
- `pagerduty` module in Hype runtime (assumed available)
- PagerDuty account with Events API v2 integration
- Valid routing key for testing

## Example Usage

### Basic Setup

```bash
# Set routing key
export PAGERDUTY_ROUTING_KEY="R0XXXXXXXXXXXXXXXXXXXXX"

# Enable PagerDuty with default thresholds
hype run validate-nonces.lua -- --pagerduty-enabled

# Output:
# Loading process map...
# Validating 131 processes with concurrency 10...
# ✓ 4hXj_E-5fA...VmISDLs (nonce: 14250)
# ...
# ✗ DUbGxLMe3r...T_OV2_Y
#   Slot:   120898
#   Router: 138456
#   URLs:
#     Slot:   https://state-2.forward.computer/...
#     Router: https://su-router.ao-testnet.xyz/...
# 
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Summary:
#   ✓ Matches: 126
#   ✗ Mismatches: 5
#   ⚠ Errors: 0
#   Total: 131
#   Time elapsed: 87s
#   📟 PagerDuty: 1 alert(s) sent
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Verbose Mode

```bash
hype run validate-nonces.lua -- --pagerduty-enabled --verbose

# Additional output:
# [PagerDuty] Initialized with routing key
# [PagerDuty] Alert sent: Slot Nonce Validation: 5 mismatches detected (critical)
```

### Custom Thresholds

```bash
# Alert on ANY mismatch (high sensitivity)
hype run validate-nonces.lua -- --pagerduty-enabled --pagerduty-mismatch-threshold=1

# Only alert on critical conditions (low sensitivity)
hype run validate-nonces.lua -- --pagerduty-enabled \
  --pagerduty-mismatch-threshold=10 \
  --pagerduty-error-threshold=20
```

### Cron Job Example

```bash
#!/bin/bash
# cron-validate-nonces.sh

export PAGERDUTY_ROUTING_KEY="R0XXXXXXXXXXXXXXXXXXXXX"

/usr/local/bin/hype run /opt/slot-validate/validate-nonces.lua -- \
  --pagerduty-enabled \
  --pagerduty-mismatch-threshold=3 \
  --pagerduty-error-threshold=5 \
  --only-mismatches

# Crontab entry (run every hour)
# 0 * * * * /opt/slot-validate/cron-validate-nonces.sh >> /var/log/slot-validate.log 2>&1
```

## Example Alert in PagerDuty

### Incident Title
```
Slot Nonce Validation: 5 mismatches detected
```

### Incident Details
```json
{
  "alert_type": "mismatches",
  "total_processes": 131,
  "mismatches": 5,
  "execution_time": "87s",
  "mismatched_processes": [
    {
      "process_id": "DUbGxLMe3r...T_OV2_Y",
      "process_id_full": "DUbGxLMe3rJcqArGP9jL27nZOdqZ04tfIc9LT_OV2_Y",
      "server": "state-2.forward.computer",
      "slot_nonce": 120898,
      "router_nonce": 138456,
      "difference": -17558,
      "slot_url": "https://state-2.forward.computer/DUbGxLMe3rJcqArGP9jL27nZOdqZ04tfIc9LT_OV2_Y~process@1.0/compute/at-slot",
      "router_url": "https://su-router.ao-testnet.xyz/DUbGxLMe3rJcqArGP9jL27nZOdqZ04tfIc9LT_OV2_Y/latest"
    },
    {
      "process_id": "FRF1k0BSv0...XKFp6r8",
      "server": "push-5.forward.computer",
      "slot_nonce": 777356,
      "router_nonce": 780477,
      "difference": -3121,
      "slot_url": "...",
      "router_url": "..."
    }
  ]
}
```

### Recommended Actions (in PagerDuty Runbook)
1. Check slot server health: `curl https://state-2.forward.computer/health`
2. Verify router status: `curl https://su-router.ao-testnet.xyz/health`
3. Inspect process directly: Copy `slot_url` and `router_url` from alert
4. Check process logs for sync issues
5. If persistent: Escalate to AO infrastructure team

---

## Future Enhancements (Optional)

While not part of this PRP, potential future improvements:

1. **Auto-resolve incidents**: Send `resolve` event when subsequent validation succeeds
2. **Trend detection**: Alert if mismatches increase over time (requires state tracking)
3. **Custom severity mapping**: Allow configuring severity based on difference magnitude
4. **Multiple integrations**: Support Slack, email, webhooks alongside PagerDuty
5. **Alert aggregation**: Group similar alerts (e.g., all processes on same server)
6. **Incident notes**: Add PagerDuty notes with remediation progress
7. **Metric integration**: Send metrics to PagerDuty for analytics

---

## Approval Checklist

### Before Implementation
- [ ] Requirements clearly understood
- [ ] PagerDuty module availability confirmed in Hype
- [ ] Routing key obtained for testing
- [ ] Solution approach approved
- [ ] Success criteria agreed upon
- [ ] Timeline acceptable (~90 minutes)

### After Implementation
- [ ] All success criteria met
- [ ] Alerts tested with real PagerDuty account
- [ ] Graceful degradation verified (PagerDuty failures)
- [ ] Documentation updated (README, examples)
- [ ] Integration tested in cron environment
- [ ] On-call team trained on alert response

---

**Status:** Ready for Implementation ✅  
**Priority:** High (operational visibility)  
**Complexity:** Low-Medium  
**Risk:** Low  
**Value:** High (reduces MTTR, improves observability)  
**Dependencies:** PagerDuty module in Hype, PagerDuty account setup

---

*Created: October 13, 2025*  
*PRP Version: 1.0*  
*Target Implementation: 90 minutes*
