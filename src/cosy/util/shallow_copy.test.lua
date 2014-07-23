-- Tests for Shallow Copy
-- ======================

local assert = require "luassert"

do
  -- For non tables, the copy just returns the data itself. We use the
  -- `non_tables` variable to iterate over such values for tests.
  local non_tables = {
    true,
    1,
    "",
    function () end,
    coroutine.create (function () end)
  }

  -- Only for Lua 5.2, that has `table.pack` and `table.unpack`.
  if table.pack and table.unpack then
    local clone = require "cosy.util.shallow_copy"
    -- The result is the input for everything but tables:
    do
      assert.are.equal (clone (nil), nil)
    end
    for _, x in ipairs (non_tables) do
      assert.are.equal (clone (x), x)
    end
    -- An empty table:
    do
      local t = {}
      local c = clone (t)
      assert.are_not.equal (c, t)
      assert.are.same (c, t)
    end
    -- A non-empty table:
    do
      local t = {
        "a", "b", "c"
      }
      local c = clone (t)
      assert.are_not.equal (c, t)
      assert.are.same (c, t)
    end
  end
end
