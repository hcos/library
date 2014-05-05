-- Basic data manipulation
-- =======================
--
-- Data in CosyVerif mainly represents formalisms and models, with two
-- requirements:
--
-- * use a memory efficient representation, as big models are sometimes
--   encountered;
-- * provide a user friendly manipulation, as users are allowed to edit
--   models in a text editor instead of the graphical user interface.
--
-- In order to fulfill these two requirements, we split the data
-- representation from its manipulation: __raw data__ is stored as Lua
-- tables, and __views__ are provided on demand upon them for manipulation.
--
-- Data is also split in several notions:
--
-- * _components_ are the top level elements that store data;
-- * _data_ are the building blocks of components; each data belongs to only
--   one component;
-- * _tags_ are special keys used in components and data, used to identify
--   internal or tool specific data.

-- Implementation details
-- ----------------------
--
-- This module makes use of both the standard `type` function, and the
-- extensible one provided in `cosy.util.type`.
--
-- __Trick:__ the standard `type` function is saved and renamed `luatype`.
--
local luatype = type
local type = require "cosy.util.type"
local tags = require "cosy.lang.tags"

-- Three tags are used within this module: `RAW`, `OWNER` and `VIEW`.
-- Two of them (`RAW` and `VIEW`) are required by the view mechanism.
-- The third one (`OWNER`) is required by the component mechanism.
--
local RAW   = tags.RAW
local VIEW  = tags.VIEW
local OWNER = tags.OWNER

-- Access to raw data
-- ------------------
--
-- The `raw` function returns the raw data behind any data (already a raw
-- one or a view). It can be used as in the example code below, that
-- retrieves in `r` the raw data from data `x`:
--
--       local r = raw (x)
--
-- This function is usable on all Lua values. When its parameter is a
-- component or data, wrapped within a view, the raw component or data is
-- returned. Otherwise, the parameter is returned unchanged.
-- `raw` should thus be preferred to direct access using the `RAW` tag
-- when the parameter can be any Lua value, even not a table.
--
local function raw (x)
  if luatype (x) == "table" then
    return x [RAW] or x
  else
    return x
  end
end

-- Access to owner
-- ---------------
--
-- The `owner` function returns the owner of any data. It can be used as
-- in the example code below, that retrieves in `o` the owner of data `x`:
--
--       local o = owner (x)
--
-- This function is usable on all Lua values. When its parameter is a
-- component or data, its owner is returned. Otherwise, `nil` is returned.
-- `owner` should thus be preferred to direct access using the `OWNER` tag
-- when the parameter can be any Lua value, even not a table.
--
local function owner (x)
  if luatype (x) == "table" then
    return x [OWNER]
  else
    return nil
  end
end

-- Iteration over a component
-- --------------------------
--
-- A component is a rooted graph of data. The `walk` function allows to
-- iterate over the data reachable within and from a component. It behaves
-- as a Lua iterator, where each step returns a data. It can be used in a
-- `for` loop as in the example below:
--
--       for data in walk (c, { ... }) do
--         ...
--       end
--
-- __WARNING:__ Contrary to `pairs` and `ipairs`, the iteration returns only
-- one value (the data) instead of a key and a value.
--
-- `walk` takes two arguments:
--
-- * `data` is the component to iterate over, that is mandatory;
-- * `args` is an optional table containing iteration parameters.
--
-- The iteration parameters are:
--
-- * `visit_once`: when set, each data is only returned once in the
--   iteration, even if it can be accessed through two paths in the
--   component;
-- * `in_component`: when set, only data within the components are returned,
--   while all reachable data, even in other components, are returned
--   otherwise.
--
local function walk (data, args)
  local config = {
    visit_once  = true,
    in_component = true,
  }
  if args and luatype (args) == "table" then
    if args.visit_once == false then
      config.visit_once = false
    end
    if args.in_component == false then
      config.in_component = false
    end
  end

  local function iterate (data, view, visited)
    local data_view = data
    for _, f in ipairs (view) do
      data_view = f (data_view)
    end
    coroutine.yield (data_view)
    if not visited [data] then
      visited [data] = true
      for k, v in pairs (data) do
        if not type (k).tag and type (v).table
        and not (config.visit_once and visited [v])
        and not (config.in_component and owner (v) ~= owner (data)) then
          iterate (v, view, visited)
        end
      end
      visited [data] = config.visit_once or nil
    end
  end

  assert (type (data).component)
  local view = data [VIEW] or {}
  local data = raw (data)
  return coroutine.wrap (function () iterate (data, view, {}) end)
end


-- Extensible `type` function
-- --------------------------
--
-- We extend the `type` function with the different notions found in
-- CosyVerif:
--
-- * `"tag"` is the type returned for all tags;
-- * `"data"` is the type returned for all data except components and tags;
-- * `"component"` is the type returned for all components (that is for the
--   data at the root of a component);
-- * `"table"` is still returned for every table that does not meet one of
--   the above constraints.

-- A tag is a data, the owner of which is `tags`.
type.tag = function (data)
  return owner (data) == tags
end

-- A component is a data, the owner of which is itself.
type.component = function (data)
  return owner (data) == raw (data)
end

-- A data is any data with an owner, that is both not a tag and not a
-- component.
type.data = function (data)
  local o = owner (data)
  return o
     and o ~= raw (data)
     and o ~= tags
end

-- Every other table is considered as a raw table.

-- Module
-- ------
--
-- This module exports three functions:
--
-- * `raw` and `owner` that allow to access respectively the raw data behind
--   and the owner of any data;
-- * `walk` that allows to iterate over the data of a component.
--
return {
  raw   = raw,
  owner = owner,
  walk  = walk,
}
