local sha1   = require "sha1"
local json   = require "dkjson"
local rev    = require "cosy.util.rev"
local seq    = require "cosy.util.seq"
local set    = require "cosy.util.set"
local map    = require "cosy.util.map"
local tags   = require "cosy.util.tags"
local raw    = require "cosy.util.raw"
local ignore = require "cosy.util.ignore"

local rawify        = require "cosy.proxy.rawify"
local remember_path = require "cosy.proxy.remember_path"
local guess_patch   = require "cosy.proxy.guess_patch"

local IS_VOLATILE = tags.IS_VOLATILE
local PATCHES     = tags.PATCHES
local RESOURCE    = tags.RESOURCE
local TOKEN       = tags.TOKEN
local INTERFACE   = tags.INTERFACE
local VERSION     = tags.VERSION
local REQUESTS    = tags.REQUESTS

PATCHES   [IS_VOLATILE] = true
RESOURCE  [IS_VOLATILE] = true
TOKEN     [IS_VOLATILE] = true
INTERFACE [IS_VOLATILE] = true
VERSION   [IS_VOLATILE] = true

local from_user_wrapper =
  guess_patch .. remember_path .. rawify
local unapply_wrapper =
  rawify
local from_server_wrapper =
  rawify

local cosy = {}
local global = _G or _ENV
global.tags  = tags
global.cosy  = wrapper (cosy)

local protocol   = {}

-- Called by the interface:
function protocol.on_connect (parameters)
  local resource = parameters.resource
  local token    = parameters.token
  local ws       = parameters.ws
  ws:log ("Connecting to resource: " .. tostring (resource) ..
          " using token: " .. tostring (token))
  cosy [resource] = {
    [PATCHES  ] = {},
    [RESOURCE ] = resource,
    [TOKEN    ] = token,
    [INTERFACE] = ws,
    [VERSION  ] = nil,
  }
end

function protocol.on_open (model)
  local resoure = model [RESOURCE]
  local token   = model [TOKEN]
  local ws      = model [INTERFACE]
  ws:log ("Sending set-resource command" ..
          " for: " .. tostring (resource) ..
          " using token: " .. tostring (token))
  ws:send {
    action   = "set-resource",
    token    = token,
    resource = resource,
  }
end

function protocol.on_close (model)
  local resource = model [RESOURCE]
  ws:log ("Closing connection to resource " .. tostring (resource))
  cosy [resource] = nil
end

-- Protocol:
--
-- Messages:
--
-- * set-editor
-- * set-token
-- * set-resource   -> ?
-- * get-model      -> data
-- * list-patches   -> patches
-- * get-patches    -> patches
-- * add-patch      -> id
-- * update         -> patches
--
-- * Messages sent in an order are received in the same order
-- 
-- Cases:
--
-- * updates while waiting for initial patches
-- * answer to initial patches
-- * accepted the first patch
-- * rejected the first patch
-- * receive an update
--
-- 

function protocol.on_patch (model)
  local token   = model [TOKEN]
  local ws      = model [INTERFACE]
  local patches = model [PATCHES]
  for patch in seq (patches) do
    if patch.status == "applied" then
      local id = tostring (patch)
      ws:send {
        action     = "add-patch",
        token      = token,
        data       = patch.code,
        request_id = id,
      }
      patch.status     = "sent"
      patch.request_id = id
    end
  end
end

function protocol.on_message (model, message)
  local resoure = model [RESOURCE]
  local token   = model [TOKEN]
  local ws      = model [INTERFACE]
  -- Case 1: answer to get-model
  -- Case 2: answer to add-patch
  -- Case 3: update
  if message.action == "set-resource" then
    if message.accepted then
      ws:log ("Connected to resource: " .. tostring (resource))
      ws:log ("Sending get-model command" ..
              " for resource: " .. tostring (resource) ..
              " using token: " .. tostring (token))
      ws:send {
        action     = "get-model",
        token      = token,
      }
    else
      ws:err ("Unable to connect to resource: " .. tostring (message.reason))
      ws:close ()
    end
  elseif message.action == "get-model" then
    if message.accepted then
      ws:log ("Loading resource: " .. tostring (resource))
      local ok, err = pcall (loadstring (message.code))
      if ok then
        ws:log ("Updating resource: " .. tostring (resource) ..
                " version to: " .. tostring (message.version))
        model [VERSION] = message.version
        ws:ready ()
      else
        ws:err ("Unable to load resource: " .. tostring (resource) ..
                " because: " .. tostring (err))
        ws:close ()
      end
    else
      ws:close ()
      error ("Unable to get resource: " .. tostring (resource) .. 
             " because: " .. tostring (message.reason))
    end
  elseif message.action == "add-patch" then
    if model [VERSION] then
      if message.accepted then
        assert (message.answer == patches [1] . request_id)
        ws:log ("Patch: " .. tostring (message.id) ..
                " on resource: " .. tostring (resource) ..
                " has been accepted")
        model [VERSION] = message.version
        table.remove (patches, 1)
      else
        -- TODO: set correct cosy wrapper
        for patch in rev (patches) do
          patch.unapply ()
        end
        -- TODO: set correct cosy wrapper
        table.remove (patches, 1)
        for patch in seq (patches) do
          local ok, err = pcall (loadstring (patch.code))
        end
        -- TODO: set correct cosy wrapper
      end
    else
      ws:err ("Edition of resource: " .. tostring (resource) ..
              " that has still not been loaded")
    end
  elseif message.action == "update" then
    if model [VERSION] then
      -- TODO: set correct cosy wrapper
      for patch in rev (patches) do
        patch.unapply ()
      end
      -- TODO: set correct cosy wrapper
      for patch in seq (message.patches) do
        if patch.id > model [VERSION] then
          local ok, err = pcall (loadstring (patch.code))
        else
          ws:log ("Patch: " .. tostring (patch.id) ..
                  " has already been applied on resource: " ..
                  tostring (resource)) 
        end
      end
      -- TODO: set correct cosy wrapper
      for patch in seq (patches) do
        local ok, err = pcall (loadstring (patch.code))
      end
      -- TODO: set correct cosy wrapper
    else
      ws:log ("Receiving patches for resource: " .. tostring (resource) ..
              " that has still not been loaded")
    end
  else

  end
  global.cosy = from_user_wrapper (cosy)
end

return protocol
