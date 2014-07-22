local raw    = require "cosy.util.raw"
local proxy  = require "cosy.util.proxy"
local copy   = require "cosy.util.shallow_copy"
local tags   = require "cosy.util.tags"

local PATH  = tags.PATH

local remember_path = proxy {}

local forward = remember_path.__index

function remember_path:__index (key)
  if not rawget (self, PATH) then
    rawset (self, PATH, { raw (self) })
    return self [key]
  end
  local result = forward (self, key)
  if type (result) ~= "table" then
    return result
  end
  local p = copy (self [PATH])
  p [#p + 1] = key
  rawset (result, PATH, p)
  return result
end

return remember_path
