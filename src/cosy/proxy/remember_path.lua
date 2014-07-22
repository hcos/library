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
    return rawget (self, PATH)
  end
  local below  = rawget (self, DATA)
  if not below then
    error "attempt to index a nil value"
  end
  local result = remember_path (below [key])
  local p = copy (self [PATH])
  p [#p + 1] = key
  rawset (result, PATH, p)
  return result
end

return remember_path
