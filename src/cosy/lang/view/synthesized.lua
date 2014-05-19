-- Synthesized Fields
-- ==================
--
-- Some data fields are not set by the users or tools, but are computed
-- from other fields. This view allows to set computation functions for
-- such synthesized fields, and to call them transparently when they are
-- accessed.

-- Design
-- ------
--
-- Synthesized fields are stored in raw data, but are computed
-- automatically when accessed through the `synthesized` view. This view
-- acts as both a repository for computation functions, and as a view
-- constructor.

-- Usage
-- -----
--
--       local synthesized = require "cosy.lang.view.synthesized"
--       synthesized.a_tag = function (data)
--         data.a_tag = ...
--       end
--       local data = ...
--       local view = synthesized (data)
--       local _ = view.some_key
--       local _ = view.a_tag

-- Implementation
-- --------------

-- This module makes use of the following tags and functions.
local tags  = require "cosy.lang.tags"
local raw   = require "cosy.lang.data" . raw
local view  = require "cosy.lang.data" . view
local error = require "cosy.lang.message" . error

-- Required Tags
-- -------------
--
-- The `DATA` tag refers to the data above which a view is built.
local DATA  = tags.DATA
-- The `VIEWS` tag stores in a view the sequence of views that wrap a raw
-- data. This sequence can then be used to rebuild a similar view on any
-- data.
local VIEWS = tags.VIEWS

-- Metatables
-- ----------
--
-- The `synthesized` object has a metatable to allow begin called like a
-- function, for the construction of a view from a data or view.
local synthesized = require "cosy.lang.view.make" ()

-- Read a field
-- ------------
--
-- A field is accessed from a view in the standard Lua way, by using the
-- dotted (`data.field`) or square brackets (`data [tag]`) notations. The
-- view simply computes a synthesized field, and stores it in the data for
-- future uses.
--
-- TODO
function synthesized:__index (key)
  local data = self [DATA]
  if not data [key] and synthesized [key] then
    synthesized [key] (raw (data))
  end
  return view (data [key], self [VIEWS])
end

-- Write a field
-- -------------
--
-- A field is written using a view in the standard Lua way,  by using the
-- dotted (`data.field`) or square brackets (`data [tag]`) notations. The
-- view checks that the written field is not a synthesized one. In such a
-- case, write is forbidden, as it could interfere with other computed
-- fields.
--
function synthesized:__newindex (key, value)
  local data = self [DATA]
  if synthesized [key] then
    error (data,
      "Trying to insert " .. tostring (key) ..
      ", but it is marked as synthesized."
    )
  else
    data [key] = value
  end
end

-- The module only exports the `synthesized` object.
return synthesized
