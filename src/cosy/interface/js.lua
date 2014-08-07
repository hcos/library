local json   = require "dkjson"

local cosy       = require "cosy.util.cosy"
local tags       = require "cosy.util.tags"
local protocol   = require "cosy.protocol"
local proxy      = require "cosy.util.proxy"
local container  = require "cosy.util.container"
local ignore     = require "cosy.util.ignore"
local map        = require "cosy.util.map"
local set        = require "cosy.util.set"

local GLOBAL = _G or _ENV
local js  = GLOBAL.js
local env = js.global

env.cosy = cosy

local detect = proxy ()

local DATA    = tags.DATA
local PATH    = tags.PATH
local PATCHES = tags.PATCHES
local NODES   = tags.NODES

function detect:__newindex (key, value)
  local below = self [DATA]
  local path = self [PATH] .. key
  assert (#path >= 2)
  local model = path [1] [path [2]]
  model [PATCHES] = {}
  --
  local old_value = self [key]
  below [key] = value
  local new_value = self [key]
  --
  protocol.on_patch (model)
  --
  if self.type then
    if model [NODES] [self] then
      env:update_node (self)
    else
      env:add_node (self)
    end
  end
  if type (old_value) == "table" and old_value.type then
    model [NODES] [old_value] = model [NODES] [old_value] - 1
    if model [NODES] [old_value] == 0 then
      model [NODES] [old_value] = nil
      env:remove_node (old_value)
    end
  end
  if type (new_value) == "table" and new_value.type then
    model [NODES] [new_value] = (model [NODES] [new_value] or 0) + 1
    if model [NODES] [new_value] == 1 then
      env:add_node (new_value)
    end
  end
end

local interface_mt = {}

function interface_mt:log (message)
  ignore (self)
  env.console:log (message)
end

function interface_mt:err (message)
  ignore (self)
  env.console:error (message)
end

function interface_mt:ready ()
  env:ready (self.resource)
end

function interface_mt:send (message)
  if self.websocket.readyState == 1 then
    message.token = self.token
    self.websocket:send (json.encode (message))
  else
    self:log (json.encode (message))
  end
end

function interface_mt:close ()
  self.websocket = nil
end

interface_mt.__index = interface_mt


local function connect (editor, resource, token)
  local websocket = js.new.WebSocket (editor, "cosy")
  local interface = setmetatable ({
    resource  = resource,
    token     = token,
    websocket = websocket,
  }, interface_mt)
  function websocket:onopen ()
    ignore (self)
    protocol.on_connect (interface)
    interface:send {
      action   = "set-resource",
      resource = resource,
    }
    interface:send {
      action   = "get-patches",
    }
    interface.model = cosy [resource]
    cosy [resource] [NODES] = container {}
  end
  function websocket:onclose ()
    ignore (self)
    protocol.on_close (interface)
  end
  function websocket:onmessage (event)
    ignore (self)
    protocol.on_message (interface, json.decode (event.data))
  end
  function websocket:onerror ()
    ignore (self)
    websocket:close ()
  end
end

function env:count (x)
  ignore (self)
  return #x
end

function env:id (x)
  ignore (self)
  return tostring (x)
end

function env:keys (x)
  ignore (self)
  local result = {}
  for key, _ in map (x) do
    result [#result + 1] = key
  end
  return result
end

function env:elements (model)
  ignore (self)
  local result = {}
  for x in set (model [NODES]) do
    result [#result + 1] = x
  end
  return result
end

function env:connect (editor, resource, token)
  ignore (self)
  connect {
    editor   = editor,
    token    = token,
    resource = resource,
  }
end

--[[
local map = require "cosy.util.map"

function js.global:map (collection)
  local iterator = coroutine.wrap (function ()
    for k, v in map (collection) do
      coroutine.yield (js.new (js.global.Array, k, v))
    end
  end)
  return js.global:make_iterator (iterator)
end
--]]

