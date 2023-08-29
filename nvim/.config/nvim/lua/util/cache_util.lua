local M = {}
local cache = {}

local function cache_func(auto_event, cache_key, action)
  -- use string as key
  if cache[cache_key] ~= nil then
    return cache[cache_key]
  end
  val, code = action(cache_key)
  if code == 0 then
    if val ~= nil then
    end
    cache[cache_key] = val
    return val
  end
  return nil
end

local cache_on_buffer = function(auto_event, cache_key, action)
  return cache_func(auto_event, cache_key, action)
end

local function set_cache(cache_key, val)
  cache[cache_key] = val
end

M.set_cache = set_cache
M.cache_on_buffer = cache_on_buffer
return M
