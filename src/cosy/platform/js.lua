local json       = require "dkjson"
local _          = require "cosy.util.string"
local ignore     = require "cosy.util.ignore"

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

local Data      = require "cosy.data"
local Algorithm = require "cosy.algorithm"
local Tags      = require "cosy.tags"
local INHERITS  = Tags.INHERITS
local TYPE      = Tags.TYPE
local INSTANCE  = Tags.INSTANCE
local VISIBLE   = Tags.VISIBLE

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

local function instantiate (model, target_type, data)
  assert (Data.is (target_type))
  model [#model + 1] = target_type * data
  local result = model [#model]
  result [INHERITS] [tostring (result)] = true
  result [INSTANCE] = true
  return result
end

local function create (model, source, link_type, target_type, data)
  
end

local function delete (target)
  
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
