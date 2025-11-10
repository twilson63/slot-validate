local http = require("http")

local function json_encode_string(str)
  str = str:gsub('\\', '\\\\')
  str = str:gsub('"', '\\"')
  str = str:gsub('\n', '\\n')
  str = str:gsub('\r', '\\r')
  str = str:gsub('\t', '\\t')
  str = str:gsub('\b', '\\b')
  str = str:gsub('\f', '\\f')
  return '"' .. str .. '"'
end

local function is_array(tbl)
  if type(tbl) ~= "table" then
    return false
  end
  
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

local function json_encode(value, seen)
  seen = seen or {}
  local vtype = type(value)
  
  if vtype == "nil" then
    return "null"
  end
  
  if vtype == "boolean" then
    return value and "true" or "false"
  end
  
  if vtype == "number" then
    if value ~= value then
      error("Cannot encode NaN")
    elseif value == math.huge or value == -math.huge then
      error("Cannot encode Infinity")
    end
    return tostring(value)
  end
  
  if vtype == "string" then
    return json_encode_string(value)
  end
  
  if vtype == "table" then
    if seen[value] then
      error("Circular reference detected")
    end
    seen[value] = true
    
    local result
    if is_array(value) then
      local parts = {}
      for i = 1, #value do
        table.insert(parts, json_encode(value[i], seen))
      end
      result = "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for k, v in pairs(value) do
        if type(k) == "string" then
          local encoded_key = json_encode_string(k)
          local encoded_value = json_encode(v, seen)
          table.insert(parts, encoded_key .. ":" .. encoded_value)
        end
      end
      result = "{" .. table.concat(parts, ",") .. "}"
    end
    
    seen[value] = nil
    return result
  end
  
  error("Cannot encode type: " .. vtype)
end

local function json_decode_response(json_str)
  if not json_str or json_str == "" then
    return nil, "Empty response"
  end
  
  local data = {}
  
  data.status = json_str:match('"status"%s*:%s*"([^"]+)"')
  data.message = json_str:match('"message"%s*:%s*"([^"]+)"')
  data.dedup_key = json_str:match('"dedup_key"%s*:%s*"([^"]+)"')
  
  return data, nil
end

local function validate_event(event_data)
  if not event_data.event_action then
    return false, "event_action is required"
  end
  
  local valid_actions = {trigger = true, acknowledge = true, resolve = true}
  if not valid_actions[event_data.event_action] then
    return false, "event_action must be 'trigger', 'acknowledge', or 'resolve'"
  end
  
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

function PagerDuty:event(event_data)
  local valid, err = validate_event(event_data)
  if not valid then
    return false, err
  end
  
  local request = {
    routing_key = self.routing_key,
    event_action = event_data.event_action
  }
  
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
  
  local ok, body_or_err = pcall(json_encode, request)
  if not ok then
    return false, "JSON encoding error: " .. tostring(body_or_err)
  end
  local body = body_or_err
  
  local http_ok, resp = pcall(function()
    return http.fetch(self.endpoint, {
      method = "POST",
      body = body,
      headers = {
        ["Content-Type"] = "application/json"
      }
    })
  end)
  
  if not http_ok then
    return false, "HTTP error: " .. tostring(resp)
  end
  
  if resp.status == 202 then
    return true, nil
  elseif resp.status == 400 then
    local data, _ = json_decode_response(resp:text())
    return false, "Bad request: " .. (data and data.message or "Invalid event")
  elseif resp.status == 429 then
    return false, "Rate limited: Too many requests"
  elseif resp.status >= 500 then
    return false, "Server error: HTTP " .. resp.status
  else
    return false, "HTTP " .. resp.status .. ": " .. (resp:text() or "Unknown error")
  end
end

PagerDuty._json_encode = json_encode

return PagerDuty
