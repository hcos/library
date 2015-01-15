-- Select the platform using the environment.

if _G.js then
  return require "cosy.platform.js"
else
  return require "cosy.platform.standalone"
end