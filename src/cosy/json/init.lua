return function (loader)

  if _G.js then
    return loader.require "dkjson"
  else
    return loader.require "cjson" .new ()
  end

end
