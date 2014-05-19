-- Tests for View Constructor
-- ==========================

-- These tests use `luassert` that exports various assertions.
local assert = require "luassert"

local make = require "cosy.lang.view.make"
local tags = require "cosy.lang.tags"

local DATA   = tags.DATA
local VIEWS  = tags.VIEWS

-- Constructor creation
-- --------------------
--
assert.has.no.error (function () make () end)

-- Building a view
-- ---------------
--
do
  local data = {}
  local view = make ()
  local x = view (data)
  assert.are.equal (x [DATA], data)
end

-- Views
-- -----
--
-- Synthesized views are stackable.
do
  local data = {}
  local view = make ()
  local x = view (view (data))
  assert.are.same (
    x [VIEWS],
    { view, view }
  )
end
