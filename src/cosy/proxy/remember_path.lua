local proxy  = require "cosy.util.proxy"
local copy   = require "cosy.util.shallow_copy"
local tags   = require "cosy.util.tags"

local PATH  = tags.PATH

local remember_path = proxy {}

local forward = remember_path.__index

local path = proxy {}

function path.__concat (lhs, rhs)
  local result = copy (lhs)
  result [#result + 1] = rhs
  return path (result)
end

function remember_path:__index (key)
  if not rawget (self, PATH) then
    rawset (self, PATH, path { self })
    return self [key]
  end
  local result = forward (self, key)
  if type (result) ~= "table" then
    return result
  end
  local p = self [PATH] .. key
  rawset (result, PATH, p)
  return result
end

return remember_path
