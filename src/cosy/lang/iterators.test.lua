-- Tests of Iterators over Data
-- ============================

-- These tests use `luassert` that exports various assertions.
local assert = require "luassert"
local iterators = require "cosy.lang.iterators"

-- Behavior on non tables
-- ----------------------
--
-- All iterators should return nil when applied on a non table, as it
-- prevent iterating of these data.
--
do
  for _, f in pairs (iterators) do
    assert.is_true (f (nil) () == nil)
  end
  for _, x in ipairs {
    true,
    0,
    "",
    function () end,
    coroutine.create (function () end),
  } do
    for _, f in pairs (iterators) do
      assert.is_true (f (x) () == nil)
    end
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

-- ### `map` Iterator
--
-- The `map` iterator lists all the key / value pairs in a table or view.
--
do
  local map = iterators.map
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

-- ### `seq` Iterator
--
-- The `seq` iterator lists all the values that are obtained by iterating
-- sequentially over keys starting from 1.
--
do
  local seq = iterators.seq
  local values = {}
  for v in seq (data) do
    values [v] = true
  end
  assert.are.same (values, {
    ["one"] = true,
    ["two"] = true,
    [false] = true,
  })
end

-- ### `set` Iterator
--
-- The `set` iterator lists all the keys in a table or view that are
-- associated neither to `false` no `nil`.
--
do
  local set = iterators.set
  local keys = {}
  for k in set (data) do
    keys [k] = true
  end
  assert.are.same (keys, {
    [1  ] = true,
    [2  ] = true,
    [5  ] = true,
    ["a"] = true,
    ["b"] = true,
  })
end
