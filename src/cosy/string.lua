local string_metatable = getmetatable ""
string_metatable.__mod = require "i18n.interpolate"

function string:quote ()
  if not self:find ('"') then
    return '"' .. self .. '"'
  elseif not self:find ("'") then
    return "'" .. self .. "'"
  end
  local pattern = ""
  while true do
    if not (   self:find ("%[" .. pattern .. "%[")
            or self:find ("%]" .. pattern .. "%]")) then
      return "[" .. pattern .. "[" .. self .. "]" .. pattern .. "]"
    end
    pattern = pattern .. "="
  end
end

function string:is_identifier ()
  local i, j = self:find ("[_%a][_%w]*")
  return i == 1 and j == #self
end

-- http://lua-users.org/wiki/StringTrim
function string:trim ()
  return self:match "^()%s*$" and "" or self:match "^%s*(.*%S)"
end
