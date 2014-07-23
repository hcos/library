local GLOBAL = _G or _ENV

local sha1   = require "sha1"
local json   = require "dkjson"
local raw    = require "cosy.util.raw"
local seq    = require "cosy.util.seq"
local set    = require "cosy.util.set"
local map    = require "cosy.util.map"
local tags   = require "cosy.util.tags"
local ignore = require "cosy.util.ignore"
local proxy  = require "cosy.util.proxy"

local rawify        = require "cosy.proxy.rawify"
local remember_path = require "cosy.proxy.remember_path"
local guess_patch   = require "cosy.proxy.guess_patch"

local IS_VOLATILE = tags.IS_VOLATILE

local WS       = tags.WS
local RESOURCE = tags.RESOURCE
local PATCHES  = tags.PATCHES
local NODES    = tags.NODES
local PATH     = tags.PATH
local NAME     = tags.NAME

WS       [IS_VOLATILE] = true
RESOURCE [IS_VOLATILE] = true
PATCHES  [IS_VOLATILE] = true
NODES    [IS_VOLATILE] = true

local function wrap (x)
  return guess_patch (remember_path (rawify( raw (x))))
end

local raw_cosy = {}
raw_cosy [NAME] = "cosy"

GLOBAL.tags = tags

local js     = GLOBAL.js.global

local detect = proxy ()
local _detect_forward = detect.__newindex
local TYPE = tags.TYPE

function detect:__newindex (key, value)
  local path = self [PATH] .. key
  if #path < 2 then
    return
  end
  local model = path [1] [path [2]]
--  model [PATCHES] = {}
  --
  local old_value = self [key]
  _detect_forward (self, key, value)
  local new_value = self [key]
  --
--  for patch in seq (model [PATCHES]) do
--    js:patch (patch.apply)
--  end
  --
  if self.type then
    if model [NODES] [self] then
      js:update_node (wrap (self))
    else
      js:add_node (wrap (self))
    end
  end
  if type (old_value) == "table" and old_value.type then
    model [NODES] [old_value] = model [NODES] [old_value] - 1
    if model [NODES] [old_value] == 0 then
      model [NODES] [old_value] = nil
      js:remove_node (wrap (old_value))
    end
  end
  if type (new_value) == "table" and new_value.type then
    model [NODES] [new_value] = (model [NODES] [new_value] or 0) + 1
    if model [NODES] [new_value] == 1 then
      js:add_node (wrap (new_value))
    end
  end
end

local function connect (parameters)
  local token    = parameters.token
  local resource = parameters.resource
  local editor   = parameters.editor
  local ws       = js:websocket (editor)
  local model    = {
    [WS      ] = ws,
    [RESOURCE] = resource,
    [PATCHES ] = {},
    [NODES   ] = rawify {},
  }
  ws.token = token
  function ws:onopen ()
    ignore (self)
    ws:request {
      action   = "set-resource",
      token    = token,
      resource = resource,
    }
    ws:request {
      action   = "get-patches",
      token    = token,
    }
  end
  function ws:onclose ()
    ignore (self)
    model [WS] = nil
  end
  function ws:onmessage (event)
    ignore (self)
    local message = event.data
    if not message then
      return
    end
    local command = json.decode (message)
    if command.patches then
      local _cosy = GLOBAL.cosy
      GLOBAL.cosy = detect (remember_path (rawify (raw_cosy)))
      js.cosy = GLOBAL.cosy
      for patch in seq (command.patches) do
        local ok, err = pcall (loadstring (patch.data))
        if not ok then
          print (err)
        end
        js:add_patch (patch.data)
      end
      GLOBAL.cosy = _cosy
      js.cosy = GLOBAL.cosy
    else
      -- do nothing
    end
  end
  function ws:onerror ()
    ignore (self)
    ws:close ()
  end
  function ws:request (command)
    ignore (self)
    local str = json.encode (command)
    command.request_id = sha1 (tostring (os.time()) .. "+" .. str)
    command.token = ws.token
    if ws.readyState == 1 then
      ws:send (json.encode (command))
    end
  end
  function ws:patch (str)
    ignore (self)
    js:add_patch (str)
    local command = {
      action = "add-patch",
      data   = str,
    }
    str = json.encode (command)
    command.request_id = sha1 (tostring (os.time()) .. "+" .. str)
    command.token = ws.token
    if ws.readyState == 1 then
      ws:send (json.encode (command))
    end
  end
  raw_cosy [resource] = model
  GLOBAL.cosy = guess_patch (remember_path (rawify (raw_cosy)))
  js.cosy = GLOBAL.cosy
  return model
end

function js:count (x)
  ignore (self)
  return #x
end

function js:id (x)
  ignore (self)
  return tostring (x)
end

function js:keys (x)
  ignore (self)
  local result = {}
  for key, _ in map (x) do
    result [#result + 1] = key
  end
  return result
end

function js:elements (model)
  ignore (self)
  local result = {}
  for x in set (model [NODES]) do
    result [#result + 1] = x
  end
  return result
end

function js:connect (editor, resource, token)
  ignore (self)
  return connect {
    editor   = editor,
    token    = token,
    resource = resource,
  }
end

function js:execute (code)
  GLOBAL.cosy = detect (remember_path (rawify (raw_cosy)))
  js.cosy = GLOBAL.cosy
  loadstring (code) ()
  GLOBAL.cosy = guess_patch (remember_path (rawify (raw_cosy)))
  js.cosy = GLOBAL.cosy
end

