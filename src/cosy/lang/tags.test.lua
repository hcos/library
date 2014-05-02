-- Tests of Tags repository
-- ========================

-- These tests use `luassert` that exports various assertions.
local assert = require "luassert"
-- The `tags` repository is imported:
local tags   = require "cosy.lang.tags"

-- A tag is returned on demand:
assert.are.equal (type (tags.TAG), "table")

-- A tag is printed by enclosing its name with square brackets:
assert.are.equal (tostring(tags.TAG), "[TAG]")

-- The same tag is returned each time it accessed:
assert.are.equal (tags.TAG, tags.TAG)

-- Tags are unique:
assert.are_not.equal (tags.TAG, tags.OTHER_TAG)
