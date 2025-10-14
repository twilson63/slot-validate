local pagerduty = require("pagerduty")

local GREEN = "\27[32m"
local RED = "\27[31m"
local YELLOW = "\27[33m"
local BLUE = "\27[34m"
local RESET = "\27[0m"

local tests_passed = 0
local tests_failed = 0

local function assert_equal(actual, expected, test_name)
  if actual == expected then
    print(string.format("%s✓%s %s", GREEN, RESET, test_name))
    tests_passed = tests_passed + 1
    return true
  else
    print(string.format("%s✗%s %s", RED, RESET, test_name))
    print(string.format("  Expected: %s", tostring(expected)))
    print(string.format("  Actual: %s", tostring(actual)))
    tests_failed = tests_failed + 1
    return false
  end
end

local function assert_match(actual, pattern, test_name)
  if type(actual) == "string" and actual:match(pattern) then
    print(string.format("%s✓%s %s", GREEN, RESET, test_name))
    tests_passed = tests_passed + 1
    return true
  else
    print(string.format("%s✗%s %s", RED, RESET, test_name))
    print(string.format("  Expected pattern: %s", pattern))
    print(string.format("  Actual: %s", tostring(actual)))
    tests_failed = tests_failed + 1
    return false
  end
end

local function assert_contains(actual, substring, test_name)
  if type(actual) == "string" and actual:find(substring, 1, true) then
    print(string.format("%s✓%s %s", GREEN, RESET, test_name))
    tests_passed = tests_passed + 1
    return true
  else
    print(string.format("%s✗%s %s", RED, RESET, test_name))
    print(string.format("  Expected to contain: %s", substring))
    print(string.format("  Actual: %s", tostring(actual)))
    tests_failed = tests_failed + 1
    return false
  end
end

print(string.format("\n%s=== PagerDuty Library Test Suite ===%s\n", BLUE, RESET))

print(string.format("%s--- Test 1: JSON Encoding - Basic Types ---%s", YELLOW, RESET))
local json_encode = pagerduty._json_encode

assert_equal(json_encode(nil), "null", "Encode nil as null")
assert_equal(json_encode(true), "true", "Encode true as true")
assert_equal(json_encode(false), "false", "Encode false as false")
assert_equal(json_encode(42), "42", "Encode number 42")
assert_equal(json_encode(3.14), "3.14", "Encode number 3.14")
assert_equal(json_encode("hello"), '"hello"', "Encode string 'hello'")

print(string.format("\n%s--- Test 2: JSON Encoding - String Escaping ---%s", YELLOW, RESET))
assert_equal(json_encode("hello \"world\""), '"hello \\"world\\""', "Escape quotes")
assert_equal(json_encode("line1\nline2"), '"line1\\nline2"', "Escape newlines")
assert_equal(json_encode("tab\there"), '"tab\\there"', "Escape tabs")
assert_equal(json_encode("back\\slash"), '"back\\\\slash"', "Escape backslashes")

print(string.format("\n%s--- Test 3: JSON Encoding - Arrays ---%s", YELLOW, RESET))
assert_equal(json_encode({1, 2, 3}), "[1,2,3]", "Encode simple array")
assert_equal(json_encode({"a", "b", "c"}), '["a","b","c"]', "Encode string array")
assert_equal(json_encode({1, "two", true}), '[1,"two",true]', "Encode mixed array")
assert_equal(json_encode({}), "{}", "Encode empty table as object")

print(string.format("\n%s--- Test 4: JSON Encoding - Objects ---%s", YELLOW, RESET))
local obj1 = json_encode({key = "value"})
assert_contains(obj1, '"key"', "Object contains key")
assert_contains(obj1, '"value"', "Object contains value")

local obj2 = json_encode({name = "test", count = 42, active = true})
assert_contains(obj2, '"name"', "Object contains name field")
assert_contains(obj2, '"count"', "Object contains count field")
assert_contains(obj2, '"active"', "Object contains active field")

print(string.format("\n%s--- Test 5: JSON Encoding - Nested Structures ---%s", YELLOW, RESET))
local nested = json_encode({
  array = {1, 2, 3},
  object = {key = "value"},
  mixed = {
    nested_array = {"a", "b"},
    nested_object = {x = 1}
  }
})
assert_contains(nested, '"array"', "Contains array field")
assert_contains(nested, '[1,2,3]', "Contains array values")
assert_contains(nested, '"object"', "Contains object field")
assert_contains(nested, '"key"', "Contains nested key")

print(string.format("\n%s--- Test 6: JSON Encoding - Edge Cases ---%s", YELLOW, RESET))
local ok, err = pcall(json_encode, 0/0)
assert_equal(ok, false, "Reject NaN")
assert_contains(err, "NaN", "Error message mentions NaN")

local ok2, err2 = pcall(json_encode, 1/0)
assert_equal(ok2, false, "Reject Infinity")
assert_contains(err2, "Infinity", "Error message mentions Infinity")

local circular = {}
circular.self = circular
local ok3, err3 = pcall(json_encode, circular)
assert_equal(ok3, false, "Reject circular reference")
assert_contains(err3, "Circular", "Error message mentions circular")

print(string.format("\n%s--- Test 7: PagerDuty Client - Initialization ---%s", YELLOW, RESET))
local ok4, err4 = pcall(pagerduty.new, {})
assert_equal(ok4, false, "Reject empty config")
assert_contains(err4, "routing_key", "Error mentions routing_key")

local ok5, err5 = pcall(pagerduty.new, {routing_key = ""})
assert_equal(ok5, false, "Reject empty routing key")
assert_contains(err5, "empty", "Error mentions empty")

local ok6, pd = pcall(pagerduty.new, {routing_key = "test-key-12345"})
assert_equal(ok6, true, "Accept valid routing key")
assert_equal(type(pd), "table", "Return PagerDuty client")

print(string.format("\n%s--- Test 8: PagerDuty Client - Validation ---%s", YELLOW, RESET))
local pd_test = pagerduty.new({routing_key = "test-key"})

local ok7, err7 = pd_test:event({})
assert_equal(ok7, false, "Reject missing event_action")
assert_contains(err7, "event_action", "Error mentions event_action")

local ok8, err8 = pd_test:event({event_action = "invalid"})
assert_equal(ok8, false, "Reject invalid event_action")
assert_contains(err8, "trigger", "Error mentions valid actions")

local ok9, err9 = pd_test:event({event_action = "trigger"})
assert_equal(ok9, false, "Reject missing payload")
assert_contains(err9, "payload", "Error mentions payload")

local ok10, err10 = pd_test:event({
  event_action = "trigger",
  payload = {}
})
assert_equal(ok10, false, "Reject missing summary")
assert_contains(err10, "summary", "Error mentions summary")

local ok11, err11 = pd_test:event({
  event_action = "trigger",
  payload = {summary = "test"}
})
assert_equal(ok11, false, "Reject missing severity")
assert_contains(err11, "severity", "Error mentions severity")

local ok12, err12 = pd_test:event({
  event_action = "trigger",
  payload = {
    summary = "test",
    severity = "invalid"
  }
})
assert_equal(ok12, false, "Reject invalid severity")
assert_contains(err12, "critical", "Error mentions valid severities")

local ok13, err13 = pd_test:event({
  event_action = "trigger",
  payload = {
    summary = "test",
    severity = "critical"
  }
})
assert_equal(ok13, false, "Reject missing source")
assert_contains(err13, "source", "Error mentions source")

print(string.format("\n%s--- Test 9: PagerDuty Client - Valid Event Structure ---%s", YELLOW, RESET))
local pd_real = pagerduty.new({routing_key = "test-key-invalid"})

local ok14, err14 = pd_real:event({
  event_action = "trigger",
  payload = {
    summary = "Test alert",
    severity = "critical",
    source = "test-script",
    custom_details = {
      test = true,
      nested = {value = 123},
      array = {1, 2, 3}
    }
  }
})

assert_equal(ok14, false, "Reject invalid routing key (expected network error)")
if err14 then
  print(string.format("  %sError (expected):%s %s", BLUE, RESET, err14))
end

print(string.format("\n%s--- Test 10: Event Actions ---%s", YELLOW, RESET))
local ok15, err15 = pd_test:event({
  event_action = "acknowledge",
  dedup_key = "test-key"
})
assert_equal(ok15, false, "Acknowledge requires valid key (network error expected)")

local ok16, err16 = pd_test:event({
  event_action = "resolve",
  dedup_key = "test-key"
})
assert_equal(ok16, false, "Resolve requires valid key (network error expected)")

print(string.format("\n%s=== Test Results ===%s", BLUE, RESET))
print(string.format("Total tests: %d", tests_passed + tests_failed))
print(string.format("%sPassed: %d%s", GREEN, tests_passed, RESET))
if tests_failed > 0 then
  print(string.format("%sFailed: %d%s", RED, tests_failed, RESET))
  os.exit(1)
else
  print(string.format("%s✓ All tests passed!%s", GREEN, RESET))
  os.exit(0)
end
