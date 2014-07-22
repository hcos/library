-- `etype`
-- =======
--
local assert = require "luassert"
local etype  = require "cosy.util.etype"

do

  -- Declare an object named `"object"` in extensible `type`. Its type is
  -- triggered by the presence of a `is_object` field within.
  --
  etype.object = function (x)
    return type (x) == "table" and x.is_object
  end

  -- ### Compare `type` and `etype` for non objects
  --
  -- For non objects, the Lua `type` and the extensible `type` functions
  -- return exactly the same string:
  --
  local a_table = {}
  local cases = {
    true,
    1,
    "",
    a_table,
    function () end,
    coroutine.create (function () end),
  }
  assert.is_true(
    etype (nil) [type (nil)]
  )
  for _, c in pairs (cases) do
    assert.is_truthy (
      etype (c) [type (c)]
    )
    assert.is_falsy (
      etype (c) . something
    )
    assert.is_falsy (
      etype (c) . object
    )
  end

  -- ### Compare `type` and `etype` for objects

  -- A table without the `is_object` field is not recognized as an `"object"`:
  assert.is_falsy (
    etype {} . object
  )

  -- A table with the `is_object` field is recognized as an `"object"`:
  assert.is_truthy (
    etype { is_object = true } . object
  )
end
