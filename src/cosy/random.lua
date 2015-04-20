local hotswap = require "hotswap"

if _G.js then
  local js = _G.js
  return js.global.random
else
  local time = hotswap "cosy.platform.time"
  math.randomseed (time ())
  return math.random
end
