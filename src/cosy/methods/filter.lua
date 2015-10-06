#! /usr/bin/env luajit

local Configuration = require "cosy.configuration"
local Parameters    = require "cosy.parameters"
local Scheduler     = require "cosy.scheduler"
local Store         = require "cosy.store"
local Value         = require "cosy.value"
local Websocket     = require "websocket"

Configuration.load {
  "cosy.parameters",
  "cosy.server",
}

Scheduler.addthread (function ()
  local client  = Websocket.client.sync { timeout = 5 }
  assert (client:connect ("ws://{{{interface}}}:{{{port}}}" % {
    interface = Configuration.server.interface,
    port      = _G.port,
  }, "cosyfilter"))
  local request = client:receive ()
  request       = Value.decode (request)
  local store   = Store.new ()
  local view    = Store.toview (store)
  if request.authentication then
    view = view % request.authentication
  end
  request.authentication = nil
  Parameters.check (view, request, {
    required = {
      iterator = Parameters.iterator,
    },
  })
  local iterator = coroutine.create (request.iterator)
  local function sanitize (t)
    if type (t) ~= "table" then
      return t
    else
      local it = getmetatable (t) == getmetatable (view)
             and Store.pairs
              or pairs
      local r = {}
      for k, v in it (t) do
        r [sanitize (k)] = sanitize (v)
      end
      return r
    end
  end
  repeat
    local ok, result = coroutine.resume (iterator, view)
    result = sanitize (result)
    client:send (Value.expression {
      success  = ok,
      response = ok and result or nil,
      error    = not ok and result or nil,
      finished = coroutine.status (iterator) == "dead" or nil
    })
  until coroutine.status (iterator) == "dead"
  client:send (Value.expression {
    success  = true,
    finished = true,
  })
end)

Scheduler.loop ()
