-- Test of size
-- =================
--
local assert = require "luassert"
local size   = require "cosy.util.size"

do
  assert.is_true (size (nil) == nil)
  for _, x in ipairs {
    true,
    0,
    "",
    function () end,
    coroutine.create (function () end),
  } do
    assert.is_true (size (x) == nil)
  end
end

do
  local data = {
    [1] = "one",
    [2] = "two",
    a   = "three",
    b   = "four",
  }
  assert.are.equal (size (data), 4)
end
