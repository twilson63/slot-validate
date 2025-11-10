local http = require("http")
local fs = require("fs")

local GREEN = "\27[32m"
local RED = "\27[31m"
local YELLOW = "\27[33m"
local BLUE = "\27[34m"
local RESET = "\27[0m"

local config = {
  concurrency = 10,
  verbose = false,
  only_mismatches = false,
  max_retries = 1,
  base_retry_delay = 0.5,
  file = "process-map.json",
  pagerduty_enabled = false,
  pagerduty_routing_key = (env and env.PAGERDUTY_ROUTING_KEY) or nil,
  pagerduty_mismatch_threshold = 3,
  pagerduty_error_threshold = 5,
  request_timeout = 5000,
  exclude_servers = {}
}

local function print_help()
  print([[
Usage: hype run validate-nonces.lua -- [options]

Options:
  --file=PATH                      Path to process map JSON file (default: process-map.json)
  --concurrency=N                  Number of concurrent requests (default: 10)
  --verbose                        Show detailed information for each process
  --only-mismatches                Only show processes with mismatched nonces
  --exclude-server=HOST            Exclude server (can be used multiple times)
  
  PagerDuty Options:
  --pagerduty-enabled              Enable PagerDuty alerting (default: false)
  --pagerduty-key=KEY              PagerDuty routing key (or use PAGERDUTY_ROUTING_KEY env var)
  --pagerduty-mismatch-threshold=N Alert if mismatches >= N (default: 3)
  --pagerduty-error-threshold=N    Alert if errors >= N (default: 5)
  --help                           Show this help message

Environment Variables:
  PAGERDUTY_ROUTING_KEY           PagerDuty Events API v2 routing key

Examples:
  hype run validate-nonces.lua -- --concurrency=20 --verbose
  hype run validate-nonces.lua -- --file=test-process-map.json
  hype run validate-nonces.lua -- --exclude-server=state-2.forward.computer
  hype run validate-nonces.lua -- --exclude-server=server1.com --exclude-server=server2.com
  
  # Enable PagerDuty with env var
  export PAGERDUTY_ROUTING_KEY="<your-key>"
  hype run validate-nonces.lua -- --pagerduty-enabled
  
  # Enable with CLI key
  hype run validate-nonces.lua -- --pagerduty-enabled --pagerduty-key=<key>
]])
  return
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
    elseif a == "--pagerduty-enabled" then
      config.pagerduty_enabled = true
    elseif a:match("^%-%-concurrency=") then
      local val = a:match("^%-%-concurrency=(%d+)$")
      if val then
        config.concurrency = tonumber(val)
      else
        print(RED .. "Error: Invalid concurrency value" .. RESET)
        return
      end
    elseif a:match("^%-%-file=") then
      local val = a:match("^%-%-file=(.+)$")
      if val then
        config.file = val
      else
        print(RED .. "Error: Invalid file path" .. RESET)
        return
      end
    elseif a:match("^%-%-exclude%-server=") then
      local val = a:match("^%-%-exclude%-server=(.+)$")
      if val then
        table.insert(config.exclude_servers, val)
      end
    elseif a:match("^%-%-pagerduty%-key=") then
      config.pagerduty_routing_key = a:match("^%-%-pagerduty%-key=(.+)$")
    elseif a:match("^%-%-pagerduty%-mismatch%-threshold=") then
      local val = a:match("=(%d+)$")
      if val then
        config.pagerduty_mismatch_threshold = tonumber(val)
      end
    elseif a:match("^%-%-pagerduty%-error%-threshold=") then
      local val = a:match("=(%d+)$")
      if val then
        config.pagerduty_error_threshold = tonumber(val)
      end
    end
  end
end

local function load_process_map()
  local ok, content = pcall(function()
    return fs.readFileSync(config.file)
  end)
  
  if not ok then
    return nil, "Could not open " .. config.file .. ": " .. tostring(content)
  end
  
  local trimmed = content:match("^%s*(.-)%s*$")
  if not trimmed or trimmed == "" then
    return nil, "Invalid JSON: file is empty"
  end
  
  if not trimmed:match("^{.*}$") then
    return nil, "Invalid JSON: must be an object enclosed in {}"
  end
  
  local open_count = 0
  local close_count = 0
  for c in content:gmatch("[{}]") do
    if c == "{" then
      open_count = open_count + 1
    else
      close_count = close_count + 1
    end
  end
  
  if open_count ~= close_count or open_count == 0 then
    return nil, "Invalid JSON: unbalanced braces (found " .. open_count .. " '{' and " .. close_count .. " '}')"
  end
  
  local process_map = {}
  
  for key, value in content:gmatch('"([^"\\]*)"%s*:%s*"([^"\\]*)"') do
    process_map[key] = value
  end
  
  for key, value in content:gmatch('"([^"]*\\.[^"]*)"%s*:%s*"([^"]*)"') do
    local unescaped_key = key:gsub('\\(.)', '%1')
    local unescaped_value = value:gsub('\\(.)', '%1')
    if not process_map[unescaped_key] then
      process_map[unescaped_key] = unescaped_value
    end
  end
  
  if next(process_map) == nil then
    return nil, "Invalid JSON: no valid key-value pairs found"
  end
  
  return process_map, nil
end

local function sleep(seconds)
  local start = os.time()
  while os.time() - start < seconds do
  end
end

local function fetch_with_retry(url, max_retries)
  for attempt = 1, max_retries do
    local ok, resp = pcall(function()
      return http.fetch(url, {
        method = "GET",
        timeout = config.request_timeout
      })
    end)
    
    if ok and resp.status == 200 then
      return resp, nil
    end
    
    if attempt < max_retries then
      local delay = config.base_retry_delay * (2 ^ (attempt - 1))
      sleep(delay)
    else
      if ok then
        return nil, "HTTP " .. tostring(resp.status) .. ": " .. (resp.statusText or "error")
      else
        return nil, tostring(resp)
      end
    end
  end
  return nil, "Max retries exceeded"
end

local function extract_router_nonce(resp)
  local ok, data = pcall(function()
    return resp:json()
  end)
  
  if not ok then
    return nil, "Failed to parse JSON response: " .. tostring(data)
  end
  
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
  
  local slot_nonce = slot_resp:text():match("^%s*(.-)%s*$")
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
      -- Progress indicator (io.write not available in hype-rs)
      print(string.format("%sProcessed %d/%d...%s", BLUE, idx, #items, RESET))
    end
  end
  
  -- Clear progress line (io.write not available in hype-rs)
  print("")
  
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

local AlertManager = {}
AlertManager.__index = AlertManager

function AlertManager.new(cfg)
  local self = setmetatable({}, AlertManager)
  self.config = cfg
  self.pd = nil
  self.alerts_sent = 0
  self.enabled = false
  
  if cfg.pagerduty_enabled then
    if not cfg.pagerduty_routing_key or cfg.pagerduty_routing_key == "" then
      print("Warning: PagerDuty enabled but no routing key provided")
      print("Set PAGERDUTY_ROUTING_KEY env var or use --pagerduty-key flag")
      return self
    end
    
    local ok, pagerduty = pcall(require, "pagerduty")
    if ok then
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
        print(string.format("Warning: PagerDuty initialization failed: %s", tostring(pd_or_err)))
      end
    else
      print("Warning: PagerDuty library not found (pagerduty.lua)")
    end
  end
  
  return self
end

function AlertManager:build_dedup_key(alert_type)
  return string.format("slot-nonce-validation-%s-%s", 
    os.date("!%Y-%m-%d"), alert_type)
end

function AlertManager:should_alert(alert_type, count, threshold)
  if not self.enabled then
    return false
  end
  
  if count < threshold then
    return false
  end
  
  return true
end

function AlertManager:send_alert(severity, summary, details)
  if not self.enabled then
    return true
  end
  
  local dedup_key = self:build_dedup_key(details.alert_type or "validation")
  
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
  
  print(string.format("PagerDuty alert failed: %s", tostring(err)))
  return false
end

function AlertManager:build_mismatch_alert(results, start_time)
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
        difference = tonumber(result.slot_nonce or 0) - tonumber(result.router_nonce or 0),
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

function AlertManager:build_error_alert(results, start_time)
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

local function main()
  parse_args()
  
  local alert_mgr = AlertManager.new(config)
  
  local ok, main_err = pcall(function()
    print(BLUE .. "Loading process map..." .. RESET)
    local process_map, err = load_process_map()
    if not process_map then
      if alert_mgr.enabled then
        alert_mgr:send_alert("critical",
          "Slot Nonce Validation: Script execution failed",
          {
            alert_type = "failure",
            error = err,
            failure_point = "load_process_map",
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
          })
      end
      error(err)
    end
    
    local processes = {}
    local excluded_count = 0
    for process_id, target in pairs(process_map) do
      local clean_target = target:gsub("^https?://", "")
      local excluded = false
      
      for _, exclude in ipairs(config.exclude_servers) do
        if clean_target:find(exclude, 1, true) then
          excluded = true
          excluded_count = excluded_count + 1
          break
        end
      end
      
      if not excluded then
        table.insert(processes, {
          process_id = process_id,
          target = clean_target
        })
      end
    end
    
    if excluded_count > 0 then
      print(string.format("%sExcluded %d processes from filtered servers%s", YELLOW, excluded_count, RESET))
    end
    
    if #processes == 0 then
      print(YELLOW .. "No processes found in process-map.json" .. RESET)
      return
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
    
    if alert_mgr:should_alert("mismatches", mismatches, config.pagerduty_mismatch_threshold) then
      local details = alert_mgr:build_mismatch_alert(results, start_time)
      alert_mgr:send_alert("critical",
        string.format("Slot Nonce Validation: %d mismatches detected", mismatches),
        details)
    end
    
    if alert_mgr:should_alert("errors", errors, config.pagerduty_error_threshold) then
      local details = alert_mgr:build_error_alert(results, start_time)
      alert_mgr:send_alert("error",
        string.format("Slot Nonce Validation: %d errors occurred", errors),
        details)
    end
    
    local elapsed = os.time() - start_time
    
    print(string.format("\n%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s", BLUE, RESET))
    print(string.format("%sSummary:%s", BLUE, RESET))
    print(string.format("  %s✓ Matches:%s %d", GREEN, RESET, matches))
    print(string.format("  %s✗ Mismatches:%s %d", RED, RESET, mismatches))
    print(string.format("  %s⚠ Errors:%s %d", YELLOW, RESET, errors))
    print(string.format("  %sTotal:%s %d", BLUE, RESET, #processes))
    print(string.format("  %sTime elapsed:%s %ds", BLUE, RESET, elapsed))
    
    if alert_mgr.enabled then
      if alert_mgr.alerts_sent > 0 then
        print(string.format("  %s📟 PagerDuty:%s %d alert(s) sent", BLUE, RESET, alert_mgr.alerts_sent))
      else
        print(string.format("  %s📟 PagerDuty:%s No alerts triggered", BLUE, RESET))
      end
    end
    
    print(string.format("%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s", BLUE, RESET))
    
    if mismatches > 0 then
      return
    end
  end)
  
  if not ok then
    print(RED .. "Fatal error: " .. tostring(main_err) .. RESET)
    return
  end
end

main()
