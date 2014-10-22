local Cosy = require "cosy.cosy"

local global = _ENV or _G

if global.js then
  return require "cosy.platform.js"
elseif global.ev then
  return require "cosy.platform.ev"
else
  return require "cosy.platform.dummy"
end
