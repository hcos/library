local version = tonumber (_VERSION:match "Lua%s*(%d%.%d)")
if version < 5.1
or (version == 5.1 and type (_G.jit) ~= "table") then
  error "Cosy requires Luajit >= 2 or Lua >= 5.2 to run."
end

local Loader = {}
local loader = {}

if _G.js then
  loader.hotswap   = require
else
  local ev         = require "ev"
  loader.scheduler = require "copas.ev"
  loader.scheduler:make_default ()
  loader.hotswap   = require "hotswap" .new ()
  loader.hotswap.register = function (filename, f)
    ev.Stat.new (function ()
      f ()
    end, filename):start (loader.scheduler._loop)
  end
end

do
  loader.hotswap "cosy.string"
  Loader.__index = function (_, key)
    return loader.hotswap ("cosy." .. tostring (key))
  end
end

return setmetatable (loader, Loader)