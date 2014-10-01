local json       = require "dkjson"
local _          = require "cosy.util.string"
local ignore     = require "cosy.util.ignore"
local Data       = require "cosy.data"
local Algorithm  = require "cosy.algorithm"
local Tag        = require "cosy.tag"
local INHERITS    = Tag.INHERITS
local TYPE        = Tag.TYPE
local INSTANCE    = Tag.INSTANCE
local VISIBLE     = Tag.VISIBLE
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

GLOBAL.print = function (msg)
  env.console:info (msg)
end

local Platform = {}

Platform.__index = Platform

function Platform:log (message)
  ignore (self)
  env.console:log (message)
end

function Platform:info (message)
  ignore (self)
  env.console:info (message)
end

function Platform:warn (message)
  ignore (self)
  env.console:warn (message)
end

function Platform:error (message)
  ignore (self)
  env.console:error (message)
end

function Platform:send (message)
  if self.websocket.readyState == 1 then
    message.token = self.token
    self.websocket:send (json.encode (message))
  else
    self:log ("Unable to send: " .. json.encode (message))
  end
end

function Platform.new (meta)
  -- TODO: cross-domain + authentication
  local model = meta.model
  Data.on_write [tostring (model)] = function (target, value, reverse)
    if target / 2 == model then
      local x = target / 3
      if not Data.exits (x) then
        env:remove_node (x)
      elseif Data.value (x [INSTANCE]) then
        env:update_node (x)
      end
    end
  end
  local editor_info = env:load (meta.editor.url ())
  if not editor_info then
    Platform:warn ("Cannot get editor ${editor_url} from repository." % {
      editor_url = meta.editor.url ()
    })
    return setmetatable ({
      meta = meta,
    }, Platform)
  end
  editor_info = json.decode (editor_info)
  meta.editor.token = editor_info.token
  meta.editor.url   = editor_info.url
  local websocket =
    env:eval ([[new WebSocket ("${editor}", "cosy")]] % {
      editor = meta.editor.url (),
    })
  local protocol = meta.protocol ()
  function websocket:onopen ()
    ignore (self)
    protocol:on_open ()
    websocket:send {
      action = "get-patches",
      token  = meta.editor.token (),
    }
  end
  function websocket:onclose ()
    ignore (self)
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
  return setmetatable ({
    meta      = meta,
    websocket = websocket,
  }, Platform)
end

function Platform:close ()
  if self.websocket then
    if self.websocket.readyState == 1 then
      self.websocket:close ()
    end
    self.websocket = nil
  end
end

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

function env:instantiate (model, target_type, data)
  assert (Data.is (target_type))
  model [#model + 1] = target_type * data
  local result = model [#model]
  result [INHERITS] [tostring (result)] = true
  result [INSTANCE] = true
  return result
end

function env:create (model, source, link_type, target_type, data)
  -- TODO
end

function env:delete (target)
  -- TODO: remove arcs
  Data.clear (target)
end

local function to_array (x)
  x = x or {}
  local elements = {}
  for _, element in ipairs (x) do
    elements [#elements + 1] = '"' .. tostring (element) .. '"'
  end
  table.sort (elements)
  return env:eval ("[ " .. table.concat (elements, ", ") .. " ]")
end

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
function model_of (data)
  return data [PATH] [1]
end

function is_empty (data)
  for _ in pairs (data) do
    return false
  end
  return true
end

function env:id (data)
  ignore (self)
  if type (data) ~= "table" then
    return nil
  end
  return tostring (data)
end

function env:type (data)
  ignore (self)
  if type (data) ~= "table" then
    return nil
  end
  return data [tags.TYPE]
end

local function to_array (x)
  x = x or {}
  local elements = {}
  for element in set (x) do
    elements [#elements + 1] = '"' .. tostring (element) .. '"'
  end
  table.sort (elements)
  return js.global:eval ("[ " .. table.concat (elements, ", ") .. " ]")
end

local function to_object (x)
  x = x or {}
  local elements = {}
  for key, value in map (x) do
    elements [#elements + 1] = [["${key}": ${value}]] % {
      key   = tostring (key),
      value = value,
    }
  end
  table.sort (elements)
  return js.global:eval ("{ " .. table.concat (elements, ", ") .. " }")
end

function env:selected (data)
  ignore (self)
  if type (data) ~= "table" then
    return nil
  end
  return to_array (data [tags.SELECTEDED])
end

function env:select (data)
  ignore (self)
  if type (data) ~= "table" then
    return nil
  end
  local username = model_of (data) [USER]
  local selected = data [tags.SELECTED] or {}
  selected [username] = true
  data [tags.SELECTED] = selected
end

function env:deselect (data)
  ignore (self)
  if type (data) ~= "table" then
    return nil
  end
  local username = model_of (data) [USER]
  local selected = data [tags.SELECTED] or {}
  selected [username] = nil
  if is_empty (selected) then
    data [tags.SELECTED] = nil
  else
    data [tags.SELECTED] = selected
  end
end

function env:attributes (data)
  local result = {}
  for k, v in map (data) do
    if type (k) == "string" then
      result [k] = true
    end
  end
  return to_array (result)
end

function env:appearance (data)

end

function env:update_appearance (data)

end


function env:create_node (of_type)
  ignore (self)
  return {
    [tags.TYPE] = of_type,
  }
end

function env:create_arc (arc_type, arrows²&)
end

function env:smart_create (node, arc_type, node_type)

end

function delete (data)
  local path = data [PATH]

end

function env:count (x)
  ignore (self)
  return #x
end

function env:tags ()
  ignore (self)
  return to_object (tags);
end




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
