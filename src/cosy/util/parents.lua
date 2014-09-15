local tags   = require "cosy.util.tags"
local raw    = require "cosy.util.raw"
local set    = require "cosy.util.set"

local TYPE       = tags.TYPE
local PROTOTYPES = tags.PROTOTYPES

local function parents (x, result)
  x      = raw (x)
  result = result or {}
  if result [x] then
    return result
  end
  result [x] = true
  if x [TYPE] then
    parents (x [TYPE], result)
  end
  for p in set (x [PROTOTYPES] or {}) do
    parents (p, result)
  end
  return set (result)
end

return parents
