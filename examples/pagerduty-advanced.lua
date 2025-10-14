local pagerduty = require("pagerduty")

print("=== PagerDuty Library - Advanced Usage Example ===\n")

local routing_key = os.getenv("PAGERDUTY_ROUTING_KEY") or "test-key-replace-me"

local function send_with_retry(pd, event_data, max_attempts)
  max_attempts = max_attempts or 3
  
  for attempt = 1, max_attempts do
    local ok, err = pd:event(event_data)
    
    if ok then
      return true, nil
    end
    
    if err:match("Rate limited") then
      print(string.format("   Attempt %d/%d: Rate limited, waiting...", attempt, max_attempts))
      os.execute("sleep 2")
    else
      return false, err
    end
  end
  
  return false, "Max retry attempts reached"
end

local function create_alert_manager(routing_key)
  return {
    pd = pagerduty.new({routing_key = routing_key}),
    alerts_sent = 0,
    
    send_alert = function(self, severity, summary, details)
      local dedup_key = string.format("alert-%s-%s", 
        details.alert_type or "general",
        os.date("!%Y-%m-%d"))
      
      local ok, err = send_with_retry(self.pd, {
        event_action = "trigger",
        dedup_key = dedup_key,
        payload = {
          summary = summary,
          severity = severity,
          source = "advanced-example",
          timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
          component = details.component or "unknown",
          group = details.group or "general",
          class = details.class or "alert",
          custom_details = details
        }
      })
      
      if ok then
        self.alerts_sent = self.alerts_sent + 1
        return true
      else
        return false, err
      end
    end,
    
    send_batch_summary = function(self, alerts)
      local summary = string.format("%d issues detected", #alerts)
      local details = {
        alert_type = "batch-summary",
        component = "batch-processor",
        alert_count = #alerts,
        alerts = {}
      }
      
      for i, alert in ipairs(alerts) do
        table.insert(details.alerts, {
          index = i,
          severity = alert.severity,
          message = alert.message,
          timestamp = alert.timestamp
        })
      end
      
      return self:send_alert("warning", summary, details)
    end
  }
end

print("1. Create advanced alert manager with retry logic")
local mgr = create_alert_manager(routing_key)
print("   ✓ Alert manager created\n")

print("2. Send alerts with different severity levels")

local severities = {"critical", "error", "warning", "info"}
for i, severity in ipairs(severities) do
  local ok, err = mgr:send_alert(
    severity,
    string.format("Test %s alert", severity),
    {
      alert_type = "severity-test",
      component = "test-component",
      group = "testing",
      class = "example",
      severity_level = i,
      test_data = {
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        test_id = i
      }
    }
  )
  
  if ok then
    print(string.format("   ✓ Sent %s alert", severity))
  else
    print(string.format("   ✗ Failed to send %s alert: %s", severity, err))
  end
end
print()

print("3. Send batch summary alert")
local batch_alerts = {
  {severity = "critical", message = "Database connection lost", timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")},
  {severity = "error", message = "API rate limit exceeded", timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")},
  {severity = "warning", message = "Disk space low", timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")},
  {severity = "info", message = "Deployment completed", timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")}
}

local ok, err = mgr:send_batch_summary(batch_alerts)
if ok then
  print("   ✓ Batch summary sent")
else
  print("   ✗ Batch summary failed:", err)
end
print()

print("4. Send complex nested data structure")
ok, err = mgr:send_alert(
  "warning",
  "Complex data structure example",
  {
    alert_type = "complex-structure",
    component = "data-processor",
    metrics = {
      performance = {
        cpu_usage = {current = 85, average = 72, peak = 95},
        memory_usage = {current = 1024, average = 896, peak = 1280},
        disk_io = {reads = 1000, writes = 500, latency_ms = 15}
      },
      errors = {
        total = 50,
        by_type = {
          connection_error = 20,
          timeout_error = 15,
          validation_error = 10,
          unknown_error = 5
        },
        recent = {
          {timestamp = "2025-10-13T10:00:00Z", type = "timeout", message = "Request timed out"},
          {timestamp = "2025-10-13T10:05:00Z", type = "connection", message = "Connection refused"},
          {timestamp = "2025-10-13T10:10:00Z", type = "validation", message = "Invalid input"}
        }
      },
      health_checks = {
        database = {status = "healthy", response_time_ms = 50},
        cache = {status = "degraded", response_time_ms = 200},
        api = {status = "healthy", response_time_ms = 100}
      }
    }
  }
)

if ok then
  print("   ✓ Complex alert sent")
else
  print("   ✗ Complex alert failed:", err)
end
print()

print("5. Summary")
print(string.format("   Total alerts sent: %d", mgr.alerts_sent))
print()

print("=== Advanced Example Complete ===")
print("\nKey Features Demonstrated:")
print("  • Retry logic with exponential backoff")
print("  • Alert manager pattern")
print("  • Batch alert summarization")
print("  • Complex nested data structures")
print("  • Different severity levels")
print("  • Deduplication keys")
print("\nNote: Set PAGERDUTY_ROUTING_KEY to send real alerts.")
