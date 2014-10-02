local json       = require "dkjson"
local _          = require "cosy.util.string"
local ignore     = require "cosy.util.ignore"
local Data       = require "cosy.data"
local Tag        = require "cosy.tag"

local INSTANCE    = Tag.INSTANCE
local POSITION    = Tag.POSITION
local SELECTED    = Tag.SELECTED
local HIGHLIGHTED = Tag.HIGHLIGHTED

local GLOBAL = _G or _ENV
local js  = GLOBAL.js
local env = js.global

local cosy = GLOBAL.cosy
local meta = GLOBAL.meta

local console = env.console

GLOBAL.print = function (msg)
  console:info (msg)
end

env.Cosy = env:eval [[ Object.create (null); ]]

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
--        env:remove (x)
      elseif Data.value (x [INSTANCE])
        and (env.Cosy:is_place (x) or env.Cosy:is_transition (x)) then
        env:update_node (x)
      elseif Data.value (x [INSTANCE])
        and env.Cosy:is_arc (x) then
--        env:update_arc (x)
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

function env.Cosy:configure_editor (url)
  ignore (self)
  meta.editor = url
end

function env.Cosy:configure_server (url, data)
  ignore (self)
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

function env.Cosy:model (url)
  ignore (self)
  return cosy [url]
end

function env.Cosy:instantiate (model, target_type, data)
  ignore (self)
  assert (Data.is (target_type))
  model [#model + 1] = target_type * {
    [INSTANCE] = true,
  }
  local result = model [#model]
  for k, v in pairs (data) do
    result [k] = v
  end
  return result
end

function env.Cosy:create (model, source, link_type, target_type, data)
  ignore (self, link_type, target_type)
  local place_type      = model.place_type
  local transition_type = model.transition_type
  local arc_type        = model.arc_type
  local target
  if env.Cosy:is_place (source) then
    model [#model + 1] = transition_type * {}
    target = model [#model]
  elseif env.Cosy:is_transition (source) then
    model [#model + 1] = place_type * {}
    target = model [#model]
  else
    console:error ("Source ${source} is neither a place nor a transition." % {
      source = tostring (source)
    })
    return
  end
  for k, v in pairs (data) do
    target [k] = v
  end
  model [#model + 1] = arc_type * {
    source = source,
    target = target,
  }
  return target
end

function env.Cosy:remove (target)
  ignore (self)
  local model           = target / 2
  local place_type      = model.place_type
  local transition_type = model.transition_type
  if Data.value (target [tostring (place_type)])
  or Data.value (target [tostring (transition_type)]) then
    for _, x in pairs (model) do
      if Data.dereference (x.source) == target
      or Data.dereference (x.target) == target then
        Data.clear (x)
      end
    end
  end
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
  local elements = env:eval [[ Object.create (null); ]]
  for key, value in pairs (x) do
    if type (key) == "string" then
      elements [key] = value
    end
  end
  return elements
end

function env.Cosy:types (model)
  ignore (self)
  return to_object {
    place_type      = model.place_type,
    transition_type = model.transition_type,
    arc_type        = model.arc_type,
  }
end

function env.Cosy:is_place (x)
  ignore (self)
  local model = x / 2
  return Data.value (x [tostring (model.place_type)])
end

function env.Cosy:is_transition (x)
  ignore (self)
  local model = x / 2
  return Data.value (x [tostring (model.transition_type)])
end

function env.Cosy:is_arc (x)
  ignore (self)
  local model = x / 2
  return Data.value (x [tostring (model.arc_type)])
end

function env.Cosy:get_name (x)
  ignore (self)
  return Data.value (x.name)
end

function env.Cosy:set_name (x, value)
  ignore (self)
  x.name = value
end

function env.Cosy:get_token (x)
  ignore (self)
  return Data.value (x.token)
end

function env.Cosy:set_token (x, value)
  ignore (self)
  x.token = value
end

function env.Cosy:get_position (x)
  ignore (self)
  return Data.value (x [POSITION])
end

function env.Cosy:set_position (x, value)
  ignore (self)
  x [POSITION] = value
end

function env.Cosy:is_selected (x)
  ignore (self)
  return Data.value (x [SELECTED]) -- FIXME
end

function env.Cosy:select (x)
  ignore (self)
  x [SELECTED] = true
end

function env.Cosy:deselect (x)
  ignore (self)
  x [SELECTED] = nil
end

function env.Cosy:is_highlighted (x)
  ignore (self)
  return Data.value (x [HIGHLIGHTED]) -- FIXME
end

function env.Cosy:highlight (x)
  ignore (self)
  x [HIGHLIGHTED] = true
end

function env.Cosy:unhighlight (x)
  ignore (self)
  x [HIGHLIGHTED] = nil
end

function env.Cosy:source (x)
  ignore (self)
  return x.source
end

function env.Cosy:target (x)
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
