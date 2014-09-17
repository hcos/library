local assert = require "luassert"
local data   = require "cosy.util.data"
local value  = require "cosy.util.value"

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
  assert.are.equal (value (root.m.x.a), 1)
  assert.are.equal (value (root.m.x.b), 2)
  assert.are.equal (value (root.m.x.c), 3)
  assert.are.equal (value (root.m.x  ), nil)
  assert.are.equal (value (root.m.y  ), 5)
  assert.are.equal (value (root.m.z  ), root.f1.t)
end

