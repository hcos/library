-- Tests for Observed Objects
-- ==========================

-- These tests use `luassert` that exports various assertions.
local assert = require "luassert"

-- They also depend on the `observed` fields module, and the `tags`.
local observed = require "cosy.lang.view.observed"
local tags = require "cosy.lang.tags"

local ERRORS = tags.ERRORS

-- This callback works because it does not try to write a field within its
-- pre part.
--
local function good_handler (data, key)
  if key == "x" then
    -- Before:
    local old = data [key]
    coroutine.yield ()
    -- After:
    data.old_value = old
  end
end

-- This callback does not work because it tries to write the `old_value`
-- field within the pre part.
--
local function bad_handler (data, key)
  -- Before:
  data.old_value = data [key]
  coroutine.yield ()
  -- After:
end

-- With no handler:
do
  observed [1] = nil
  local data = {}
  data.x = 0
  local view = observed (data)
  view.x = 1
  assert.is_falsy (view.old_value)
end

-- With a working handler:
do
  observed [1] = good_handler
  local data = {}
  data.x = 0
  local view = observed (data)
  view.x = 1
  assert.are.equal (view.old_value, 0)
  assert.are.equal (view.x, data.x)
end

-- With an ill-defined handler:
do
  observed [1] = bad_handler
  local data = {}
  data.x = 0
  local view = observed (data)
  view.x = 1
  assert.are.equal (#(view [ERRORS]), 1)
end

-- The value written is stored as raw data instead of a view, if it was a
-- view.
do
  local value = {}
  local value_view = observed (value)
  local data = {}
  local view = observed (data)
  view.something = value_view
  assert.are.equal (data.something, value)
end
