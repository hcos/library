-- Observed Objects
-- ================
--
-- Sometimes, there is a need to observe changes on data, and call a handler
-- to perform some actions on updates. The `observed` view is a way to
-- perform such tasks.
--
-- An observer is not bound to a particular data, as it would be very costly
-- in memory. Instead, observers register callbacks in the `observed`
-- object. These callbacks are all called every time an update is performed
-- on a data wrapped by the `observed` view.
--
-- The callbacks are not just plain functions. They are functions that will
-- be used as coroutines and called in two steps:
--
-- * the initial call is performed __before__ the data update; it allows for
--   instance to save the old value;
-- * the function is resumed __after__ the data update; and can then change
--   some other data.
--
-- __Warning:__ the part __before__ is only allowed to read data, not to
-- write to it!
--

-- Usage
-- -----
--
-- A callback is registered as below:
--
--       local observed = require "cosy.lang.view.observed"
--       observed.my_observer = function (data, key)
--          -- pre:
--          ...
--          coroutine.ield ()
--          -- post:
--          ...
--       end
--
-- Note that insertion of the observer can also be done as:
--
--       observed [#observed + 1] = function (data, key)
--         ...
--       end
--
-- Note that the callback should usually check for the tags it observes, as
-- in the code below:
--
--       observed.my_observer = function (data, key)
--         if key == "mykey" then
--           -- pre:
--           ...
--           coroutine.ield ()
--           -- post:
--           ...
--         end
--       end


-- Dependencies
-- ------------
--
-- The module depends on `tags`, `view` and `error`.
--
local tags  = require "cosy.lang.tags"
local raw   = require "cosy.lang.data" . raw
local view  = require "cosy.lang.data" . view
local error = require "cosy.lang.message" . error

-- The `DATA` tag refers to the data above which a view is built.
--
local DATA  = tags.DATA

-- The `VIEWS` tag stores in a view the sequence of views that wrap a raw
-- data. This sequence can then be used to rebuild a similar view on any
-- data.
--
local VIEWS = tags.VIEWS

-- Constructor
-- -----------
--
-- The `observed` object acts as a view constructor over data:
--
--        local view = observed (data)
--
local observed = require "cosy.lang.view.make" ()

-- Read a field
-- ------------
--
-- A field is accessed from a view in the standard Lua way, by using the
-- dotted (`data.field`) or square brackets (`data [tag]`) notations.
-- This view just forwards the `__index` to the underlying view, or to the
-- raw data.
--
function observed:__index (key)
  return view (self [DATA] [raw (key)], self [VIEWS])
end

-- Write a field
-- -------------
--
-- A field is written using a view in the standard Lua way,  by using the
-- dotted (`data.field`) or square brackets (`data [tag]`) notations.
--
-- We provide two `__newindex` implementations: one allows writes, the other
-- one does not. Writes are disabled within the read part of the handler
-- coroutines.
--
local function nonwritable_newindex (self, key, _)
  error (self,
    "Trying to update " .. tostring (key) ..
    " within the 'pre' part of an observer."
  )
end

local function writable_newindex (self, key, value)
  key = raw (key)
  value = raw (value)
  local data = self [DATA]
  local running = {}
  observed.__newindex = nonwritable_newindex
  for handler, f in pairs (observed) do
    if type (handler) ~= "string" or handler:find ("__") ~= 1 then
      local c = coroutine.create (function() f (self, key) end)
      running [handler] = c
      local ok, err = coroutine.resume (c)
      if not ok then
--        print (err)
      end
    end
  end
  data [key] = value
  observed.__newindex = writable_newindex
  for handler, c in pairs (running) do
    local ok, err = coroutine.resume (c)
    if not ok then
--      print (err)
    end
    running [handler] = nil
  end
end

-- Outside a handler, an observed view is writeable.
--
observed.__newindex = writable_newindex

-- Length
-- ------
--
-- The length operator is simply forwarded to the underlying data or view.
--
function observed:__len ()
  return # (self [DATA])
end


-- Module
-- ------
--
-- This module simply returns the `observed` object.
--
return observed
