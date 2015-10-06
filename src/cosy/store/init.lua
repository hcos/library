local I18n      = require "cosy.i18n"
local Redis     = require "cosy.redis"
local Value     = require "cosy.value"
local encode    = require "cosy.store.key".encode
local decode    = require "cosy.store.key".decode
local Coromake  = require "coroutine.make"

local i18n      = I18n.load "cosy.store"

local Hidden    = setmetatable ({}, { __mode = "k" })
local Store     = { __metatable = "store"     }
local View      = { __metatable = "view"      }
local Documents = { __metatable = "documents" }

local unpack    = table.unpack or unpack

function Documents.new (store)
  return setmetatable ({
    store  = store,
    loaded = {
      [true] = {
        data  = false,
        dirty = false,
      }
    },
  }, Documents)
end

function Documents.__index (documents, t)
  assert (getmetatable (documents) == Documents.__metatable)
  assert (type (t) == "table" or type (t) == "string")
  if #t == 0 then
    return documents.loaded [true]
  end
  local key = t
  if type (t) == "table" then
    local keys = {}
    for i = 1, #t do
      if t [i].is_pattern then
        return nil, "pattern"
      end
      keys [i] = encode (t [i].key)
    end
    key = table.concat (keys, "/")
  end
  local found = documents.loaded [key]
  if found then
    return found
  end
  local store = documents.store
  store.redis:watch (key)
  local data = store.redis:get (key)
  if data then
    data = Value.decode (data)
  end
  documents.loaded [key] = {
    data  = data,
    dirty = false,
  }
  return documents.loaded [key]
end

function Documents.filter (documents, t)
  assert (getmetatable (documents) == Documents.__metatable)
  assert (type (t) == "table")
  local coroutine = Coromake ()
  local seen      = {}
  local function match (key)
    if type (key) ~= "string" then
      return false
    end
    local parts = {}
    for part in key:gmatch "[^/]+" do
      parts [#parts+1] = decode (part)
    end
    if #t ~= #parts then
      return false
    end
    for i = 1, #t do
      local found = parts [i]:find (t [i].key, 1, not t [i].is_pattern)
      if not found then
        return false
      end
    end
    return parts
  end
  return coroutine.wrap (function ()
    for key, document in pairs (documents.loaded) do
      local parts = match (key)
      if parts and not seen [key] then
        seen [key] = true
        coroutine.yield (parts, document)
      end
    end
    local pattern = {}
    for i = 1, #t do
      pattern [i] = t [i].is_pattern
                and "*"
                 or encode (t [i].key)
    end
    pattern = table.concat (pattern, "/")
    local cursor = 0
    repeat
      local r = documents.store.redis:scan (cursor, {
        match = pattern,
        count = 100,
      })
      cursor = r [1]
      for i = 1, #r [2] do
        local key   = r [2] [i]
        local parts = match (key)
        if parts and not seen [key] then
          seen [key] = true
          coroutine.yield (parts, documents [parts])
        end
      end
    until cursor == "0"
  end)
end

function Documents.__newindex ()
  assert (false)
end

Store.__index = Store

function Store.__newindex (...)
  print (...)
  assert (false)
end

function Store.new ()
  local result     = {}
  result.redis     = Redis ()
  result.documents = Documents.new (result)
  result.redis:unwatch ()
  return setmetatable (result, Store)
end

function Store.commit (store)
  assert (getmetatable (store) == Store.__metatable)
  store.redis:multi ()
  local ok = pcall (function ()
    for key, document in pairs (store.documents.loaded) do
      if key ~= true and document.dirty then
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

function Store.cancel (store)
  assert (getmetatable (store) == Store.__metatable)
  store.redis:multi ()
  store.redis:discard ()
end

function Store.toview (store)
  assert (getmetatable (store) == Store.__metatable)
  return View.new (store)
end

function View.new (store)
  assert (getmetatable (store) == Store.__metatable)
  local result = setmetatable ({}, View)
  Hidden [result] = {
    store    = store,
    token    = false,
    document = {},
    field    = {},
  }
  return result
end

function View.copy (view)
  assert (getmetatable (view) == View.__metatable)
  local rawview   = assert (Hidden [view])
  local result    = setmetatable ({}, View)
  Hidden [result] = {
    store    = rawview.store,
    token    = rawview.token,
    document = { unpack (rawview.document) },
    field    = { unpack (rawview.field   ) },
  }
  return result
end

function View.__mod (view, token)
  assert (getmetatable (view) == View.__metatable)
  local result = View.copy (view)
  local raw    = assert (Hidden [result])
  raw.token    = token
  return result
end

function View.document (view)
  assert (getmetatable (view) == View.__metatable)
  local rawview = assert (Hidden [view])
  assert (#rawview.field == 0)
  return rawview.store.documents [rawview.document]
end

function View.subdocument (view, key, is_pattern)
  assert (getmetatable (view) == View.__metatable)
  assert (type (key) == "string")
  local document    = View.document (view)
  assert (document ~= nil and document.data ~= nil)
  local result    = View.copy (view)
  local rawresult = assert (Hidden [result])
  rawresult.document [#rawresult.document+1] = {
    is_pattern = is_pattern,
    key        = key,
  }
  return result
end

function View.__div (view, key)
  assert (getmetatable (view) == View.__metatable)
  assert (type (key) == "string")
  local result   = View.subdocument (view, key, false)
  local document = View.document (result)
  if document == nil or document.data == nil then
    return nil
  end
  return result
end

function View.__mul (view, key)
  assert (getmetatable (view) == View.__metatable)
  assert (type (key) == "string")
  return View.subdocument (view, key, true)
end

function View.field (view)
  assert (getmetatable (view) == View.__metatable)
  local rawview  = assert (Hidden [view])
  local document = View.document (view)
  assert (document ~= nil and document.data ~= nil)
  local value    = document.data
  for i = 1, #rawview.field do
    assert (type (value) == "table")
    value = value [rawview.field [i]]
    assert (type (value) == "table")
  end
  return value
end

function View.__index (view, key)
  assert (getmetatable (view) == View.__metatable)
  local field = View.field (view) [key]
  if type (field) ~= "table" then
    return field
  else
    local result    = View.copy (view)
    local rawresult = assert (Hidden [view])
    rawresult.field [#rawresult.field+1] = key
    return result
  end
end

function View.__newindex (view, key, value)
  assert (getmetatable (view) == View.__metatable)
  local document = View.document (view)
  assert (document ~= nil and document.data ~= nil)
  document.dirty = true
  local field = View.field (view)
  if type (value) == "table" then
    local subview = view [key]
    field [key] = {}
    for k, v in pairs (value) do
      subview [k] = v
    end
  else
    field [key] = value
  end
end

function View.__call (view)
  assert (getmetatable (view) == View.__metatable)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    local rawview = assert (Hidden [view])
    for t in Documents.filter (rawview.store.documents, rawview.document) do
      local result       = View.copy (view)
      local rawresult    = assert (Hidden [result])
      for i = 1, #t do
        t [i] = {
          is_pattern = false,
          key        = t [i],
        }
      end
      rawresult.document = t
      coroutine.yield (result)
    end
  end)
end

function View.__pairs (view)
  assert (getmetatable (view) == View.__metatable)
  local field = View.field (view)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for k in pairs (field) do
      coroutine.yield (k, view [k])
    end
  end)
end

function View.__ipairs (view)
  assert (getmetatable (view) == View.__metatable)
  local coroutine = Coromake ()
  return coroutine.wrap (function ()
    for i = 1, View.__len (view) do
      coroutine.yield (i, view [i])
    end
  end)
end

function View.__len (view)
  assert (getmetatable (view) == View.__metatable)
  return # View.field (view)
end

function View.__tostring (view)
  assert (getmetatable (view) == View.__metatable)
  local rawview  = assert (Hidden [view])
  local doc      = View.document (view)
  local document = {}
  local field    = {}
  if #rawview.document == 0 then
    document [1] = "(root)"
  else
    for i = 1, #rawview.document do
      document [i] = rawview.document [i].is_pattern
                 and "¿" .. rawview.document [i].key .. "?"
                  or rawview.document [i].key
    end
  end
  for i = 1, #rawview.field do
    field [i] = rawview.field [i]
  end
  return table.concat (document, "/")
      .. ":"
      .. table.concat (field, ".")
      .. ":"
      .. (doc and doc.dirty and "[dirty]" or "")
end

function View.__add (view, key)
  assert (getmetatable (view) == View.__metatable)
  assert (type (key) == "string")
  local document  = View.document (view)
  assert (document ~= nil and document.data ~= nil)
  local result    = View.copy (view)
  local rawresult = assert (Hidden [result])
  rawresult.document [#rawresult.document+1] = {
    is_pattern = false,
    key        = key,
  }
  local subdocument = View.document (result)
  subdocument.data  = {}
  subdocument.dirty = true
  return result
end

function View.__unm (view)
  assert (getmetatable (view) == View.__metatable)
  for subdocument in (view * ".*") () do
    local _ = - subdocument
  end
  local rawview = assert (Hidden [view])
  for _, document in Documents.filter (rawview.store.documents, rawview.document) do
    document.data  = nil
    document.dirty = true
  end
end

function View.__sub (view, x)
  assert (getmetatable (view) == View.__metatable)
  assert (type (x) == "string")
  return - (view / x)
end

function View.__eq (lhs, rhs)
  assert (getmetatable (lhs) == View.__metatable)
  assert (getmetatable (rhs) == View.__metatable)
  local rawlhs = assert (Hidden [lhs])
  local rawrhs = assert (Hidden [rhs])
  if #rawlhs.document ~= #rawrhs.document then
    return false
  end
  assert (#rawlhs.field == 0)
  assert (#rawrhs.field == 0)
  for i = 1, #rawlhs.document do
    if rawlhs.document [i].key        ~= rawrhs.document [i].key
    or rawlhs.document [i].is_pattern ~= rawrhs.document [i].is_pattern
    then
      return false
    end
  end
  return true
end

function View.__lt (lhs, rhs)
  assert (getmetatable (lhs) == View.__metatable)
  assert (getmetatable (rhs) == View.__metatable)
  local rawlhs = assert (Hidden [lhs])
  local rawrhs = assert (Hidden [rhs])
  if #rawlhs.document >= #rawrhs.document then
    return false
  end
  assert (#rawlhs.field == 0)
  assert (#rawrhs.field == 0)
  for i = 1, #rawlhs.document do
    if rawlhs.document [i].key        ~= rawrhs.document [i].key
    or rawlhs.document [i].is_pattern ~= rawrhs.document [i].is_pattern
    then
      return false
    end
  end
  return true
end

function View.__le (lhs, rhs)
  return lhs <  rhs
      or lhs == rhs
end

return Store
