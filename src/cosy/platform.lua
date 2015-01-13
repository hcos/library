-- Select the platform using the environment.

local global = _ENV or _G

if global.js then
  return require "cosy.platform.js"
else
  return require "cosy.platform.standalone"
end