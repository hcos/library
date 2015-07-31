local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Redis         = require "cosy.redis"
local Value         = require "cosy.value"
local Layer         = require "layeredata"
local Coromake      = require "coroutine.make"

Configuration.load {
  "cosy.methods",
}

local i18n = I18n.load "cosy.store"

local Hidden   = setmetatable ({}, { __mode = "k" })
local Store    = { __metatable = "Store"    }
local Document = { __metatable = "Document" }
local View     = { __metatable = "View"     }

local function is_pattern (s)
  return s:find "[*+-?%%%[%]]" ~= nil
end

function Store.new ()
  local client = Redis ()
  client:unwatch ()
  local result    = setmetatable ({}, Store)
  Hidden [result] = {
    documents = {},
    redis     = client,
  }
  return result
end

function Store.commit (store)
  assert (getmetatable (store) == Store.__metatable)
  store = assert (Hidden [store])
  store.redis:multi ()
  local ok = pcall (function ()
    for key, document in pairs (store.documents) do
      document = assert (Hidden [document])
      if document.dirty then
        if document.data == nil then
          store.redis:del (key)
        else
          store.redis:set (key, Value.encode (document.data))
        end
      end
    end
  end)
  if ok then
    if not store.redis:exec () then
      store.redis:discard ()
      error {
        _ = i18n ["redis:retry"],
      }
    end
  else
    store.redis:discard ()
  end
end

function Store.__div (store, namespace)
  assert (getmetatable (store) == Store.__metatable)
  assert (type (namespace) == "string")
  local resource = assert (Configuration.resource [namespace])
  return Document.new {
    store    = store,
    resource = resource,
    key      = "/" .. namespace
  }
end

function Store.__index ()
  assert (false)
end

function Store.__newindex ()
  assert (false)
end

function Store.__tostring (store)
  assert (getmetatable (store) == Store.__metatable)
  return "/"
end

function Document.new (t)
  assert (type (t) == "table")
  assert (getmetatable (t.store) == Store.__metatable)
  assert (type (t.resource) == "table")
  assert (type (t.key     ) == "string")
  local store = assert (Hidden [t.store])
  if store.documents [t.key] then
    return store.documents [t.key]
  end
  store.redis:watch (t.key)
  local data = store.redis:get (t.key)
  if data then
    data = Value.decode (data)
  end
  local document = setmetatable ({}, Document)
  Hidden [document] = {
    data      = data,
    dirty     = false,
    key       = t.key,
    resource  = t.resource,
    store     = t.store,
  }
  Hidden [document].root = document
  store.documents [t.key] = document
  return document
end

function Document.__index (document, key)
  assert (getmetatable (document) == Document.__metatable)
  document = assert (Hidden [document])
  assert (type (document.data) == "table")
  local value = document.data [key]
  if type (value) == "table" then
    local result    = setmetatable ({}, Document)
    Hidden [result] = {
      data = value,
      root = document.root,
    }
    return result
  else
    return value
  end
end

function Document.__newindex (document, key, value)
  assert (getmetatable (document) == Document.__metatable)
  document = assert (Hidden [document])
  if getmetatable (value) == Document.__metatable then
    value = assert (Hidden [value]).data
  end
  assert (type (document.data) == "table")
  document.data [key] = value
  local root = assert (Hidden [document.root])
  root.dirty = true
end

function Document.__div (document, pattern)
  assert (getmetatable (document) == Document.__metatable)
  assert (type (pattern) == "string")
  document = assert (Hidden [document])
  document = assert (Hidden [document.root])
  return Document.new {
    store    = document.store,
    resource = document.resource ["/"],
    key      = document.key .. "/" .. pattern,
  }
end

function Document.__tostring (document)
  assert (getmetatable (document) == Document.__metatable)
  document = assert (Hidden [document])
  document = assert (Hidden [document.root])
  return document.key
end

function Document.__add (document, key)
  assert (getmetatable (document) == Document.__metatable)
  document = assert (Hidden [document])
  document = assert (Hidden [document.root])
  local result    = Document.new {
    key      = document.key .. "/" .. key,
    resource = document.resource ["/"],
    store    = document.store,
  }
  document      = assert (Hidden [result])
  document.data = {}
  return result
end

function View.new (store)
  assert (getmetatable (store) == Store.__metatable)
  local result = setmetatable ({}, View)
  Hidden [result] = {
    access   = true,
    store    = store,
    token    = false,
  }
  Hidden [result].root = Hidden [result]
  return result
end

function View.from_key (view, key)
  assert (getmetatable (view) == View.__metatable)
  assert (type (key) == "string")
  view              = assert (Hidden [view])
  local store       = assert (Hidden [view.store])
  local document    = store.documents [key]
  if not document then
    return nil
  end
  local result      = setmetatable ({}, View)
  Hidden [result]   = {
    access   = view.access,
    document = document,
    root     = view.root,
    store    = view.store,
    token    = view.token,
  }
  Hidden [result].root = Hidden [result]
  return result
end

function View.specialize (view, token)
  assert (getmetatable (view) == View.__metatable)
  view = assert (Hidden [view])
  local result = setmetatable ({}, View)
  Hidden [result] = {
    access = type (token) == "table"
         and token.type == "administration"
          or false,
    root   = view.root,
    store  = view.store,
    token  = token,
  }
  return result
end

function View.__unm (view)
  assert (getmetatable (view) == View.__metatable)
  local document = assert (Hidden [view]).document
  local data     = assert (Hidden [document]).data
  return data ~= false and data ~= nil
end

function View.__index (view, key)
  assert (getmetatable (view) == View.__metatable)
  view = assert (Hidden [view])
  local document = assert (view.document)
  return document [key]
end

function View.__newindex (view, key, value)
  assert (getmetatable (view) == View.__metatable)
  view = assert (Hidden [view])
  local document = assert (view.document)
  if getmetatable (value) == View.__metatable then
    value = assert (Hidden [value].document)
  end
  document [key] = value
end

function View.__div (view, pattern)
  assert (getmetatable (view) == View.__metatable)
  view = assert (Hidden [view])
  local document
  if view.document then
    document = assert (view.document) / pattern
  else
    document = assert (view.store   ) / pattern
  end
  local rawdocument = assert (Hidden [document])
  if rawdocument.data == nil and not is_pattern (pattern) then
    return nil
  end
  local result      = setmetatable ({}, View)
  Hidden [result]   = {
    access   = view.access,
    document = document,
    root     = view.root,
    store    = view.store,
    token    = view.token,
  }
  Hidden [result].root = Hidden [result]
  return result
end

function View.__add (view, key)
  assert (getmetatable (view) == View.__metatable)
  assert (type (key) == "string")
  local rawview = assert (Hidden [view])
  local document
  if rawview.document then
    document = assert (Hidden [view].document)
    assert (document + key)
    document = document / key
  else
    document = assert (rawview.store) / key
  end
  local rawdoc    = assert (Hidden [document])
  rawdoc.data     = {}
  local result    = setmetatable ({}, View)
  Hidden [result] = {
    access   = rawview.access,
    document = document,
    store    = rawview.store,
    token    = rawview.token,
  }
  Hidden [result].root = Hidden [result]
  return result
end

function View.__sub (view, pattern)
  assert (getmetatable (view) == View.__metatable)
  for _, document in view / pattern do
    document = assert (Hidden [document]).document
    document = assert (Hidden [document])
    document.data   = nil
    document.dirty  = true
    document.loaded = true
  end
  return view
end

function View.__call (view)
  assert (getmetatable (view) == View.__metatable)
  local rawview   = assert (Hidden [view])
  if not rawview.iterator then
    local document  = assert (Hidden [rawview.document])
    local store     = assert (Hidden [rawview.store])
    local coroutine = Coromake ()
    rawview.iterator = coroutine.wrap (function ()
      for key, doc in pairs (store.documents) do
        if key:match (document.key) and Hidden [doc].data ~= nil then
          coroutine.yield (key, View.from_key (view, key))
        end
      end
      local cursor = 0
      repeat
        local r = store.redis:scan (cursor, {
          match = is_pattern (document.key)
              and document.key:match "^(/.-/).*$" .. "*"
               or document.key,
          count = 100,
        })
        cursor = r [1]
        for i = 1, #r [2] do
          local key = r [2] [i]
          if key:match (document.key) then
            coroutine.yield (key, View.from_key (view, key))
          end
        end
      until cursor == "0"
      rawview.iterator = false
    end)
  end
  return rawview.iterator ()
end

function View.__pairs (view)
  assert (getmetatable (view) == View.__metatable)
  view            = assert (Hidden [view])
  local document  = assert (Hidden [view.document])
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for k in pairs (document.data) do
      coroutine.yield (k, view.document [k])
    end
  end)
end

function View.__ipairs (view)
  assert (getmetatable (view) == View.__metatable)
  view            = assert (Hidden [view])
  local document  = assert (Hidden [view.document])
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for i = 1, #document.data do
      coroutine.yield (i, view.document [i])
    end
  end)
end

function View.__len (view)
  assert (getmetatable (view) == View.__metatable)
  view            = assert (Hidden [view])
  local document  = assert (Hidden [view.document])
  return #document.data
end

function View.__tostring (view)
  assert (getmetatable (view) == View.__metatable)
  view = assert (Hidden [view])
  if view.document then
    return tostring (view.document)
  else
    return tostring (view.store)
  end
end

return {
  initialize = function ()
    local client = Redis ()
    client:unwatch ()
    for k in Layer.pairs (Configuration.resource) do
      if type (k) == "string" then
        client:setnx ("/" .. k, Value.expression {})
      end
    end
  end,
  new = function ()
    return View.new (Store.new ())
  end,
  specialize = function (view)
    assert (getmetatable (view) == View.__metatable)
    return View.specialize (view)
  end,
  commit = function (view)
    assert (getmetatable (view) == View.__metatable)
    return Store.commit (Hidden [view].store)
  end,
  exists = function (view)
    assert (view == nil or getmetatable (view) == View.__metatable)
    if view == nil then
      return false
    else
      return -view
    end
  end,
  pairs  = View.__pairs,
  ipairs = View.__ipairs,
  size   = View.__len,
}
