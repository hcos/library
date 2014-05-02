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
assert.are.equal ("nil", type (nil), itype (nil))
-- * for `boolean`:
assert.are.equal (type (true), itype (true))
-- * for `number`:
assert.are.equal (type (1   ), itype (1   ))
-- * for `string`:
assert.are.equal (type (""  ), itype (""  ))
-- * for `table`:
assert.are.equal (type ({}  ), itype ({}  ))
-- * for `function`:
assert.are.equal (
  type (function () end),
  itype (function () end)
)
-- * for `thread`:
assert.are.equal (
  type (coroutine.create (function () end)),
  type (coroutine.create (function () end))
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
assert.are.equal (itype {}, "table")

-- A table with the `is_object` field is recognized as an `"object"`:
assert.are.equal (itype { is_object = true }, "object")
