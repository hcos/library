-- Utilities
-- =========

-- This module defines some utility functions, that are used in
-- CosyVerif.

-- Source Code Helpers
-- ===================

-- Ignoring parameters
-- -------------------
--
-- Coding standards in CosyVerif require:
--
-- * 100 % code coverage by tests;
-- * no warning by luacheck.
--
-- The latter is difficult to reach as warnings are emitted for unused
-- function parameters. To explicitly state that these parameters are
-- useless, please use the `ignore` function.
--
-- ### Usage
--
--      function f (a, b, c)
--        ignore (a, c)
--        ...
--      end
--
-- ### Warning
--
-- Using the `ignore` function is __not__ efficient in the standard Lua
-- interpreter. It is almost as good as not using it in LuaJIT (see
-- the benchmarks in `util.bench.lua`).
--
-- In all cases, prefer it to the usual construct `local _ = a, b`, as the
-- intention in the latter is not obvious for non Lua programmers.
--
-- ### Implementation
--
-- Implementation is trivial: we use variadic arguments and do nothing of
-- them.
--
local function ignore (...)
end


-- Proxies
-- =======
--
-- TODO: explain more on data
--
-- Data is represented as raw tables, and operations are implemented either
-- as functions, or as proxies over raw data.
-- The goal of this design decision is to allow easy exchange of data over
-- the network, and to select the behaviors depending on the context.
--
-- Tags
-- ----

-- Internal mechanisms require to store some information in the data. In
-- order to avoid name conflicts with user defined keys, we use tables as
-- keys for internal information. Such keys are called  __tags__.
--
-- ### Usage
--
--       local tags = require "cosy.util" . tags
--       local TAG = tags.TAG -- Uppercase by convention for tags

-- ### Implementation
--
-- The implementation relies on overriding the `__index` behavior. Whenever
-- a non existing tag is accessed, it is created on the fly.

local tags
do

  local mt = {}

  -- __Trick:__ the newly created tag is added as early as possible to the
  -- `tags`. This is required to avoid infinite loops when defining the three
  -- tags used within tags.
  function mt:__index (key)
    local result = {}
    self [key] = result
    result [self.IS_TAG] = true
    return result
  end

  tags = setmetatable ({}, mt)

end


-- Proxy specific tags
-- -------------------
--
-- The `DATA` tag is meant to be used only in proxies, to identify the data
-- behind the proxy.
--
local DATA = tags.DATA

-- The `IS_PROXY` tag is also meant to be used only as `x [IS_PROXY] =
-- true` to identify proxies. The `DATA` tag alone is not sufficient, as
-- proxies over the `nil` value do not define the `DATA` tag.
--
local IS_PROXY = tags.IS_PROXY

-- ### Warning
--
-- Proxies can be stacked. Thus, a `DATA` field can be assigned to another
-- proxy.

local function is_proxy (x)
  return type (x) == "table" and
         (getmetatable (x) or {}) [IS_PROXY]
end

-- Access to raw data
-- ------------------
--
-- The `raw` function returns the raw data behind any data (already a raw
-- one or a proxy).
--
-- ### Usage
--
--       local r = raw (x)
--
-- This function is usable on all Lua values, even strings or numbers.
-- When its parameter is a proxy, the raw data behind is returned.
-- Otherwise, the parameter is returned unchanged.
--
-- ### Implementation
--
-- Implementation is trivial: we use iteratively the `DATA` field until
-- it does not exist anymore. The raw data is then reached.

local function raw (x)
  local result = x
  while is_proxy (result) do
    result = rawget (result, DATA)
  end
  return result
end

-- Proxy type
-- ----------

local proxy
do
  local function string (self)
    return tostring (rawget (self, DATA))
  end
  local function eq (lhs, rhs)
    return raw (lhs) == raw (rhs)
  end
  local function len (self)
    return # rawget (self, DATA)
  end
  local function index (self, key)
    return rawget (self, DATA) [key]
  end
  local function newindex_writable (self, key, value)
    rawget (self, DATA) [key] = value
  end
  local function newindex_readonly (self, key, value)
    ignore (self, key, value)
    error "Attempt to write to a read-only proxy."
  end
  local eq_mt = {
    __eq = eq,
  }
  local function call_instance (self, x)
    local below = rawget (self, DATA)
    if is_proxy (below) then
      return getmetatable (self) (below (x))
    else
      return getmetatable (self) (below)
    end
  end
  local function call_metatable (self, x)
    if type (x) == "table" then
      local mt = getmetatable (x)
      if not mt then
        setmetatable (x, eq_mt)
      end
    end
    return setmetatable ({
      [DATA] = x,
    }, self)
  end
  proxy = function (parameters)
    parameters = parameters or {}
    local newindex
    if parameters.read_only then
      newindex = newindex_readonly
    else
      newindex = newindex_writable
    end
    return setmetatable ({
      __tostring  = string,
      __eq        = eq,
      __len       = len,
      __index     = index,
      __newindex  = newindex,
      __call      = call_instance,
      __mode      = nil,
      [IS_PROXY]  = true,
    }, {
      __call      = call_metatable,
    })
  end
end

-- Extensible type
-- ---------------

-- Usage
-- -----
--
--       etype.my_type_name = function (x) ... end
--       
--       if etype (a_data).my_type_name then
--         ...
--       end

-- Implementation
-- --------------
local etype
do

  local compute = proxy { read_only = true  }
        etype   = proxy { read_only = false }

  local mt = getmetatable (etype)
  function mt:__call (x)
    ignore (self)
    local result = compute (x)
    for _, t in ipairs {
      "nil",
      "boolean",
      "number",
      "string",
      "function",
      "thread",
      "table",
    } do
      rawset (result, t, false)
    end
    rawset (result, type (x), true)
    return result
  end

  function mt:__newindex (key, value)
    rawset (self, key, value)
  end

  function compute:__index (key)
    local x = raw (self)
    local detector = etype [key]
    if detector then
      rawset (self, key, detector (x) or false)
    end
    return rawget (self, key) or false
  end

  -- The function uses the standard Lua `type` function internally, and
  -- overrides its result in the case of tables. In this case, it returns a
  -- table that maps each type name to the result of the corresponding
  -- detection function.

end

-- Iterators over Data
-- ===================
--
-- The Lua language provides two standard iterators on tables:
--
-- * `pairs` iterates over all key / value pairs of a table,
-- * `ipairs` iterates only over all key / value pairs where the keys are
--   a sequence of successive integers starting from `1`.
--
-- These two iterators cannot work on views, as they are prexies over data,
-- and thus empty tables.
--
-- We provide three iterator functions as replacement. They can be applied
-- on data and views. When applied on a view, the iterator retrieves the raw
-- data behind and iterates over it.
--
-- The three iterators are designed to iterate over tables as we would over
-- particular data structures:
--
-- * `map` for a map;
-- * `seq` for a list;
-- * `set` for a set.

-- This module makes only use of the `raw` function to retrieve a raw data
-- behind a view.

-- Iterator over Maps
-- ------------------
--
-- This iterator allows to retrieve the key / values pairs in a data. Thus,
-- it presents data as a map.
--
-- Its usage is:
--
--       for k, v in map (data) do ... end
--
local function map (data)
  if type (data) ~= "table" then
    return function () end
  end
  data = raw (data)
  local f = coroutine.wrap (
    function ()
      for k, v in pairs (data) do
        coroutine.yield (k, v)
      end
    end
  )
  return f
end

-- Iterator over Lists
-- --------------------
--
-- This iterator allows to retrieve the values associated to successive
-- integer keys in a data (starting from `1`). Thus, it presents data as
-- a list.
--
-- Its usage is:
--
--       for v in seq (data) do ... end
--
local function seq (data)
  if type (data) ~= "table" then
    return function () end
  end
  data = raw (data)
  local f = coroutine.wrap (
    function ()
      for _, v in ipairs (data) do
        coroutine.yield (v)
      end
    end
  )
  return f
end

-- Iterator over Sets
-- ------------------
--
-- This iterator allows to retrieve the keys associated to neither `nil` nor
-- `false` in a data. Thus, it presents data as a set.
--
-- Its usage is:
--
--       for k in set (data) do ... end
--
local function set (data)
  if type (data) ~= "table" then
    return function () end
  end
  data = raw (data)
  local f = coroutine.wrap (
    function ()
      for k, v in pairs (data) do
        if v then
          coroutine.yield (k)
        end
      end
    end
  )
  return f
end

-- Test for emptiness
-- ------------------
--
-- This function is not an iterator but can be useful when dealing with
-- collections.
--
-- Its usage is:
--
--      if [not] is_empty (data) then
--        ...
--      end

local function is_empty (data)
  if type (data) ~= "table" then
    return nil
  end
  data = raw (data)
  return pairs (data) (data) == nil
end


return {
  tags = tags,
  ignore = ignore,
  raw = raw,
  proxy = proxy,
  etype = etype,
  map = map,
  seq = seq,
  set = set,
  is_empty = is_empty,
}

