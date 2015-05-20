local Configuration = require "cosy.configuration"
local Redis         = require "cosy.redis"
local Value         = require "cosy.value"

local Coromake      = require "coroutine.make"

local Store      = {}
local Collection = {}
local Document   = {}

Store.Error     = setmetatable ({}, { __tostring = function () return "ERROR"   end })
local PATTERN   = setmetatable ({}, { __tostring = function () return "PATTERN" end })
local DATA      = setmetatable ({}, { __tostring = function () return "DATA"    end })
local ROOT      = setmetatable ({}, { __tostring = function () return "ROOT"    end })
local DIRTY     = setmetatable ({}, { __tostring = function () return "DIRTY"   end })

function Store.new ()
  return setmetatable ({}, Store)
end

function Store.__index (store, key)
  local collection = Collection.new (key)
  rawset (store, key, collection)
  return collection
end

function Store.__newindex ()
  assert (false)
end

function Store.commit (store)
  local client = Redis ()
  client:multi ()
  for _, collection in pairs (store) do
    local pattern = collection [PATTERN]
    for key, document in pairs (collection [DATA]) do
      if document [DIRTY] then
        local name  = pattern % {
          key = Value.expression (key),
        }
        local value = document [DATA]
        if value == nil then
          client:del (name)
        else
          client:set (name, Value.encode (value))
          if type (value) == "table" and value.expire_at then
            client:expireat (name, math.ceil (value.expire_at))
          else
            client:persist (name)
          end
        end
      end
    end
  end
  if not client:exec () then
    error (Store.Error)
  end
end

function Collection.new (key)
  local pattern = Configuration.redis.key [key]._
  assert (pattern, key)
  return setmetatable ({
    [PATTERN] = pattern,
    [DATA   ] = {},
  }, Collection)
end

function Collection.__index (collection, key)
  if not collection [DATA] [key] then
    local name   = collection [PATTERN] % {
      key = Value.expression (key),
    }
    local client = Redis ()
    client:watch (name)
    local value  = client:get (name)
    if value ~= nil then
      value = Value.decode (value)
    end
    collection [DATA] [key] = {
      [DIRTY] = false,
      [DATA ] = value,
    }
  end
  return Document.new (collection [DATA] [key])
end

function Collection.__newindex (collection, key, value)
  collection [DATA] [key] = {
    [DIRTY] = true,
    [DATA ] = value,
  }
end

function Collection.__pairs (collection)
  local coroutine = require "coroutine.make" ()
  return coroutine.wrap (function ()
    local name   = collection [PATTERN] % { key = "*" }
    local client = Redis ()
    local cursor = 0
    repeat
      local t = client:scan (cursor, {
        match = name,
        count = 100,
      })
      cursor = t [1]
      local data = t [2]
      for i = 1, #data do
        local key   = (collection [PATTERN] / data [i]).key
        local value = collection [key]
        coroutine.yield (Value.decode (key), value)
      end
    until cursor == "0"
  end)
end

function Collection.__len (collection)
  local i = 0
  repeat
    i = i+1
    local value = collection [i]
  until value == nil
  return i-1
end

function Collection.__ipairs (collection)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    local i = 0
    repeat
      i = i+1
      local value = collection [i]
      if value == nil then
        return
      end
      coroutine.yield (i, value)
    until true
  end)
end

function Document.new (root)
  local result = root [DATA]
  if type (result) ~= "table" then
    return result
  else
    return setmetatable ({
      [ROOT] = root,
      [DATA] = result,
    }, Document)
  end
end

function Document.__index (document, key)
  local result = document [DATA] [key]
  if type (result) ~= "table" then
    return result
  else
    return setmetatable ({
      [ROOT] = document [ROOT],
      [DATA] = result,
    }, Document)
  end
end

function Document.__newindex (document, key, value)
  document [DATA] [key  ] = value
  document [ROOT] [DIRTY] = true
end

function Document.__pairs (document)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for k in pairs (document [DATA]) do
      coroutine.yield (k, document [k])
    end
  end)
end

function Document.__ipairs (document)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for i = 1, #document do
      coroutine.yield (i, document [i])
    end
  end)
end

function Document.__len (document)
  return # document [DATA]
end

return Store
