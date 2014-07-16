-- Tests for `cosy.util`
-- =====================

local util   = require "cosy.util"
local assert = require "luassert"

-- `ignore` function
-- --------------
--
do
  local ignore = util.ignore
  local function f (a, b, c)
    ignore (a, b, c)
  end
  assert.has.no.error (f)
end

-- `proxy` object
-- --------------
--
do
  local proxy = util.proxy
  local DATA  = util.DATA
  local NIL = {}
  for _, value in ipairs {
    NIL,
    true,
    0,
    "",
    function () end,
    coroutine.create (function () end),
    {},
  } do
    if value == NIL then
      value = nil
    end
    local p = proxy ()
    assert.has.no.error (function () p (value) end)
    local o = p (value)
    assert.are.equal (rawget (o, DATA), value)
    assert.are.equal (tostring (o), tostring (value))
    local ok, size = pcall (function () return # value end)
    if ok then
      assert.has.no.error (function () return # o end)
      assert.are.equal (# o , size)
    end
    if type (value) == "string" then
      assert.has.no.error (function () return o [1] end)
      assert.has.error (function () o [1] = true end)
    elseif type (value) == "table" then
      assert.has.no.error (function () return o [1] end)
      assert.has.no.error (function () o [1] = true end)
    else
      assert.has.error (function () return o [1] end)
      assert.has.error (function () o [1] = true end)
    end
    local p1 = proxy ()
    local p2 = proxy ()
    local r = p1 (p2 (value))
    assert.are.equal (getmetatable (r), p1)
    assert.are.equal (getmetatable (rawget (r, DATA)), p2)
    assert.are.equal (rawget (rawget (r, DATA), DATA), value)
    assert.are.equal (r, o)
    assert.are.equal (o, r)
    local s = r (nil)
    assert.are.equal (getmetatable (s), p1)
    assert.are.equal (getmetatable (rawget (s, DATA)), p2)
    assert.are.equal (rawget (rawget (s, DATA), DATA), value)
  end
  do
    local value = {}
    local p = proxy { read_only = true}
    local o = p (value)
    assert.has.error (function () o [1] = true end)
  end
  do
    local value = {}
    local p = proxy { read_only = false }
    local o = p (value)
    assert.has.no.error (function () o [1] = true end)
    assert.are.same (value, { true })
  end
end

-- `raw` function
-- --------------
--
do
  local raw  = util.raw
  local proxy = util.proxy
  -- When applied on non table values, the `raw` function returns the value
  -- unchanged:
  for _, value in ipairs {
    NIL,
    true,
    0,
    "",
    function () end,
    coroutine.create (function () end),
    {},
  } do
    if value == NIL then
      value = nil
    end
    assert.are.equal (raw (value), value)
    local p = proxy ()
    assert.are.equal (raw (p (value)), value)
    local q = proxy ()
    assert.are.equal (raw (p (q (value))), value)
  end
end

-- `etype` object
-- --------------
--
do
  local etype = util.etype

  -- Declare an object named `"object"` in extensible `type`. Its type is
  -- triggered by the presence of a `is_object` field within.
  --
  etype.object = function (x)
    return type (x) == "table" and x.is_object ~= nil
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

-- Iterators on non tables
-- -----------------------
--
-- All iterators should return nil when applied on a non table, as it
-- prevent iterating of these data.
--
do
  for _, f in pairs { util.map, util.seq, util.set } do
    assert.is_true (f (nil) () == nil)
  end
  assert.is_true (util.is_empty (nil) == nil)
  for _, x in ipairs {
    true,
    0,
    "",
    function () end,
    coroutine.create (function () end),
  } do
    for _, f in pairs { util.map, util.seq, util.set } do
      assert.is_true (f (x) () == nil)
    end
    assert.is_true (util.is_empty (x) == nil)
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

-- ### `is_empty`

do
  assert.is_true  (util.is_empty {})
  assert.is_false (util.is_empty { "some key"})
  assert.is_false (util.is_empty (data))
end

-- ### `map` Iterator
--
-- The `map` iterator lists all the key / value pairs in a table or view.
--
do
  local map = util.map
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
  local seq = util.seq
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
  local set = util.set
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
