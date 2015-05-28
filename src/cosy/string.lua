local Lustache      = require "lustache"
local metatable     = getmetatable ""
local string        = string

metatable.__mod = function (pattern, variables)
  return Lustache:render (pattern, variables)
end

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

function string.quote (s)
  return string.format ("%q", s)
end

function string.is_identifier (s)
  local i, j = s:find ("[_%a][_%w]*")
  return i == 1 and j == #s
end

-- http://lua-users.org/wiki/StringTrim
function string.trim (s)
  return s:match "^()%s*$" and "" or s:match "^%s*(.*%S)"
end
