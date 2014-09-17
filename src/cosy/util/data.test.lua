local assert = require "luassert"
local tags   = require "cosy.util.tags"
local data   = require "cosy.util.data"

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

