-- Utilities
-- =========

-- This module defines some utility functions, that are used in
-- CosyVerif.

-- Source Code Helpers
-- ===================



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

return {
  tags          = require "cosy.util.tags",
  ignore        = require "cosy.util.ignore",
  raw           = require "cosy.util.raw",
  proxy         = require "cosy.util.proxy",
  etype         = require "cosy.util.etype",
  map           = require "cosy.util.map",
  seq           = require "cosy.util.seq",
  set           = require "cosy.util.set",
  is_empty      = require "cosy.util.is_empty",
  shallow_copy  = require "cosy.util.shallow_copy",
}

