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
local raw   = data.raw

-- When applied on a table, he `raw` function returns the `RAW`, or the
-- data itself if there is no such field:
local RAW = tags.RAW
local a_data = {}
assert.are.equal (raw (a_data), a_data)
local raw_data = {}
a_data [RAW] = raw_data
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
assert.has.no.errors (function ()
  walk (component_1)
  walk (component_2)
end)
assert.has.errors (function ()
  walk (component_1.a)
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
local seen = {}
for d in walk (component_1) do
  if seen [d] then
    seen [d] = seen [d] + 1
  else
    seen [d] = 1
  end
end
assert.are.equal (seen [component_1  ], 1)
assert.are.equal (seen [component_1.a], 1)
assert.are.equal (seen [component_2  ], nil)
assert.are.equal (seen [component_2.x], nil)
assert.are.equal (seen [component_2.y], nil)

-- With `visit_once = true` and `in_component = false`,
--
-- * `component_1` is seen once ;
-- * `component_1.a` is also seen once;
-- * `component_2.x` is also soon once, reached from `component_1.external`;
-- * other data in `component_2` are ever seen.
local seen = {}
for d in walk (component_1, { in_component = false }) do
  if seen [d] then
    seen [d] = seen [d] + 1
  else
    seen [d] = 1
  end
end
assert.are.equal (seen [component_1  ], 1)
assert.are.equal (seen [component_1.a], 1)
assert.are.equal (seen [component_2  ], nil)
assert.are.equal (seen [component_2.x], 1)
assert.are.equal (seen [component_2.y], nil)

-- With `visit_once = false` and `in_component = true`,
--
-- * `component_1` is seen twice (reached as root and as
--   `component_1.circular`);
-- * `component_1.a` is also seen twice (reached as `component_1.a` and
--   `component_1.internal`);
-- * no data in `component_2` is ever seen.
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

-- With `visit_once = false` and `in_component = false`,
--
-- * `component_1` is seen twice (reached as root and as
--   `component_1.circular`);
-- * `component_1.a` is also seen twice (reached as `component_1.a` and
--   `component_1.internal`);
-- * `component_2.x` is also soon once, reached from `component_1.external`;
-- * other data in `component_2` are ever seen.
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
