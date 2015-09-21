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
  print ("connecting to", ("ws://{{{interface}}}:{{{port}}}" % {
    interface = Configuration.server.interface,
    port      = arg [1],
  }), "cosyfilter")

  local client  = Websocket.client.sync { timeout = 5 }
  assert (client:connect ("ws://{{{interface}}}:{{{port}}}" % {
    interface = Configuration.server.interface,
    port      = arg [1],
  }, "cosyfilter"))
  local request = client:receive ()
  request       = Value.decode (request)

  local store   = Store.new ()
  if request.authentication then
    store = Store.specialize (store, request.authentication)
  end
  request.authentication = nil
  Parameters.check (store, request, {
    required = {
      iterator = Parameters.iterator,
    },
  })

  local iterator = coroutine.create (request.iterator)
  repeat
    local ok, result = coroutine.resume (iterator, store)
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
