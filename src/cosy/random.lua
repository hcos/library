local loader = require "cosy.loader"

if _G.js then
  local js = _G.js
  return js.global.random
else
  math.randomseed (loader.time ())
  return math.random
end
