local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Redis         = require "cosy.redis"
local Value         = require "cosy.value"
local encode        = require "cosy.store.key".encode
local decode        = require "cosy.store.key".decode
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
  return Document.new {
    store    = store,
    keys     = { namespace },
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
  assert (type (t.keys) == "table")
  local keys = {}
  for i = 1, #t.keys do
    keys [i] = encode (t.keys [i])
  end
  local key   = table.concat (keys, "/")
  local store = assert (Hidden [t.store])
  if store.documents [key] then
    return store.documents [key]
  end
  store.redis:watch (key)
  local data = store.redis:get (key)
  if data then
    data = Value.decode (data)
  end
  local document = setmetatable ({}, Document)
  Hidden [document] = {
    data      = data,
    dirty     = false,
    keys      = t.keys,
    store     = t.store,
  }
  Hidden [document].root = document
  store.documents [key]  = document
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
  local keys = {}
  for i = 1, #document.keys do
    keys [i] = document.keys [i]
  end
  keys [#keys+1] = pattern
  return Document.new {
    keys  = keys,
    store = document.store,
  }
end

function Document.__tostring (document)
  assert (getmetatable (document) == Document.__metatable)
  document = assert (Hidden [document])
  document = assert (Hidden [document.root])
  return table.concat (document.keys, "/")
end

function Document.__add (document, key)
  assert (getmetatable (document) == Document.__metatable)
  document = assert (Hidden [document])
  document = assert (Hidden [document.root])
  local keys = {}
  for i = 1, #document.keys do
    keys [i] = document.keys [i]
  end
  keys [#keys+1] = key
  local result = Document.new {
    keys  = keys,
    store = document.store,
  }
  document        = assert (Hidden [result])
  document.data   = {}
  document.dirty  = true
  document.loaded = true
  return result
end

function View.new (store)
  assert (getmetatable (store) == Store.__metatable)
  local result = setmetatable ({}, View)
  Hidden [result] = {
    access   = true,
    iterator = false,
    store    = store,
    token    = false,
  }
  Hidden [result].root = result
  return result
end

function View.from_key (view, key, iterator)
  assert (getmetatable (view) == View.__metatable)
  assert (type (key) == "string")
  local rawview  = assert (Hidden [view])
  local store    = assert (Hidden [rawview.store])
  local document = store.documents [key]
  if not document then
    document = rawview.root
    for sub in key:gmatch "[^/]+" do
      document = document / decode (sub)
    end
    document = Hidden [document].document
  end
  local result    = setmetatable ({}, View)
  Hidden [result] = {
    access   = rawview.access,
    document = document,
    iterator = iterator,
    root     = rawview.root,
    store    = rawview.store,
    token    = rawview.token,
  }
  return result
end

function View.specialize (view, token)
  assert (getmetatable (view) == View.__metatable)
  view = assert (Hidden [view])
  local result = setmetatable ({}, View)
  Hidden [result] = {
    access   = type (token) == "table"
           and token.type == "administration"
            or false,
    document = view.document,
    iterator = view.iterator,
    root     = view.root,
    store    = view.store,
    token    = token,
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
  view            = assert (Hidden [view])
  local value     = assert (view.document) [key]
  if type (value) ~= "table" then
    return value
  end
  local result    = setmetatable ({}, View)
  Hidden [result] = {
    access   = view.access,
    document = value,
    iterator = view.iterator,
    root     = view.root,
    store    = view.store,
    token    = view.token,
  }
  return result
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
  assert (type (pattern) == "string")
  view = assert (Hidden [view])
  local document
  if view.document then
    document = assert (view.document) / pattern
  else
    document = assert (view.store   ) / pattern
  end
  local rawdocument = assert (Hidden [document])
  if rawdocument.data == nil then
    return nil
  end
  local result      = setmetatable ({}, View)
  Hidden [result]   = {
    access   = view.access,
    document = document,
    iterator = view.iterator,
    root     = view.root,
    store    = view.store,
    token    = view.token,
  }
  return result
end

function View.__mul (view, pattern)
  assert (getmetatable (view) == View.__metatable)
  assert (type (pattern) == "string")
  view = assert (Hidden [view])
  local document
  if view.document then
    document = assert (view.document) / pattern
  else
    document = assert (view.store   ) / pattern
  end
  local result = setmetatable ({}, View)
  Hidden [result]   = {
    access   = view.access,
    document = document,
    iterator = true,
    root     = view.root,
    store    = view.store,
    token    = view.token,
  }
  return result
end

function View.export (view)
  assert (getmetatable (view) == View.__metatable)
  view = assert (Hidden [view])
  local document
  if view.document then
    document = assert (view.document)
  else
    document = assert (view.store   )
  end
  local rawdocument = assert (Hidden [document])
  return rawdocument.data
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
  rawdoc.dirty    = true
  local result    = setmetatable ({}, View)
  Hidden [result] = {
    access   = rawview.access,
    document = document,
    iterator = rawview.iterator,
    root     = rawview.root,
    store    = rawview.store,
    token    = rawview.token,
  }
  return result
end

function View.__sub (view, x)
  assert (getmetatable (view) == View.__metatable)
  if type (x) == "string" then
    for _, document in view * x do
      local _ = document - ".*"
      document = assert (Hidden [document]).document
      document = assert (Hidden [document])
      document.data   = nil
      document.dirty  = true
      document.loaded = true
    end
  elseif getmetatable (x) == View.__metatable then
    for _, lhs in view do
      local lhsd = assert (Hidden [lhs ]).document
      local lhsk = assert (Hidden [lhsd]).keys
      for _, rhs in x do
        local rhsd = assert (Hidden [rhs ]).document
        local rhsk = assert (Hidden [rhsd]).keys
        local suppress = true
        for i = 1, #lhsk do
          if lhsk [i] ~= rhsk [i] then
            suppress = false
            break
          end
        end
        if suppress then
          local current = lhs
          for i = #lhsk+1, #rhsk-1 do
            current = current / rhsk [i]
          end
          local _ = current - rhsk [#rhsk]
        end
      end
    end
  else
    assert (false)
  end
  return view
end

function View.__call (view)
  assert (getmetatable (view) == View.__metatable)
  local rawview = assert (Hidden [view])
  if type (rawview.ifunction) ~= "function" then
    local document  = assert (Hidden [rawview.document])
    local store     = assert (Hidden [rawview.store])
    local coroutine = Coromake ()
    local seen      = {}
    local function match (key)
      local extracted = {}
      for skey in key:gmatch "[^/]+" do
        extracted [#extracted+1] = decode (skey)
      end
      if #extracted == #document.keys then
        local matched = true
        for i = 1, #extracted do
          if not extracted [i]:match ("^" .. document.keys [i] .. "$") then
            matched = false
            break
          end
        end
        if  matched
        and not seen [key] then
          seen [key] = true
          local v = View.from_key (view, key)
          local d = Hidden [v].document
          if Hidden [d].data ~= nil then
            coroutine.yield (v)
          end
        end
      end
    end
    rawview.ifunction = coroutine.wrap (function ()
      for key in pairs (store.documents) do
        match (key)
      end
      local pattern = {}
      for i = 1, #document.keys do
        local key = document.keys [i]
        pattern [i] = is_pattern (key) and "*" or encode (key)
      end
      pattern = table.concat (pattern, "/")
      local cursor = 0
      repeat
        local r = store.redis:scan (cursor, {
          match = pattern,
          count = 100,
        })
        cursor = r [1]
        for i = 1, #r [2] do
          match (r [2] [i])
        end
      until cursor == "0"
      rawview.ifunction = false
    end)
  end
  return rawview.ifunction ()
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
    for i = 1, Layer.size (Configuration.resource ["/"]) do
      local key  = Configuration.resource ["/"] [i]
      local name = key.__keys [#key.__keys]
      client:setnx (encode (name), Value.expression {})
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
  export = function (view)
    if getmetatable (view) == View.__metatable then
      return View.export (view)
    else
      return view
    end
  end,
  pairs  = View.__pairs,
  ipairs = View.__ipairs,
  size   = View.__len,
}
