-- Test of emptiness
-- =================
--
-- All iterators should return nil when applied on a non table, as it
-- prevent iterating of these data.
--
local assert   = require "luassert"
local is_empty = require "cosy.util.is_empty"

do
  assert.is_true (is_empty (nil) == nil)
  for _, x in ipairs {
    true,
    0,
    "",
    function () end,
    coroutine.create (function () end),
  } do
    assert.is_true (is_empty (x) == nil)
  end
end

do
  local data = {
    [1] = "one",
    [2] = "two",
    [3] = false,
    [5] = true,
    a   = "three",
    b   = "four",
    z   = false,
  }
  assert.is_true  (is_empty {})
  assert.is_false (is_empty { "some key"})
  assert.is_false (is_empty (data))
end
