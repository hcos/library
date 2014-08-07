local rev    = require "cosy.util.rev"
local seq    = require "cosy.util.seq"

local rawify        = require "cosy.proxy.rawify"
local remember_path = require "cosy.proxy.remember_path"
local guess_patch   = require "cosy.proxy.guess_patch"

local cosy = require "cosy.util.cosy"
local tags = require "cosy.util.tags"

local IS_VOLATILE = tags.IS_VOLATILE
local PATCHES     = tags.PATCHES
local RESOURCE    = tags.RESOURCE
local TOKEN       = tags.TOKEN
local INTERFACE   = tags.INTERFACE
local VERSION     = tags.VERSION

PATCHES   [IS_VOLATILE] = true
RESOURCE  [IS_VOLATILE] = true
TOKEN     [IS_VOLATILE] = true
INTERFACE [IS_VOLATILE] = true
VERSION   [IS_VOLATILE] = true

local protocol = {}

local function from_user (interface)
  return interface.wrapper ..
         guess_patch ..
         remember_path ..
         rawify
end

local function from_server (interface)
  return interface.wrapper ..
         rawify
end

-- Called by the interface:
function protocol.on_connect (interface)
  local resource  = interface.resource
  local token     = interface.token
  interface:log ("Connecting to resource: " .. tostring (resource) ..
                 " using token: " .. tostring (token))
  cosy [resource] = from_user (interface) {
    [PATCHES  ] = {},
    [RESOURCE ] = resource,
    [TOKEN    ] = token,
    [INTERFACE] = interface,
    [VERSION  ] = nil,
  }
end

function protocol.on_open (model)
  local resource  = model [RESOURCE]
  local token     = model [TOKEN]
  local interface = model [INTERFACE]
  interface:log ("Sending set-resource command" ..
                 " for: " .. tostring (resource) ..
                 " using token: " .. tostring (token))
  interface:send {
    action   = "set-resource",
    token    = token,
    resource = resource,
  }
end

function protocol.on_close (model)
  local resource  = model [RESOURCE]
  local interface = model [INTERFACE]
  interface:log ("Closing connection to resource " .. tostring (resource))
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
  local token     = model [TOKEN]
  local interface = model [INTERFACE]
  local patches   = model [PATCHES]
  for patch in seq (patches) do
    if patch.status == "applied" then
      local id = tostring (patch)
      interface:send {
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
  local resource  = model [RESOURCE]
  local token     = model [TOKEN]
  local interface = model [INTERFACE]
  local patches   = model [PATCHES]
  if message.action == "set-resource" then
    if message.accepted then
      interface:log ("Connected to resource: " .. tostring (resource))
      interface:log ("Sending get-model command" ..
                     " for resource: " .. tostring (resource) ..
                     " using token: " .. tostring (token))
      interface:send {
        action = "get-model",
        token  = token,
      }
    else
      interface:err ("Unable to connect to resource: " ..
                     tostring (message.reason))
      interface:close ()
    end
  elseif message.action == "get-model" then
    if message.accepted then
      interface:log ("Loading resource: " .. tostring (resource))
      local ok, err = pcall (loadstring (message.code))
      if ok then
        interface:log ("Updating resource: " .. tostring (resource) ..
                       " version to: " .. tostring (message.version))
        model [VERSION] = message.version
        interface:ready ()
      else
        interface:err ("Unable to load resource: " .. tostring (resource) ..
                       " because: " .. tostring (err))
        interface:close ()
      end
    else
      interface:err ("Unable to get resource: " .. tostring (resource) .. 
                     " because: " .. tostring (message.reason))
      interface:close ()
    end
  elseif message.action == "add-patch" then
    local patch = patches [1]
    assert (message.answer == patch.request_id)
    if model [VERSION] then
      if message.accepted then
        interface:log ("Patch: " .. tostring (message.id) ..
                       " on resource: " .. tostring (resource) ..
                       " has been accepted")
        if patch.status == "unapplied" then
          interface:log ("Applying unapplied patch: " ..
                         tostring (patch.id) ..
                         " on resource: " .. tostring (resource))
          local ok, err = pcall (loadstring (patch.code))
          if not ok then
            interface:err ("Unable to reapply patch: " ..
                           tostring (patch.id) ..
                           " on resource: " .. tostring (resource) ..
                           " because: " .. tostring (err))
          end
        end
        model [VERSION] = message.version
        table.remove (patches, 1)
      else
        interface:log ("Patch: " .. tostring (message.id) ..
                       " on resource: " .. tostring (resource) ..
                       " rejected because: " .. tostring (message.reason))
        cosy [resource] = from_server (cosy [resource])
        for patch in rev (patches) do
          if patch.status == "applied" or patch.status == "sent" then
            patch.unapply ()
            patch.status = "unapplied"
          end
        end
        table.remove (patches, 1)
        cosy [resource] = from_user (cosy [resource])
      end
    else
      interface:err ("Edition of resource: " .. tostring (resource) ..
                     " that has still not been loaded")
    end
  elseif message.action == "update" then
    if model [VERSION] then
      cosy [resource] = from_server (cosy [resource])
      interface:log ("Unapply patches on resource: " ..
                     tostring (resource) ..
                     " because of interleaved update: " ..
                     tostring (message.id))
      for patch in rev (patches) do
        if patch.status == "applied" or patch.status == "sent" then
          patch.unapply ()
          patch.status = "unapplied"
        end
      end
      for patch in seq (message.patches) do
        if patch.id > model [VERSION] then
          interface:log ("Applying patch: " .. tostring (patch.id) ..
                         " on resource: " .. tostring (resource))
          local ok, err = pcall (loadstring (patch.code))
          if not ok then
            interface:err ("Unable to apply patch: " ..
                           tostring (patch.id) ..
                           " because: " .. tostring (err))
          end
        else
          interface:log ("Patch: " .. tostring (patch.id) ..
                         " already applied on resource: " ..
                         tostring (resource)) 
        end
      end
      cosy [resource] = from_user (cosy [resource])
    else
      interface:log ("Receiving patches for resource: " ..
                     tostring (resource) ..
                     " that has still not been loaded")
    end
  else
    interface:err ("Unexpected message: " .. tostring (message.action))
  end
end

return protocol
