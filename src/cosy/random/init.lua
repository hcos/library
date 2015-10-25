return function (loader)

  if _G.js then
    local js = _G.js
    return js.global.random
  else
    local Time = loader.load "cosy.time"
    math.randomseed (Time ())
    return math.random
  end

end
