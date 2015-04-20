local Platform = {}
local platform = {}

if not _G.js then
  local ev           = require "ev"
  platform.scheduler = require "copas.ev"
  platform.scheduler:make_default ()
  package.preload [hotswap] = function ()
    local hotswap      = require "hotswap" .new ()
    hotswap.register   = function (filename, f)
      local stat = ev.Stat.new (function (loop, stat, events)
        stat:stop (loop)
        f ()
      end, path):start (platform.scheduler._loop)
    end
    return hotswap
  end
end

do
  local hotswap = require "hotswap"
  hotswap "cosy.string"
  Platform.__index = function (_, key)
    return hotswap ("cosy.platform." .. tostring (key))
  end
end

return setmetatable (platform, Platform)