local proxy    = require "cosy.util.proxy"
local raw      = require "cosy.util.raw"
local is_proxy = require "cosy.util.is_proxy"

local rawify = proxy ()

function rawify:__index (key)
  local raw_self  = raw (self)
  local raw_key   = raw (key)
  local value     = raw_self [raw_key]
  if is_proxy (value) then
    value = raw (value)
    rawset (raw_self, raw_key, value)
  end
  return rawify (value)
end

function rawify:__newindex (key, value)
  local raw_self  = raw (self)
  local raw_key   = raw (key)
  local raw_value = raw (value)
  rawset (raw_self, raw_key, raw_value)
end

return rawify
