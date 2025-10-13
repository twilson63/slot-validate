local http = require("http")

local GREEN = "\27[32m"
local RED = "\27[31m"
local YELLOW = "\27[33m"
local BLUE = "\27[34m"
local RESET = "\27[0m"

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
  io.write(string.format("%s[TEST]%s %s... ", BLUE, RESET, name))
  io.flush()
  
  local ok, err = pcall(fn)
  
  if ok then
    print(GREEN .. "✓ PASS" .. RESET)
    tests_passed = tests_passed + 1
  else
    print(RED .. "✗ FAIL" .. RESET)
    print(RED .. "  Error: " .. tostring(err) .. RESET)
    tests_failed = tests_failed + 1
  end
end

local function assert_equal(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\n  Expected: %s\n  Actual: %s", 
      message or "Values not equal", 
      tostring(expected), 
      tostring(actual)))
  end
end

local function assert_not_nil(value, message)
  if value == nil then
    error(message or "Value is nil")
  end
end

local function assert_type(value, expected_type, message)
  if type(value) ~= expected_type then
    error(string.format("%s\n  Expected type: %s\n  Actual type: %s", 
      message or "Type mismatch", 
      expected_type, 
      type(value)))
  end
end

test("JSON file loading", function()
  local file = io.open("test-process-map.json", "r")
  assert_not_nil(file, "test-process-map.json should exist")
  
  local content = file:read("*all")
  file:close()
  
  assert_type(content, "string", "File content should be string")
  assert(#content > 0, "File should not be empty")
end)

test("JSON parsing via HTTP", function()
  local test_json = '{"test": "value", "number": 123}'
  
  local resp, err = http.post("https://httpbin.org/anything", test_json, {["Content-Type"] = "application/json"})
  
  assert_not_nil(resp, "HTTP response should not be nil")
  assert_equal(resp.status, 200, "HTTP status should be 200")
  
  local data = resp.json()
  assert_not_nil(data, "Parsed JSON should not be nil")
  assert_not_nil(data.json, "Response should have json field")
  assert_equal(data.json.test, "value", "JSON field should match")
end)

test("HTTP GET request", function()
  local resp, err = http.get("https://httpbin.org/get")
  
  assert_not_nil(resp, "HTTP response should not be nil")
  assert_equal(resp.status, 200, "HTTP status should be 200")
  
  local data = resp.json()
  assert_not_nil(data, "Response should be valid JSON")
end)

test("HTTP request with error handling", function()
  local resp, err = http.get("https://httpbin.org/status/404")
  
  assert_not_nil(resp, "Response should exist even for 404")
  assert_equal(resp.status, 404, "Status should be 404")
end)

test("Retry logic simulation", function()
  local attempts = 0
  local max_retries = 3
  
  for attempt = 1, max_retries do
    attempts = attempts + 1
    if attempt == max_retries then
      break
    end
  end
  
  assert_equal(attempts, max_retries, "Should attempt all retries")
end)

test("Router nonce extraction structure", function()
  local mock_router_response = {
    assignment = {
      tags = {
        {name = "Process-Id", value = "test-id"},
        {name = "Nonce", value = "12345"},
        {name = "Timestamp", value = "1234567890"}
      }
    }
  }
  
  local nonce_found = false
  for _, tag in ipairs(mock_router_response.assignment.tags) do
    if tag.name == "Nonce" then
      nonce_found = true
      assert_equal(tag.value, "12345", "Nonce value should match")
      break
    end
  end
  
  assert(nonce_found, "Should find Nonce tag")
end)

test("URL construction", function()
  local process_id = "4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs"
  local target = "state-2.forward.computer"
  
  local slot_url = "https://" .. target .. "/" .. process_id .. "~process@1.0/compute/at-slot"
  local router_url = "https://su-router.ao-testnet.xyz/" .. process_id .. "/latest"
  
  assert(slot_url:match("^https://"), "Slot URL should start with https://")
  assert(router_url:match("^https://"), "Router URL should start with https://")
  assert(slot_url:match(process_id), "Slot URL should contain process ID")
  assert(router_url:match(process_id), "Router URL should contain process ID")
end)

test("String trimming logic", function()
  local test_string = "  12345  \n"
  local trimmed = test_string:match("^%s*(.-)%s*$")
  
  assert_equal(trimmed, "12345", "Should trim whitespace")
end)

test("Process ID formatting", function()
  local function format_process_id(pid)
    if #pid > 20 then
      return pid:sub(1, 10) .. "..." .. pid:sub(-7)
    end
    return pid
  end
  
  local long_id = "4hXj_E-5fAKmo4E8KjgQvuDJKAFk9P2grhycVmISDLs"
  local formatted = format_process_id(long_id)
  
  assert(#formatted < #long_id, "Formatted ID should be shorter")
  assert(formatted:match("%.%.%."), "Formatted ID should contain ellipsis")
end)

test("Result status categorization", function()
  local slot_nonce = "12345"
  local router_nonce_match = "12345"
  local router_nonce_mismatch = "67890"
  
  local status_match = (slot_nonce == router_nonce_match) and "match" or "mismatch"
  local status_mismatch = (slot_nonce == router_nonce_mismatch) and "match" or "mismatch"
  
  assert_equal(status_match, "match", "Equal nonces should match")
  assert_equal(status_mismatch, "mismatch", "Different nonces should mismatch")
end)

test("Coroutine creation", function()
  local co = coroutine.create(function()
    return "test_result"
  end)
  
  assert_type(co, "thread", "Should create coroutine")
  
  local ok, result = coroutine.resume(co)
  assert(ok, "Coroutine should resume successfully")
  assert_equal(result, "test_result", "Should return correct result")
  assert_equal(coroutine.status(co), "dead", "Coroutine should be dead after completion")
end)

test("Table operations", function()
  local items = {}
  
  table.insert(items, "item1")
  table.insert(items, "item2")
  table.insert(items, "item3")
  
  assert_equal(#items, 3, "Should have 3 items")
  
  local removed = table.remove(items, 2)
  assert_equal(removed, "item2", "Should remove correct item")
  assert_equal(#items, 2, "Should have 2 items after removal")
end)

print("\n" .. string.rep("━", 50))
print(string.format("%s%s Test Results %s%s", BLUE, string.rep("━", 17), string.rep("━", 17), RESET))
print(string.format("%s✓ Passed:%s %d", GREEN, RESET, tests_passed))
print(string.format("%s✗ Failed:%s %d", RED, RESET, tests_failed))
print(string.format("%sTotal:%s %d", BLUE, RESET, tests_passed + tests_failed))
print(string.rep("━", 50))

if tests_failed > 0 then
  print(RED .. "\nSome tests failed!" .. RESET)
  os.exit(1)
else
  print(GREEN .. "\nAll tests passed!" .. RESET)
  os.exit(0)
end
