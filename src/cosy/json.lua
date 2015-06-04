if _G.js then
  return {
    decode = function (s)
      return _G.window.JSON:parse (s)
    end,
    encode = function (t)
      return _G.window.JSON:stringify (t)
    end,
  }
else
  return require "cjson" .new ()
end
