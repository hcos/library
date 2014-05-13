-- Tests for Basic data manipulation
-- =================================

-- These tests use `luassert` that exports various assertions.
local assert = require "luassert"
-- Testing data requires also `tags` as tests need to access some internal
-- data tags, such as `OWNER`.
local data   = require "cosy.lang.data"
local tags   = require "cosy.lang.tags"



-- `owner` function
-- ----------------
--
local owner = data.owner

-- When applied on data, he `owner` function returns the `OWNER`:
local OWNER = tags.OWNER
local component = {}
component [OWNER] = component
assert.are.equal (owner (component), component)

-- When applied on tables with no `OWNER`, the `owner` function returns
-- `nil`:
assert.are.equal (owner ({}  ), nil)

-- When applied on non table values, the `owner` function returns `nil`:
assert.are.equal (owner (true), nil)
assert.are.equal (owner (0), nil)
assert.are.equal (owner (""), nil)
assert.are.equal (owner (function () end), nil)
assert.are.equal (owner (coroutine.create (function () end)), nil)



-- `raw` function
-- --------------
--
do
  local raw   = data.raw

  -- When applied on a table, he `raw` function returns the raw data behind
  -- any data:
  local DATA = tags.DATA
  local a_data = {}
  assert.are.equal (raw (a_data), a_data)
  local raw_data = {}
  a_data [DATA] = raw_data
  assert.are.equal (raw (a_data), raw_data)

  -- When applied on non table values, the `raw` function returns the value
  -- unchanged:
  assert.are.equal (raw (true), true)
  assert.are.equal (raw (0), 0)
  assert.are.equal (raw (""), "")
  local f = function () end
  assert.are.equal (raw (f), f)
  local c = coroutine.create (f)
  assert.are.equal (raw (c), c)
end



-- `view` function
-- --------------

do
  local view  = data.view
  local DATA = tags.DATA
  local T = tags.T

  local v1 = function (data)
    return {
      [T   ] = "v1",
      [DATA] = data,
    }
  end
  local v2 = function (data)
    return {
      [T   ] = "v2",
      [DATA] = data,
    }
  end

  local a_data = {}
  -- An empty view returns the data itself:
  assert.are.equal (view (a_data, {}), a_data)
  -- Views are stacked over the data:
  assert.are.equal (view (a_data, { v1 }) [DATA], a_data)
  assert.are.equal (view (a_data, { v1 }) [T], "v1")
  assert.are.equal (view (a_data, { v1, v2 }) [T], "v2")
  assert.are.equal (view (a_data, { v2, v1 }) [T], "v1")

  -- When applied on non table values, the `view` function returns the value
  -- unchanged:
  for _, v in pairs { nil, {v1, v2} } do
    assert.are.equal (view (true, v), true)
    assert.are.equal (view (0, v), 0)
    assert.are.equal (view ("", v), "")
    local f = function () end
    assert.are.equal (view (f, v), f)
    local c = coroutine.create (f)
    assert.are.equal (view (c, v), c)
  end
end



-- `walk` function
-- ---------------
--
local walk  = data.walk

-- Tests of the `walk` function are based of a shared data, that exhibits
-- all interesting cases. It is a graph with two components, cycles, and
-- references between components and inside components.
--
local component_1 = {
  a = {},
  circular = nil,
  internal = nil,
  external = nil,
}

local component_2 = {
  x = {},
  y = {},
}

-- Set the relations:
component_1.circular = component_1
component_1.internal = component_1.a
component_1.external = component_2.x

-- Set the `OWNER`:
component_1   [OWNER] = component_1
component_1.a [OWNER] = component_1

component_2   [OWNER] = component_2
component_2.x [OWNER] = component_2
component_2.y [OWNER] = component_2

-- `walk` only works on components:
  walk (component_1)
  walk (component_2)
assert.has.no.errors (function ()
  walk (component_1)
  walk (component_2)
end)
assert.has.errors (function ()
  walk (component_1.a)
end)
assert.has.errors (function ()
  walk (component_2.x)
end)

-- `walk` has two parameters:
--
-- * `visit_once`, that only shows each data once, even if it is reachable
--   through several paths;
-- * `in_component`, that does not show data outside the component.

-- With `visit_once = true` and `in_component = true` (the defaults),
--
-- * `component_1` is seen once ;
-- * `component_1.a` is also seen once;
-- * no data in `component_2` is ever seen.
do
  local seen = {}
  for d in walk (component_1) do
    assert.are.equal (seen [d], nil)
    seen [d] = 1
  end
  assert.are.equal (seen [component_1  ], 1)
  assert.are.equal (seen [component_1.a], 1)
  assert.are.equal (seen [component_2  ], nil)
  assert.are.equal (seen [component_2.x], nil)
  assert.are.equal (seen [component_2.y], nil)
end

-- With `visit_once = true` and `in_component = false`,
--
-- * `component_1` is seen once ;
-- * `component_1.a` is also seen once;
-- * `component_2.x` is also soon once, reached from `component_1.external`;
-- * other data in `component_2` are ever seen.
do
  local seen = {}
  for d in walk (component_1, { in_component = false }) do
    assert.are.equal (seen [d], nil)
    seen [d] = 1
  end
  assert.are.equal (seen [component_1  ], 1)
  assert.are.equal (seen [component_1.a], 1)
  assert.are.equal (seen [component_2  ], nil)
  assert.are.equal (seen [component_2.x], 1)
  assert.are.equal (seen [component_2.y], nil)
end

-- With `visit_once = false` and `in_component = true`,
--
-- * `component_1` is seen twice (reached as root and as
--   `component_1.circular`);
-- * `component_1.a` is also seen twice (reached as `component_1.a` and
--   `component_1.internal`);
-- * no data in `component_2` is ever seen.
do
  local seen = {}
  for d in walk (component_1, { visit_once = false }) do
    if seen [d] then
      seen [d] = seen [d] + 1
    else
      seen [d] = 1
    end
  end
  assert.are.equal (seen [component_1  ], 2)
  assert.are.equal (seen [component_1.a], 2)
  assert.are.equal (seen [component_2  ], nil)
  assert.are.equal (seen [component_2.x], nil)
  assert.are.equal (seen [component_2.y], nil)
end

-- With `visit_once = false` and `in_component = false`,
--
-- * `component_1` is seen twice (reached as root and as
--   `component_1.circular`);
-- * `component_1.a` is also seen twice (reached as `component_1.a` and
--   `component_1.internal`);
-- * `component_2.x` is also soon once, reached from `component_1.external`;
-- * other data in `component_2` are ever seen.
do
  local seen = {}
  for d in walk (component_1, { visit_once = false, in_component = false }) do
    if seen [d] then
      seen [d] = seen [d] + 1
    else
      seen [d] = 1
    end
  end
  assert.are.equal (seen [component_1  ], 2)
  assert.are.equal (seen [component_1.a], 2)
  assert.are.equal (seen [component_2  ], nil)
  assert.are.equal (seen [component_2.x], 1)
  assert.are.equal (seen [component_2.y], nil)
end

-- `walk` with a view
-- ------------------
--
-- A view is a table with a `DATA` tag referring to the underlying data.
-- The `walk` function should expose to the iteration a view of the data
-- similar to the view of the data passed to `walk`.
do
  local raw = data.raw
  local DATA  = tags.DATA
  local VIEWS = tags.VIEWS
  local function view (d)
    return setmetatable ({
      [VIEWS] = { view },
      [DATA ] = d,
    }, {
      __index = d
    })
  end
  for d in walk (view (component_1)) do
    assert.are.equal (d [DATA], raw (d))
  end
end



-- Types
-- -----
--
-- The exntensible type function must return correct results for components,
-- data, tags, sequences and non sequences.
--
local type = require "cosy.util.type"

do
  local data = {}
  assert.is_false (type (data) . tag)
  assert.is_false (type (data) . component)
  assert.is_false (type (data) . data)
  assert.is_true  (type (data) . sequence)
end
do
  local data = {}
  data [OWNER] = data
  assert.is_false (type (data) . tag)
  assert.is_true  (type (data) . component)
  assert.is_true  (type (data) . data)
  assert.is_true  (type (data) . sequence)
end
do
  local data = tags.A_TAG
  assert.is_true  (type (data) . tag)
  assert.is_false (type (data) . component)
  assert.is_true  (type (data) . data)
  assert.is_true  (type (data) . sequence)
end
do
  local o = {}
  o [OWNER] = o
  local data = {}
  data [OWNER] = o
  assert.is_false (type (data) . tag)
  assert.is_false (type (data) . component)
  assert.is_true  (type (data) . data)
  assert.is_true  (type (data) . sequence)
end
do
  local data = {
    {}, {}, {}
  }
  assert.is_false (type (data) . tag)
  assert.is_false (type (data) . component)
  assert.is_false (type (data) . data)
  assert.is_true  (type (data) . sequence)
end
do
  local data = {
    a = {}, b = {}, c = {}
  }
  assert.is_false (type (data) . tag)
  assert.is_false (type (data) . component)
  assert.is_false (type (data) . data)
  assert.is_false (type (data) . sequence)
end
