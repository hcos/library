local json       = require "dkjson"
local _          = require "cosy.util.string"
local ignore     = require "cosy.util.ignore"
local Data       = require "cosy.data"
local Tag        = require "cosy.tag"
local Helper     = require "cosy.helper"

local INSTANCE    = Tag.INSTANCE

local GLOBAL = _G or _ENV
local js  = GLOBAL.js
local env = js.global

local console = env.console

GLOBAL.print = function (msg)
  console:info (msg)
end

env.Cosy = env:eval [[ Object.create (null); ]]

for k, v in pairs (Helper) do
  env.Cosy [k] = function (self, ...)
    ignore (self)
    return v (...)
  end
end


local Platform = {}

Platform.__index = Platform

function Platform:log (message)
  ignore (self)
  console:log (message)
end

function Platform:info (message)
  ignore (self)
  console:info (message)
end

function Platform:warn (message)
  ignore (self)
  console:warn (message)
end

function Platform:error (message)
  ignore (self)
  console:error (message)
end

function Platform:send (message)
  if self.websocket.readyState == 1 then
    message.token = self.token
    self.websocket:send (json.encode (message))
    self:log ("Sent: " .. json.encode (message))
    return true
  else
    self:log ("Unable to send: " .. json.encode (message))
    return false
  end
end

function Platform.new (meta)
  local model     = meta.model
  local websocket =
    env:eval ([[new WebSocket ("${editor}", "cosy")]] % {
      editor = meta.editor,
    })
  local protocol = meta.protocol
  local platform = setmetatable ({
    meta      = meta,
    websocket = websocket,
  }, Platform)
  Data.on_write [platform] = function (target)
    if target / 2 == model and # (Data.path (target)) >= 3 then
      local x = target / 3
      if not Data.exists (x) then
        env:remove (x)
      elseif Data.value (x [INSTANCE])
        and (Helper.is_place (x) or Helper.is_transition (x)) then
        env:update_node (x)
      elseif Data.value (x [INSTANCE])
        and Helper.is_arc (x) then
        env:update_arc (x)
      end
    end
  end
  function websocket:onopen ()
    ignore (self)
    env:is_connected (true);
    protocol:on_open ()
  end
  function websocket:onclose ()
    ignore (self)
    env:is_connected (false);
    protocol:on_close ()
  end
  function websocket:onmessage (event)
    ignore (self)
    protocol:on_message (json.decode (event.data))
  end
  function websocket:onerror ()
    ignore (self)
    websocket:close ()
  end
  return platform
end

function Platform:close ()
  if self.websocket then
    if self.websocket.readyState == 1 then
      self.websocket:close ()
    end
    self.websocket = nil
  end
end

function Platform.start ()
end

function Platform.respond ()
end

function Platform.stop ()
end


--[[
local function to_array (x)
  x = x or {}
  local elements = {}
  for _, element in ipairs (x) do
    elements [#elements + 1] = '"' .. tostring (element) .. '"'
  end
  table.sort (elements)
  return env:eval ("[ " .. table.concat (elements, ", ") .. " ]")
end
--]]

local function to_object (x)
  x = x or {}
  local elements = env:eval [[ Object.create (null); ]]
  for key, value in pairs (x) do
    if type (key) == "string" then
      elements [key] = value
    end
  end
  return elements
end

local old_types = env.Cosy.types

function env.Cosy:types (model)
  ignore (self)
  return to_object (old_types (model))
end

--[=[
js.global:eval [[
  window.make_iterator = function (iterator) {
    return {
      next: function () {
              var result = iterator ();
              if (result == undefined) {
                return {
                  done: true
                }
              } else {
                return {
                  value: result,
                  done:  false
                }
              }
            }
    };
  };
]]

function env:map (collection)
  ignore (self)
  local iterator = coroutine.wrap (function ()
    for k, v in map (collection) do
      coroutine.yield (js.global:eval ([[
        new Array (${k}, ${v})
      ]] % { k = k, v = v }))
    end
  end)
  return env:make_iterator (iterator)
end
--]=]

return Platform
