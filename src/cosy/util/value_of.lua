local tags    = require "cosy.util.tags"
local is_tag  = require "cosy.util.is_tag"
local path_of = require "cosy.util.path_of"

local NAME = tags.NAME

local function value_of (value, seen)
  if value == nil then
    return "nil"
  elseif type (value) == "string" then
    return  "[[" .. value .. "]]"
  elseif type (value) == "number" then
    return tostring (value)
  elseif type (value) == "boolean" then
    return tostring (value)
  elseif type (value) == "table" and is_tag (value) then
    return "tags." .. value [NAME]
  elseif type (value) == "table" and seen [value] then
    return path_of (seen [value])
  elseif type (value) == "table" then
    return "{}"
  else
    error ("cannot create patch from data type " .. type (value))
  end
end

return value_of
