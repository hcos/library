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
--
local raw  = require "cosy.lang.data" . raw

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

-- Module
-- ------
--
-- The module exports these three iterator functions.
--
return {
  map = map,
  seq = seq,
  set = set,
  is_empty = is_empty,
}
