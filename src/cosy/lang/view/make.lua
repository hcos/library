-- View Constructor
-- ================
--
-- This module is a function to create view handlers. A view handler is an
-- object that defines the `__index` and `__newindex` methods to override
-- standard access to data.
--
-- A view is created over a raw data or another view, by calling a view
-- handler. The view can then be manipulated like any data. The extensible
-- `type` function (`cosy.util.type`) should even detect it as a data /
-- component / ...
--
-- See `cosy.lang.view.synthesized` for an example.

-- This module makes use of the following tags:.
local tags  = require "cosy.lang.tags"
local DATA  = tags.DATA
local VIEWS = tags.VIEWS

-- Usage
-- -----
--
--        local my_view_handler = require "cosy.lang.view.make" ()
--        function my_view_handler:__index (key) ... end
--        function my_view_handler:__newindex (key, value) ... end
--        local my_data = { ... }
--        local my_data_view = my_view_handler (my_data)
--
-- It uses internally a `clone` function to copy and extend the `VIEWS` of
-- the underlying data or view.
--
local clone = require "cosy.util.shallow_copy"

-- A view is a proxy above a raw data or another view. Its constructor
-- has to set two tags:
--
-- * `DATA` that stores the underlying raw data or view, if views are
--   stacked;
-- * `VIEWS` that stores a sequence of view constructors, used to build
--   similar views for other data accessed through any field.
--
local function constructor (self, data)
  local views = clone (data [VIEWS] or {})
  views [#views + 1] = self
  local result = {}
  result [DATA ] = data
  result [VIEWS] = views
  return setmetatable (result, self)
end

-- This module returns a nullary function to create a new view handler. The
-- two methods `__index` and `__newindex` must be filled on its result in
-- order to create a valid view handler.
--
local function make ()
  local mt = {}
  local result   = setmetatable ({}, mt)
  mt.__call      = constructor
  mt.__index     = mt
  return result
end

return make
