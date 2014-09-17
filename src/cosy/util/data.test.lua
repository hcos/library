local assert = require "luassert"
local tags   = require "cosy.util.tags"
local data   = require "cosy.util.data"
local value  = require "cosy.util.value"

local PATH    = tags.PATH
local PARENTS = tags.PARENTS
local VALUE   = tags.VALUE

do
  local t = {}
  local d = data (t)
  assert.are.same (d, { [PATH] = { t } })
end

do
  local t = {}
  local d = data (t)
  assert.are.same (d.a.b, { [PATH] = { t, "a", "b" } })
  local k = {}
  assert.are.same (d [k], { [PATH] = { t, k } })
end

do
  local t = {}
  local d = data (t)
  d.x = 1
  assert.are.same (t, { x = 1 })
  d.x = { a = "a" }
  assert.are.same (t, { x = { [VALUE] = 1, a = "a" } })
  d.x = 2
  assert.are.same (t, { x = { [VALUE] = 2, a = "a" } })
  d.x = { b = "b" }
  assert.are.same (t, { x = { [VALUE] = 2, b = "b" } })
  d.x = nil
  assert.are.same (t, { x = { b = "b" } })
  d.a     = "a"
  d.a.b.c = 1
  assert.are.same (t, { x = { b = "b" }, a = { [VALUE] = "a", b = { c = 1 } } })
end

do
  local t = {}
  local d = data (t)
  assert.has.no.error (function () return tostring (d.a.b) end)
end

do
  local t = {}
  local l = data (t)
  local r = data (t)
  assert.are.equal     (l.a.b, r.a.b)
  assert.are_not.equal (l.a.b, l.a  )
  assert.are_not.equal (l.a  , l.a.b)
  assert.are_not.equal (l.a.b, l.a.c)
end

do
  local t = {}
  local d = data (t)
  d.x = d {}
  assert.are.same (t, { x = { [PARENTS] = { d } } })
end

do
  local t = {}
  local d = data (t)
  d.x = {}
  d.y = {}
  d.z = {}
  d.a = (d.x + d.y + d.z) {}
  assert.are.same (t.a, { [PARENTS] = { d.x, d.y, d.z } })
  d.a = ((d.x + d.y) + d.z) {}
  assert.are.same (t.a, { [PARENTS] = { d.x, d.y, d.z } })
  d.a = (d.x + (d.y + d.z)) {}
  assert.are.same (t.a, { [PARENTS] = { d.x, d.y, d.z } })
  d.a = ((d.x + d.y) + (d.y + d.z)) {}
  assert.are.same (t.a, { [PARENTS] = { d.x, d.y, d.y, d.z } })
  assert.has.error (function () return d.x + {} end)
  assert.has.error (function () return (d.x + d.y) + {} end)
end

do
  local d = data {}
  d.a = {
    [2] = 2
  }
  d.b = d.a {
    [3] = 3
  }
  d.c = d.b {
    [1] = 1
  }
  assert.are.equal (#d.c, 3)
end

do
  local d = data {}
  d.a = {
    [2] = 2
  }
  d.b = d.a {
    [3] = 3
  }
  d.c = d.b {
    [1] = 1
  }
  local count = 0
  for i, v in ipairs (d.c) do
    assert.are.equal (i, value (v))
    count = count + 1
  end
  assert.are.equal (count, 3)
end

do
  local d = data {}
  d.a = {
    [2] = 2
  }
  d.b = d.a {
    [3] = 3
  }
  d.c = d.b {
    [1] = 1
  }
  local count = 0
  for k, v in pairs (d.c) do
    count = count + 1
  end
  assert.are.equal (count, 3)
end

do
  local root = data {}
  root.f1 = {
    t = {
      x = {
        c = 3,
      },
    },
  }
  root.f2 = {
    t = {
      x = {
        a = 1,
      },
      y = {
        z = true,
      },
      z = root.f1.t,
    },
  }
  root.m = (root.f1.t + root.f2.t) {
    x = {
      b = 2,
    },
    y = 5,
  }
  local count = 0
  for k, v in pairs (root.m.x) do
    count = count + 1
  end
  assert.are.equal (count, 3)
end
