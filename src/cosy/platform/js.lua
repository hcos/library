local json       = require "dkjson"
local _          = require "cosy.util.string"
local ignore     = require "cosy.util.ignore"
local Data       = require "cosy.data"
local Tag        = require "cosy.tag"
local INHERITS    = Tag.new "INHERITS"
local INSTANCE    = Tag.new "INSTANCE"
local POSITION    = Tag.new "POSITION"
local SELECTED    = Tag.new "SELECTED"
local HIGHLIGHTED = Tag.new "HIGHLIGHTED"

local GLOBAL = _G or _ENV
local js  = GLOBAL.js
local env = js.global

local cosy = GLOBAL.cosy
local meta = GLOBAL.meta
env.cosy = cosy
env.meta = meta

local console = env.console

GLOBAL.print = function (msg)
  console:info (msg)
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
  local model    = meta.model
  local resource = meta.resource
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
    if target / 2 == resource then
      local x = target / 3
      if not Data.exists (x) then
        env:remove_node (x)
      elseif Data.value (x [INSTANCE]) then
        env:update_node (x)
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

function env:configure_server (url, data)
  -- If url does not use SSL, force it:
  if url:find "http://" == 1 then
    url = url:gsub ("^http://", "https://")
  end
  -- Remove trailing slash:
  if url [#url] == "/" then
    url = url:sub (1, #url-1)
  end
  -- Store:
  meta.servers [url] = {
    username = data.username,
    password = data.password,
  }
end

--[[

local function visible_types (model)
  assert (Data.is (model))
  return Algorithm.filter (model, function (d)
    return d [TYPE] () == true and d [VISIBLE] () == true
  end)
end

local function visible_instances (model)
  assert (Data.is (model))
  return Algorithm.filter (model, function (d)
    return d [INSTANCE] () == true and d [VISIBLE] () == true
  end)
end

--]]

function env:instantiate (model, target_type, data)
  ignore (self)
  assert (Data.is (target_type))
  model [#model + 1] = target_type * data
  local result = model [#model]
  result [INHERITS] [tostring (result)] = true
  result [INSTANCE] = true
  return result
end

function env:create (model, source, link_type, target_type, data)
  ignore (self)
  -- TODO
end

function env:delete (target)
  ignore (self)
  -- TODO: remove arcs
  Data.clear (target)
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
  local elements = {}
  for key, value in pairs (x) do
    elements [#elements + 1] = [["${key}": ${value}]] % {
      key   = tostring (key),
      value = value,
    }
  end
  table.sort (elements)
  return env:eval ("{ " .. table.concat (elements, ", ") .. " }")
end

function env:types (model)
  ignore (self)
  return to_object {
    place_type      = model.place_type,
    transition_type = model.transition_type,
    arc_type        = model.arc_type,
  }
end

function env:is_place (x)
  ignore (self)
  local model = x / 2
  return Data.value (x [tostring (model.place_type)])
end

function env:is_transition (x)
  ignore (self)
  local model = x / 2
  return Data.value (x [tostring (model.transition_type)])
end

function env:is_arc (x)
  ignore (self)
  local model = x / 2
  return Data.value (x [tostring (model.arc_type)])
end

function env:get_name (x)
  ignore (self)
  return Data.value (x.name)
end

function env:set_name (x, value)
  ignore (self)
  x.name = value
end

function env:get_token (x)
  ignore (self)
  return Data.value (x.token)
end

function env:set_token (x, value)
  ignore (self)
  x.token = value
end

function env:get_position (x)
  ignore (self)
  return Data.value (x [POSITION])
end

function env:set_position (x, value)
  ignore (self)
  x [POSITION] = value
end

function env:is_selected (x)
  ignore (self)
  return Data.value (x [SELECTED]) -- FIXME
end

function env:select (x)
  ignore (self)
  x [SELECTED] = true
end

function env:deselect (x)
  ignore (self)
  x [SELECTED] = nil
end

function env:is_highlighted (x)
  ignore (self)
  return Data.value (x [HIGHLIGHTED]) -- FIXME
end

function env:highlight (x)
  ignore (self)
  x [HIGHLIGHTED] = true
end

function env:unhighlight (x)
  ignore (self)
  x [HIGHLIGHTED] = nil
end

function env:source (x)
  ignore (self)
  return x.source
end

function env:target (x)
  ignore (self)
  return x.target
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
