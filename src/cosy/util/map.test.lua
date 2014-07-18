-- Iterators on Maps
-- =================
--
-- All iterators should return nil when applied on a non table, as it
-- prevent iterating of these data.
--
local assert = require "luassert"
local map    = require "cosy.util.map"

do
  assert.is_true (map (nil) () == nil)
  for _, x in ipairs {
    true,
    0,
    "",
    function () end,
    coroutine.create (function () end),
  } do
    assert.is_true (map (x) () == nil)
  end
end

-- Behavior on tables
-- ------------------
--
-- In order to test the iterators, we build the following data. It has some
-- interesting characteristics:
--
-- * some keys are associated with the `false` value, and thus must not be
--   taken into account for the `set` iterator;
-- * some keys are numeric, starting from `1`, are thus used by `seq`,
-- * a numeric key is not following its `n-1` key, and thus is not taken
--   into account by `seq`.
local data = {
  [1] = "one",
  [2] = "two",
  [3] = false,
  [5] = true,
  a   = "three",
  b   = "four",
  z   = false,
}

do
  local keys = {}
  local values = {}
  for k, v in map (data) do
    keys [k] = true
    values [v] = true
  end
  assert.are.same (keys, {
    [1]   = true,
    [2]   = true,
    [3]   = true,
    [5]   = true,
    ["a"] = true,
    ["b"] = true,
    ["z"] = true,
  })
  assert.are.same (values, {
    ["one"  ] = true,
    ["two"  ] = true,
    ["three"] = true,
    ["four" ] = true,
    [false  ] = true,
    [true   ] = true,
  })
end
