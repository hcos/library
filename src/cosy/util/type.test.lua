-- Tests of Extensible `type` function
-- ===================================

-- These tests use `luassert` that exports various assertions.
local assert = require "luassert"
-- The extended `type` function is named `itype`, because tests also make
-- use of the standard Lua `type` function.
local itype  = require "cosy.util.type"


-- Compare `type` and `itype` for non objects
-- ------------------------------------------
-- 
-- For non objects, the Lua `type` and the extensible `type` functions
-- return exactly the same string:
--
-- * for `nil`:
assert.are.same (
  itype (nil),
  { [type (nil)] = true }
)
-- * for `boolean`:
assert.are.same (
  itype (true),
  { [type (true)] = true }
)
-- * for `number`:
assert.are.same (
  itype (1),
  { [type (1)] = true }
)
-- * for `string`:
assert.are.same (
  itype (""),
  { [type ("")] = true }
)
-- * for `table`:
assert.are.same (
  itype ({}),
  { [type ({})] = true }
)
-- * for `function`:
assert.are.same (
  itype (function () end),
  { [type (function () end)] = true }
)
-- * for `thread`:
assert.are.same (
  itype (coroutine.create (function () end)),
  { [type (coroutine.create (function () end))] = true }
)


-- Compare `type` and `itype` for objects
-- --------------------------------------

-- Declare an object named `"object"` in extensible `type`. Its type is
-- triggered by the presence of a `is_object` field within.
--
itype.object = function (x)
  return x.is_object ~= nil
end

-- A table without the `is_object` field is not recognized as an `"object"`:
--
assert.are.same (
  itype {},
  { table = true }
)

-- A table with the `is_object` field is recognized as an `"object"`:
assert.are.same (
  itype { is_object = true },
  { table = true, object = true }
)
