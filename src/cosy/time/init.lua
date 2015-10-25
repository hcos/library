return function (--[[loader]])

  if _G.js then
    local js = _G.js
    return js.global.Date.now
  else
    return require "socket" .gettime
  end

end
