local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Redis         = require "cosy.redis"
local Value         = require "cosy.value"
local Coromake      = require "coroutine.make"
local Layer         = require "layeredata"

Configuration.load {
  "cosy.methods",
}

local i18n = I18n.load "cosy.store"

local Store      = {}
local Collection = {}
local Document   = {}

function Store.new ()
  local client = Redis ()
  client:unwatch ()
  return setmetatable ({
    __redis       = client,
    __collections = {},
  }, Store)
end

function Store.__index (store, key)
  local resource = Configuration.resource [key]
  if not resource then
    return nil
  end
  local pattern  = resource.key
  local template = resource.template
  assert (pattern, key)
  template = template and Layer.flatten (template) or {}
  local collection = setmetatable ({
    __store    = store,
    __pattern  = pattern,
    __data     = {},
    __name     = key,
    __template = Layer.new {
      name = key,
      data = template,
    },
  }, Collection)
  store.__collections [key] = collection
  return collection
end

function Store.__newindex ()
  assert (false)
end

function Store.commit (store)
  local client = store.__redis
  client:multi ()
  local ok = pcall (function ()
    for _, collection in pairs (store.__collections) do
      local pattern = collection.__pattern
      for key, document in pairs (collection.__data) do
        if document.__dirty then
          local name  = pattern % {
            key = key,
          }
          local value = document.__data
          if value == nil then
            client:del (name)
          else
            value.__depends__ = nil
            local expire_at = value.expire_at
            client:set (name, Value.encode (Layer.export (value)))
            if expire_at then
              client:expireat (name, math.ceil (expire_at))
            else
              client:persist (name)
            end
          end
        end
      end
    end
  end)
  if ok then
    if not client:exec () then
      error {
        _ = i18n ["redis:retry"],
      }
    end
  else
    client:discard ()
  end
end

function Store.exists (collection, key)
  local store  = collection.__store
  local client = store.__redis
  local name   = collection.__pattern % {
    key = key,
  }
  return client:exists (name)
end

function Store.filter (collection, filter)
  local coroutine = Coromake ()
  local store     = collection.__store
  local client    = store.__redis
  return coroutine.wrap (function ()
    local name   = collection.__pattern % { key = filter }
    local cursor = 0
    repeat
      local t = client:scan (cursor, {
        match = name,
        count = 100,
      })
      cursor = t [1]
      local data = t [2]
      for i = 1, #data do
        local key   = (collection.__pattern / data [i]).key
        local value = collection.__data [key]
        coroutine.yield (key, value)
      end
    until cursor == "0"
  end)
end

function Collection.__index (collection, key)
  if not collection.__data [key] then
    local store  = collection.__store
    local client = store.__redis
    local name   = collection.__pattern % {
      key = key,
    }
    client:watch (name)
    local value  = client:get (name)
    if value == nil then
      return nil
    end
    local layer = Layer.new {
      name = key,
      data = Value.decode (value),
    }
    layer.__depends__ = { collection.__template }
    collection.__data [key] = {
      __store = store,
      __dirty = false,
      __data  = layer,
    }
  end
  return Document.new (collection.__data [key])
end

function Collection.__newindex (collection, key, value)
  local store = collection.__store
  if value == nil then
    collection.__data [key] = {
      __store = store,
      __dirty = true,
      __layer = nil,
      __data  = nil,
    }
  else
    local layer = Layer.new {
      name = key,
      data = value,
    }
    if type (value) == "table" then
      layer.__depends__ = { collection.__template }
    end
    collection.__data [key] = {
      __store = store,
      __dirty = true,
      __data  = layer,
    }
  end
end

function Collection.__pairs (collection)
  return Store.filter (collection, "*")
end

function Collection.__len (collection)
  local store  = collection.__store
  local client = store.__redis
  local i = 0
  repeat
    i = i+1
    local name   = collection.__pattern % {
      key = i,
    }
    local exists = client:exists (name)
  until not exists
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
  return setmetatable ({
    __root = root,
    __data = root.__data,
  }, Document)
end

function Document.__index (document, key)
  local result = document.__data [key]
  if getmetatable (result) ~= Layer then
    return result
  else
    return setmetatable ({
      __root = document.__root,
      __data = result,
    }, Document)
  end
end

function Document.__newindex (document, key, value)
  document.__data [key] = value
  document.__root.__dirty = true
end

function Document.__pairs (document)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for k in Layer.pairs (document.__data) do
      coroutine.yield (k, document [k])
    end
  end)
end

function Document.__ipairs (document)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for i = 1, Layer.size (document.__data) do
      coroutine.yield (i, document [i])
    end
  end)
end

function Document.__len (document)
  return Layer.size (document.__data)
end

return Store
