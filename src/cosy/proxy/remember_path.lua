local raw   = require "cosy.util.raw"
local proxy = require "cosy.util.proxy"
local copy  = require "cosy.util.shallow_copy"
local tags  = require "cosy.util.tags"

local DATA  = tags.DATA
local PATH  = tags.PATH

local remember_path = proxy {}

function remember_path:__index (key)
  if key == PATH then
    rawset (self, PATH, { raw (self) })
    return self [PATH]
  end
  local below  = self [DATA]
  local result = self (below [key])
  local p = copy (self [PATH])
  p [#p + 1] = key
  rawset (result, PATH, p)
  return result
end

function remember_path:__newindex (key, value)
  if key == PATH then
    error "Trying to set the PATH attribute."
  end
  local p = copy (self [PATH])
  p [#p + 1] = key
  local v = self (value)
  rawset (v, PATH, p)
  local below = self [DATA]
  below [key] = value
end

return remember_path, PATH
