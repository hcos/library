local Store         = require "cosy.store"
local Coromake      = require "coroutine.make"
local Configuration = require "cosy.configuration"
Configuration.load {
  "cosy.methods",
}

local Access = {}

local Hidden = setmetatable ({}, {
  __mode = "k",
})

function Access.new (authentication, store)
  local result = setmetatable ({}, Access)
  Hidden [result] = {
    user   = authentication and authentication.user or false,
    data   = store,
  }
  return result
end

function Access.__index (self, key)
  local hidden = Hidden [self]
  assert (hidden)
  local user   = hidden.user
  local data   = hidden.data
  assert (type (data) == "table")
  local subdata   = data [key]
  local subaccess = data ["_" .. tostring (key)]
  if type (subdata) ~= "table" then
    return subdata
  end
  if subdata.hidden then
    return nil
  elseif subaccess then
    if subaccess (user, data, Configuration.permissions.read) then
      return nil
    end
  elseif subdata.access then
    if not subdata.access (user, subdata, Configuration.permissions.read) then
      return nil
    end
  end
  local result = setmetatable ({}, Access)
  Hidden [result] = {
    user = user,
    data = subdata,
  }
  return result
end

function Access.__newindex ()
  assert (false)
end

function Access.__pairs (access)
  local hidden = Hidden [access]
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for k in Store.pairs (hidden.data) do
      local a = access [k]
      if a then
        coroutine.yield (k, a)
      end
    end
  end)
end

function Access.__ipairs (access)
  local hidden = Hidden [access]
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for i in Store.ipairs (hidden.data) do
      local a = access [i]
      if a then
        coroutine.yield (i, a)
      end
    end
  end)
end


return Access