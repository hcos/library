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

local a_table = {}
local cases = {
  true,
  1,
  "",
  a_table,
  function () end,
  coroutine.create (function () end),
}

assert.is_true (
  itype (nil) [type (nil)]
)
for _, c in pairs (cases) do
  assert.is_true (
    itype (c) [type (c)]
  )
  assert.is_false (
    itype (c) . something
  )
end

-- Compare `type` and `itype` for objects
-- --------------------------------------

-- Declare an object named `"object"` in extensible `type`. Its type is
-- triggered by the presence of a `is_object` field within.
--
itype.object = function (x)
  return x.is_object ~= nil
end

-- A table without the `is_object` field is not recognized as an `"object"`:
assert.is_false (
  itype {} . object
)

-- A table with the `is_object` field is recognized as an `"object"`:
assert.is_true (
  itype { is_object = true } . object
)
