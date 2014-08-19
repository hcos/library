local json       = require "dkjson"
                   require "cosy.util.string"
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

GLOBAL.cosy = cosy
GLOBAL.tags = tags
env.cosy = cosy


local DATA    = tags.DATA
local PATH    = tags.PATH
local PATCHES = tags.PATCHES
local NODES   = tags.NODES
local TYPE    = tags.TYPE

local show = proxy ()
function show:__newindex (key, value)
  if self [TYPE] then
    if model [NODES] [self] then
      env:update_node (self)
    else
      env:add_node (self)
    end
  end
  if type (old_value) == "table" and old_value [TYPE] then
    model [NODES] [old_value] = model [NODES] [old_value] - 1
    if model [NODES] [old_value] == 0 then
      model [NODES] [old_value] = nil
      env:remove_node (old_value)
    end
  end
  if type (new_value) == "table" and new_value [TYPE] then
    model [NODES] [new_value] = (model [NODES] [new_value] or 0) + 1
    if model [NODES] [new_value] == 1 then
      env:add_node (new_value)
    end
  end
end

local detect = proxy ()
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


function env:connect (editor, resource, token)
  ignore (self)
  local websocket =
    js.global:eval ([[new WebSocket ("${editor}", "cosy")]] % { editor = editor })
  local interface = setmetatable ({
    resource    = resource,
    token       = token,
    websocket   = websocket,
    from_user   = show .. detect,
    from_server = show,
  }, interface_mt)
  local model = protocol.on_connect (interface)
  function websocket:onopen ()
    ignore (self)
    protocol.on_open (model)
    interface:send {
      action   = "set-resource",
      resource = resource,
    }
    interface:send {
      action   = "get-patches",
    }
    cosy [resource] [NODES] = container {}
  end
  function websocket:onclose ()
    ignore (self)
    protocol.on_close (model)
  end
  function websocket:onmessage (event)
    ignore (self)
    protocol.on_message (model, json.decode (event.data))
  end
  function websocket:onerror ()
    ignore (self)
    websocket:close ()
  end
end

function env:id (data)
  ignore (self)
  return tostring (data)
end

function env:type (data)
  ignore (self)
  if type (data) == "table" then
    return data [tags.TYPE]
  else
    return nil
  end
end

local function to_array (x)
  local elements = {}
  for element in set (x) do
    elements [#elements + 1] = '"' .. tostring (element) .. '"'
  end
  table.sort (elements)
  return js.global:eval ("[ " .. table.concat (elements, ", ") .. " ]")
end

local function to_object (x)
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
  if type (data) == "table" then
    local s = data [tags.SELECT]
    if type (s) == "table" then
      return to_array (s)
    elseif type (s) == "string" then
      return to_array { s = true }
    else
      return to_array {}
    end
  else
    return nil
  end
end

function env:select (data, name, value)
  ignore (self)
  local s = data [tags.SELECT] or {}
  if type (s) == "string" then
    s = { s = true }
  end
  s [name] = value
  data [tags.SELECT] = s
end

function env:highlighted (data)
  ignore (self)
  if type (data) == "table" then
    local s = data [tags.HIGHLIGHT]
    if type (s) == "table" then
      return to_array (s)
    elseif type (s) == "string" then
      return to_array { s = true }
    else
      return to_array {}
    end
  else
    return nil
  end
end

function env:highlight (data, name, value)
  ignore (self)
  local s = data [tags.HIGHLIGHT] or {}
  if type (s) == "string" then
    s = { s = true }
  end
  s [name] = value
  data [tags.HIGHLIGHT] = s
end

function env:get_position (data)
  ignore (self)
  if type (data) == "table" then
    return data [tags.POSITION]
  else
    return nil
  end
end

function env:set_position (data, value)
  ignore (self)
  data [tags.POSITION] = value
end

function env:instantiate (element_type)
  return {
    [tags.TYPE] = element__type,
  }
end

function env:count (x)
  ignore (self)
  return #x
end

function env:all_tags ()
  ignore (self)
  return to_object (tags);
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
  local iterator = coroutine.wrap (function ()
    for k, v in map (collection) do
      coroutine.yield (js.global:eval ([[
        new Array (${k}, ${v})
      ]] % { k = k, v = v }))
    end
  end)
  return env:make_iterator (iterator)
end

