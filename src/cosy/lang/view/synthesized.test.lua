-- Tests for Synthesized Fields
-- ============================

-- These tests use `luassert` that exports various assertions.
local assert = require "luassert"

-- They also depend on the `synthesized` fields module, and the `tags`.
local synthesized = require "cosy.lang.view.synthesized"
local tags = require "cosy.lang.tags"

local VIEWS  = tags.VIEWS
local ERRORS = tags.ERRORS

-- For the tests, we define a tag (`TAG`) and a handler that computes a
-- value for this tag in the view.
local TAG  = tags.TAG
local function handler (data)
  data [TAG] = 0
end

-- Register handler
-- ----------------
--
-- The handler is then registered in the `synthesized` view.
assert.has.no.error (function () synthesized [TAG] = handler end)

-- Access to the synthesized field
-- -------------------------------
--
-- In the raw data, the field value is initially not set. After accessing
-- the field through the view, its value is set both in the view and in the
-- raw data.
do
  local data = {}
  assert.is_true (data [TAG] == nil)
  local view = synthesized (data)
  assert.are.equal (view [TAG], 0)
  assert.are.equal (data [TAG], 0)
end

-- A non synthesized field is writeable. A synthesized field generates an
-- error when it is written through the view (not in its handler, of
-- course).
do
  local data = {}
  local view = synthesized (data)
  assert.has.no.error (function ()
    view.something = 1
  end)
  assert.are.equal (view.something, 1)
  view [TAG] = 0
  assert.are.equal (# (data [ERRORS]), 1)
end

-- Views
-- -----
--
-- Synthesized views are stackable.
do
  local data = {}
  local view = synthesized (synthesized (data))
  assert.are.same (
    view [VIEWS],
    { synthesized, synthesized }
  )
  assert.are.equal (view [TAG], 0)
end
