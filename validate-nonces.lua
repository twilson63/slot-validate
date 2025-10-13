local http = require("http")

local GREEN = "\27[32m"
local RED = "\27[31m"
local YELLOW = "\27[33m"
local BLUE = "\27[34m"
local RESET = "\27[0m"

local config = {
  concurrency = 10,
  verbose = false,
  only_mismatches = false,
  max_retries = 3,
  base_retry_delay = 1,
  file = "process-map.json"
}

local function print_help()
  print([[
Usage: hype run validate-nonces.lua -- [options]

Options:
  --file=PATH          Path to process map JSON file (default: process-map.json)
  --concurrency=N      Number of concurrent requests (default: 10)
  --verbose            Show detailed information for each process
  --only-mismatches    Only show processes with mismatched nonces
  --help               Show this help message

Example:
  hype run validate-nonces.lua -- --concurrency=20 --verbose
  hype run validate-nonces.lua -- --file=test-process-map.json
]])
  os.exit(0)
end

local function parse_args()
  for i = 1, #arg do
    local a = arg[i]
    if a == "--help" then
      print_help()
    elseif a == "--verbose" then
      config.verbose = true
    elseif a == "--only-mismatches" then
      config.only_mismatches = true
    elseif a:match("^%-%-concurrency=") then
      local val = a:match("^%-%-concurrency=(%d+)$")
      if val then
        config.concurrency = tonumber(val)
      else
        print(RED .. "Error: Invalid concurrency value" .. RESET)
        os.exit(1)
      end
    elseif a:match("^%-%-file=") then
      local val = a:match("^%-%-file=(.+)$")
      if val then
        config.file = val
      else
        print(RED .. "Error: Invalid file path" .. RESET)
        os.exit(1)
      end
    end
  end
end

local function load_process_map()
  local file = io.open(config.file, "r")
  if not file then
    return nil, "Could not open " .. config.file
  end
  local content = file:read("*all")
  file:close()
  
  local resp, err = http.post("https://httpbin.org/anything", content, {["Content-Type"] = "application/json"})
  if err or not resp then
    return nil, "Failed to parse JSON: " .. tostring(err)
  end
  
  local data = resp.json()
  if data and data.json then
    return data.json
  end
  return nil, "Invalid JSON structure"
end

local function sleep(seconds)
  local start = os.time()
  while os.time() - start < seconds do
  end
end

local function fetch_with_retry(url, max_retries)
  for attempt = 1, max_retries do
    local resp, err = http.get(url)
    if resp and resp.status == 200 then
      return resp, nil
    end
    
    if attempt < max_retries then
      local delay = config.base_retry_delay * (2 ^ (attempt - 1))
      sleep(delay)
    else
      return nil, err or ("HTTP " .. tostring(resp and resp.status or "error"))
    end
  end
  return nil, "Max retries exceeded"
end

local function extract_router_nonce(resp)
  local data = resp.json()
  if not data or not data.assignment or not data.assignment.tags then
    return nil, "Invalid router response structure"
  end
  
  for _, tag in ipairs(data.assignment.tags) do
    if tag.name == "Nonce" then
      return tag.value, nil
    end
  end
  
  return nil, "Nonce tag not found"
end

local function validate_process(entry)
  local process_id = entry.process_id
  local target = entry.target
  
  local slot_url = "https://" .. target .. "/" .. process_id .. "~process@1.0/compute/at-slot"
  local router_url = "https://su-router.ao-testnet.xyz/" .. process_id .. "/latest"
  
  local slot_resp, slot_err = fetch_with_retry(slot_url, config.max_retries)
  local router_resp, router_err = fetch_with_retry(router_url, config.max_retries)
  
  local result = {
    process_id = process_id,
    target = target,
    status = "error",
    slot_url = slot_url,
    router_url = router_url
  }
  
  if slot_err then
    result.error = "Slot endpoint: " .. slot_err
    return result
  end
  
  if router_err then
    result.error = "Router endpoint: " .. router_err
    return result
  end
  
  local slot_nonce = slot_resp.body:match("^%s*(.-)%s*$")
  local router_nonce, extract_err = extract_router_nonce(router_resp)
  
  if extract_err then
    result.error = extract_err
    return result
  end
  
  result.slot_nonce = slot_nonce
  result.router_nonce = router_nonce
  
  if slot_nonce == router_nonce then
    result.status = "match"
  else
    result.status = "mismatch"
  end
  
  return result
end

local function process_concurrent(items, worker_fn, max_concurrent)
  local results = {}
  
  for idx = 1, #items do
    local result = worker_fn(items[idx])
    results[idx] = result
    
    if idx % 10 == 0 or idx == #items then
      io.write(string.format("\r%sProcessed %d/%d...%s", BLUE, idx, #items, RESET))
      io.flush()
    end
  end
  
  io.write("\r" .. string.rep(" ", 50) .. "\r")
  io.flush()
  
  return results
end

local function format_process_id(pid)
  if not pid or pid == "" then
    return "unknown"
  end
  if string.len(pid) > 20 then
    return string.sub(pid, 1, 10) .. "..." .. string.sub(pid, -7)
  end
  return pid
end

local function print_result(result)
  if not result then
    print(RED .. "Error: nil result" .. RESET)
    return
  end
  local pid_short = format_process_id(result.process_id)
  
  if result.status == "match" then
    if not config.only_mismatches then
      local line = string.format("%s✓%s %s (nonce: %s)", GREEN, RESET, pid_short, result.slot_nonce)
      if config.verbose then
        line = line .. string.format(" [%s]", result.target)
      end
      print(line)
    end
  elseif result.status == "mismatch" then
    local line = string.format("%s✗%s %s", RED, RESET, pid_short)
    if config.verbose then
      line = line .. string.format(" [%s]", result.target)
    end
    print(line)
    print(string.format("  Slot:   %s", result.slot_nonce))
    print(string.format("  Router: %s", result.router_nonce))
    print("  URLs:")
    print(string.format("    Slot:   %s", result.slot_url))
    print(string.format("    Router: %s", result.router_url))
  else
    if not config.only_mismatches then
      local line = string.format("%s⚠%s %s: %s", YELLOW, RESET, pid_short, result.error)
      if config.verbose then
        line = string.format("%s⚠%s %s [%s]: %s", YELLOW, RESET, pid_short, result.target, result.error)
      end
      print(line)
    end
  end
end

local function main()
  parse_args()
  
  print(BLUE .. "Loading process map..." .. RESET)
  local process_map, err = load_process_map()
  if not process_map then
    print(RED .. "Error: " .. err .. RESET)
    os.exit(1)
  end
  
  local processes = {}
  for process_id, target in pairs(process_map) do
    table.insert(processes, {
      process_id = process_id,
      target = target:gsub("^https?://", "")
    })
  end
  
  if #processes == 0 then
    print(YELLOW .. "No processes found in process-map.json" .. RESET)
    os.exit(0)
  end
  
  print(string.format("%sValidating %d processes with concurrency %d...%s\n", BLUE, #processes, config.concurrency, RESET))
  
  local start_time = os.time()
  
  local results = process_concurrent(processes, validate_process, config.concurrency)
  
  local matches = 0
  local mismatches = 0
  local errors = 0
  
  for _, result in ipairs(results) do
    if result then
      print_result(result)
      
      if result.status == "match" then
        matches = matches + 1
      elseif result.status == "mismatch" then
        mismatches = mismatches + 1
      else
        errors = errors + 1
      end
    end
  end
  
  local elapsed = os.time() - start_time
  
  print(string.format("\n%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s", BLUE, RESET))
  print(string.format("%sSummary:%s", BLUE, RESET))
  print(string.format("  %s✓ Matches:%s %d", GREEN, RESET, matches))
  print(string.format("  %s✗ Mismatches:%s %d", RED, RESET, mismatches))
  print(string.format("  %s⚠ Errors:%s %d", YELLOW, RESET, errors))
  print(string.format("  %sTotal:%s %d", BLUE, RESET, #processes))
  print(string.format("  %sTime elapsed:%s %ds", BLUE, RESET, elapsed))
  print(string.format("%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s", BLUE, RESET))
  
  if mismatches > 0 then
    os.exit(1)
  end
end

main()
