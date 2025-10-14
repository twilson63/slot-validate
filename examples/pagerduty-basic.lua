local pagerduty = require("pagerduty")

print("=== PagerDuty Library - Basic Usage Example ===\n")

local routing_key = os.getenv("PAGERDUTY_ROUTING_KEY") or "test-key-replace-me"

print("1. Initialize PagerDuty client")
local pd = pagerduty.new({
  routing_key = routing_key
})
print("   ✓ Client initialized\n")

print("2. Send a simple critical alert")
local ok, err = pd:event({
  event_action = "trigger",
  dedup_key = "example-alert-001",
  payload = {
    summary = "Server is down - Example Alert",
    severity = "critical",
    source = "example-script"
  }
})

if ok then
  print("   ✓ Alert sent successfully!")
else
  print("   ✗ Alert failed:", err)
end
print()

print("3. Send an alert with custom details")
ok, err = pd:event({
  event_action = "trigger",
  dedup_key = "example-alert-002",
  payload = {
    summary = "High CPU usage detected",
    severity = "warning",
    source = "monitoring-system",
    timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    component = "web-server",
    group = "production",
    class = "performance",
    custom_details = {
      cpu_percent = 95,
      memory_mb = 1024,
      process_count = 150,
      uptime_hours = 72,
      details = {
        server = "web-01",
        region = "us-east-1",
        datacenter = "dc1"
      }
    }
  },
  client = "example-script",
  client_url = "https://example.com/dashboard"
})

if ok then
  print("   ✓ Alert with custom details sent!")
else
  print("   ✗ Alert failed:", err)
end
print()

print("4. Acknowledge the first alert")
ok, err = pd:event({
  event_action = "acknowledge",
  dedup_key = "example-alert-001"
})

if ok then
  print("   ✓ Alert acknowledged!")
else
  print("   ✗ Acknowledge failed:", err)
end
print()

print("5. Resolve the first alert")
ok, err = pd:event({
  event_action = "resolve",
  dedup_key = "example-alert-001"
})

if ok then
  print("   ✓ Alert resolved!")
else
  print("   ✗ Resolve failed:", err)
end
print()

print("=== Example Complete ===")
print("\nNote: If using test-key-replace-me, alerts won't actually be sent.")
print("Set PAGERDUTY_ROUTING_KEY environment variable to send real alerts.")
