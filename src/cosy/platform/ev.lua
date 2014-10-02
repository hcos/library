local json       = require "dkjson"
local _          = require "cosy.util.string"
local ignore     = require "cosy.util.ignore"
local websocket  = require "websocket"
local ev         = require "ev"

local logging    = require "logging"
logging.console  = require "logging.console"
local logger     = logging.console "%level %message\n"

local global = _ENV or _G

local Platform = {}

Platform.__index = Platform

function Platform:log (message)
  ignore (self)
  logger:debug (message)
end

function Platform:info (message)
  ignore (self)
  logger:info (message)
end

function Platform:warn (message)
  ignore (self)
  logger:warn (message)
end

function Platform:error (message)
  ignore (self)
  logger:error (message)
end

function Platform:send (message)
  if self.websocket.state == "OPEN" then
    self.websocket:send (json.encode (message))
    return true
  else
    self:log ("Unable to send message.")
    return false
  end
end

function Platform.new (meta)
  local websocket = websocket.client.ev { timeout = 2 }
  local protocol  = meta.protocol
  local platform  = setmetatable ({
    meta      = meta,
    websocket = websocket,
  }, Platform)
  websocket:connect (meta.editor, "cosy")
  websocket:on_open (function ()
    protocol:on_open ()
  end)
  websocket:on_close (function ()
    protocol:on_close ()
  end)
  websocket:on_message (function (_, message)
    if not message then
      return
    end
    protocol:on_message (json.decode (message))
  end)
  websocket:on_error (function (_, err)
    logger:warn ("Error received: ${err}." % {
      err = err
    })
    websocket:close ()
  end)
  return platform
end

function Platform:close ()
  print "Close"
  if self.websocket then
    self.websocket:close ()
    self.websocket = nil
  end
end

function Platform:execute (f, again)
  ignore (self, again)
  local co = coroutine.create (function ()
    local ok, err = pcall (f)
    if not ok then
      logger:warn (err)
    end
  end)
  local timer = ev.Timer.new (function (_1, timer, _2)
    ignore (_1, _2)
    local _, delay = coroutine.resume (co)
    if coroutine.status (co) == "dead" then
      timer:stop (ev.Loop.default)
    else
      timer:again (ev.Loop.default, delay)
    end
  end, 1)
  timer:start (ev.Loop.default)
end

function Platform.start ()
  if global.main then
    local m = coroutine.create (function ()
      local ok, err = pcall (global.main)
      if not ok then
        logger:error (err)
      end
    end)
    local function wrap (loop, idle, revents)
      if coroutine.status (m) == "suspended" then
        coroutine.resume (m)
      else
        idle:stop (loop)
      end
    end
    local idle = ev.Idle.new (wrap)
    idle:start (ev.Loop.default)
  end
  ev.Loop.default:loop ()
end

function Platform.stop ()
  local function check_patches (loop, timer, revents)
    local models = global.meta.models
    local all = true
    for _, m in pairs (models) do
      if # (m.patches) ~= 0 then
        all = false
        break
      end
    end
    if all then
      timer:stop (loop)
      loop:unloop ()
      return
    end
  end
  local timer = ev.Timer.new (check_patches, 1, 1)
  timer:start (ev.Loop.default)
end

return Platform
