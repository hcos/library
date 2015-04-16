-- Select the platform using the environment.

local version = tonumber (_VERSION:match "Lua%s*(%d%.%d)")

if version < 5.1
or (version == 5.1 and type (_G.jit) ~= "table") then
  error "Cosy requires Luajit >= 2 or Lua >= 5.2 to run."
end

if _G.js then
  return require "cosy.platform.js"
else
  return require "cosy.platform.standalone"
end