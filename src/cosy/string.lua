local Platform = require "cosy.platform"

local metatable = getmetatable ""

metatable.__mod = Platform.i18n.interpolate
--    > require "cosy.string"
--    > print ("%{key}" % { key = "some text" })
--    ...
--    some text

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
--    > require "cosy.string"
--    > local text = "abc"
--    > print (text:quote ())
--    ...
--    "abc"
--    > local text = [[a"bc]]
--    > print (text:quote ())
--    ...
--    'a"bc'
--    > local text = [[a'bc]]
--    > print (text:quote ())
--    ...
--    "a'bc"
--    > local text = [[a"b'c]]
--    > print (text:quote ())
--    ...
--    [[a"b'c]]
--    > local text = [=[a[["b']]c]=]
--    > print (text:quote ())
--    ...
--    [=[a[["b']]c]=]

function string:is_identifier ()
  local i, j = self:find ("[_%a][_%w]*")
  return i == 1 and j == #self
end
--    > require "cosy.string"
--    > local text = "abc"
--    > print (text:is_identifier ())
--    ...
--    true
--    > local text = "0abc"
--    > print (text:is_identifier ())
--    ...
--    false

-- http://lua-users.org/wiki/StringTrim
function string:trim ()
  return self:match "^()%s*$" and "" or self:match "^%s*(.*%S)"
end
--    > require "cosy.string"
--    > local text = "   abc   def   "
--    > print (text:trim ())
--    ...
--    abc   def
