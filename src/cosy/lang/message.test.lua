-- Tests of Message Handler
-- ========================

-- These tests use `luassert` that exports various assertions.
local assert = require "luassert"

-- The `message` handler is imported, with its three functions:
--
-- * `error` to signal errors,
-- * `warning` to signal warnings, and
-- * `generate` to generate new type of messages.
local message = require "cosy.lang.message"

-- We also use `tags` to identify specific tags:
local tags = require "cosy.lang.tags"
local ERRORS   = tags.ERRORS
local WARNINGS = tags.WARNINGS

-- `error` function
-- ----------------

do
  -- Initially, a data does not have an `ERRORS` field:
  local data = {}
  assert.is_true (
    data [ERRORS] == nil
  )
  -- `error` adds a sequence of messages associated to tag `ERRORS` in a data.
  message.error (data, "error 1")
  assert.are.same (
    data [ERRORS],
    { "error 1" }
  )
  message.error (data, "error 2")
  assert.are.same (
    data [ERRORS],
    { "error 1", "error 2" }
  )
end

-- `warning` function
-- ------------------

do
  -- Initially, a data does not have a `WARNINGS` field:
  local data = {}
  assert.is_true (
    data [WARNINGS] == nil
  )
  -- `warning` adds a sequence of messages associated to tag `WARNINGS` in a
  -- data.
  message.warning (data, "warning 1")
  assert.are.same (
    data [WARNINGS],
    { "warning 1" }
  )
  message.warning (data, "warning 2")
  assert.are.same (
    data [WARNINGS],
    { "warning 1", "warning 2" }
  )
end

-- `custom` function
-- -------------------

do
  local MY_TAG = tags.MY_TAG
  local my_handler = message.custom (MY_TAG)

  -- Initially, a data does not have a `MY_TAG` field:
  local data = {}
  assert.is_true (
    data [MY_TAG] == nil
  )
  -- `my_handler` adds a sequence of messages associated to tag `MY_TAG` in
  -- a data.
  my_handler (data, "1")
  assert.are.same (
    data [MY_TAG],
    { "1" }
  )
  my_handler (data, "2")
  assert.are.same (
    data [MY_TAG],
    { "1", "2" }
  )
end
