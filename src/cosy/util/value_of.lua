local tags      = require "cosy.util.tags"
local is_tag    = require "cosy.util.is_tag"
local path_of -- Cyclic dependency

local NAME = tags.NAME

local function value_of (value, named)
  if not path_of then
    path_of = require "cosy.util.path_of"
  end
  named = named or {}
  if value == nil then
    return "nil"
  elseif type (value) == "boolean" then
    return tostring (value)
  elseif type (value) == "number" then
    return tostring (value)
  elseif type (value) == "string" then
    if not value:find ('"') then
      return '"' .. value .. '"'
    elseif not value:find ("'") then
      return "'" .. value .. "'"
    end
    local pattern = ""
    while true do
      if not (   value:find ("%[" .. pattern .. "%[")
              or value:find ("%]" .. pattern .. "%]")) then
        return "[" .. pattern .. "[" .. value .. "]" .. pattern .. "]"
      end
      pattern = pattern .. "="
    end
  elseif type (value) == "table" and is_tag (value) then
    return "tags." .. value [NAME]
  elseif type (value) == "table" and named [value] then
    return path_of (named [value])
  elseif type (value) == "table" then
    return nil
  elseif type (value) == "function" then
    return string.dump (value)
  else
    error ("Unable to dump value for data type " .. type (value))
  end
end

return value_of
