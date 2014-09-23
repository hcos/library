--local Algorithm = require "cosy.algorithm"

local Protocol = {}

Protocol.__index = Protocol

function Protocol.new (meta)
  return setmetatable ({
    meta = meta
  }, Protocol)
end

function Protocol:on_open ()
  self.meta.platform:log ("Connection to ${resource} opened." % {
    resource = self.meta.resource
  })
  self.meta.platform:send {
    action   = "set-resource",
    token    = self.meta.editor.token,
    resource = self.meta.resource,
  }
end

function Protocol:on_close ()
  self.meta.platform:log ("Connection to ${resource} closed." % {
    resource = self.meta.resource
  })
  self.meta.disconnect ()
end

--[[

function Protocol:on_change ()
  local patches = self.meta.patches
  for patch in Algorithm.seq (patches) do
    if patch.status () == "applied" then
      local id = tostring (patch)
      interface:send {
        action     = "add-patch",
        token      = value (patch.token),
        data       = value (patch.code),
        request_id = value (patch.id),
      }
      patch.status     = "sent"
    end
  end
end

function Protocol:on_message (message)
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

--]]
return Protocol
