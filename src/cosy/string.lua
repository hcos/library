local metatable = getmetatable ""
local string    = string

--    > require "cosy.string"

-- taken from i18n/interpolate
metatable.__mod = function (pattern, variables)
  variables = variables or {}
  return pattern:gsub ("(.?)%%{(.-)}", function (previous, key)
    if previous == "%" then
      return
    end
    local value = tostring (variables [key])
    return previous .. value
  end)
end

--    > = "%{_1}-%{_2}-%{_3}" % {
--    >     _1 = "abc",
--    >     _2 = true,
--    >     _3 = nil,
--    >   }
--    "abc-true-nil"

--    > = "%%{_1}-%%{_2}-%%{_3}" % {
--    >     _1 = "abc",
--    >     _2 = true,
--    >     _3 = nil,
--    >   }
--    "%%{_1}-%%{_2}-%%{_3}"

-- http://stackoverflow.com/questions/9790688/escaping-strings-for-gsub
function string.escape (s)
  return s
        :gsub('%%', '%%%%')
        :gsub('%^', '%%%^')
        :gsub('%$', '%%%$')
        :gsub('%(', '%%%(')
        :gsub('%)', '%%%)')
        :gsub('%.', '%%%.')
        :gsub('%[', '%%%[')
        :gsub('%]', '%%%]')
        :gsub('%*', '%%%*')
        :gsub('%+', '%%%+')
        :gsub('%-', '%%%-')
        :gsub('%?', '%%%?')
end

metatable.__div = function (pattern, s)
  local names = {}
  pattern = pattern:escape ()
  pattern = pattern:gsub ("(.?)%%%%{(.-)}", function (previous, key)
    if previous == "%" then
      return
    end
    names [#names+1] = key
    return previous .. "(.*)"
  end)
  if pattern:sub (1,1) ~= "^" then
    pattern = "^" .. pattern
  end
  if pattern:sub (-1,1) ~= "$" then
    pattern = pattern .. "$"
  end
  local results = { s:match (pattern) }
  if #results == 0 then
    return nil
  end
  local result  = {}
  for i = 1, #names do
    result [names [i]] = results [i]
  end
  return result
end

--    > = "abc%{key}xyz" / "abcdefxyz"
--    { key = "def" }

--    > = "abc%{key}xyz" / "abcdefijk"
--    nil

--    > = "abc%%{key}xyz" / "abcdefxyz"
--    nil

function string.quote (s)
  return string.format ("%q", s)
end

--    > local text = "abc"
--    > = text:quote ()
--    [["abc"]]

function string.is_identifier (s)
  local i, j = s:find ("[_%a][_%w]*")
  return i == 1 and j == #s
end

--    > local text = "abc"
--    > = text:is_identifier ()
--    true

--    > local text = "0abc"
--    > = text:is_identifier ()
--    false

-- http://lua-users.org/wiki/StringTrim
function string.trim (s)
  return s:match "^()%s*$" and "" or s:match "^%s*(.*%S)"
end

--    > local text = "   abc   def   "
--    > = text:trim ()
--    "abc   def"
