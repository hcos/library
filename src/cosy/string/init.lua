return function (loader)

  local Lustache      = loader.require "lustache"
  local Metatable     = getmetatable ""
  local String        = string

  Metatable.__mod = function (pattern, variables)
    return Lustache:render (pattern, variables)
  end

  Metatable.__div = function (pattern, string)
    local names = {}
    pattern = pattern:gsub ("{{{(.-)}}}", function (key)
      names [#names+1] = key
      return "(.*)"
    end)
    if pattern:sub (1,1) ~= "^" then
      pattern = "^" .. pattern
    end
    if pattern:sub (-1,1) ~= "$" then
      pattern = pattern .. "$"
    end
    local results = { string:match (pattern) }
    if #results == 0 then
      return nil
    end
    local result  = {}
    for i = 1, #names do
      result [names [i]] = results [i]
     end
    return result
  end

  -- http://stackoverflow.com/questions/9790688/escaping-strings-for-gsub
  function String.escape (s)
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

  function String.quote (s)
    return string.format ("%q", s)
  end

  function String.is_identifier (s)
    local i, j = s:find ("[_%a][_%w]*")
    return i == 1 and j == #s
  end

  -- http://lua-users.org/wiki/StringTrim
  function String.trim (s)
    return s:match "^()%s*$" and "" or s:match "^%s*(.*%S)"
  end

end
