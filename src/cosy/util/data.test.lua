local assert = require "luassert"
local tags   = require "cosy.util.tags"
local ignore = require "cosy.util.ignore"
local Data   = require "cosy.util.data"

local data    = Data.new
local is_data = Data.is
local value   = Data.value
local exists  = Data.exists

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
  assert.are.equal (value {}, nil)
  assert.are.equal (value (1), nil)
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
  for _ in pairs (d.c) do
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
  for _ in pairs (root.m.x) do
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
  assert.are.equal (value (root.m.x.a), 1)
  assert.are.equal (value (root.m.x.b), 2)
  assert.are.equal (value (root.m.x.c), 3)
  assert.are.equal (value (root.m.x  ), nil)
  assert.are.equal (value (root.m.y  ), 5)
  assert.are.equal (value (root.m.z  ), root.f1.t)
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
  assert.is_true  (exists (root))
  assert.is_true  (exists (root.m))
  assert.is_true  (exists (root.f1))
  assert.is_true  (exists (root.f2))
  assert.is_true  (exists (root.m.x))
  assert.is_true  (exists (root.m.x.b))
  assert.is_true  (exists (root.m.x.c))
  assert.is_false (exists ({}))
  assert.is_false (exists (root.w))
  assert.is_false (exists (root.m.x.d))
end

do
  assert.is_false (is_data (1))
  assert.is_false (is_data {} )
end

do
  local d = data {}
  assert.is_true (is_data (d))
  assert.is_true (is_data (d.x))
end

do
  local target
  local value
  local reverse
  Data.on_write ["me"] = function (t, v, r)
    target  = t
    value   = v
    reverse = r
  end
  local t = {}
  local d = data (t)
  d.a = 1
  assert.are.equal (target, d.a)
  assert.are.equal (value, 1)
  assert.are.same  (t, { a = 1 })
  reverse ()
  assert.are.equal (target, d.a)
  assert.are.equal (value, nil)
  assert.are.same  (t, {})
  reverse ()
  assert.are.same  (t, { a = 1 })
end

do
  local reverse
  Data.on_write ["me"] = function (t, v, r)
    ignore (t, v)
    reverse = r
  end
  local t = {
    x = 1,
    y = { z = 3 }
  }
  local d = data (t)
  -- Replace value by value:
  d.x = 0
  assert.are.same (t, {
    x = 0,
    y = { z = 3 },
  })
  reverse ()
  assert.are.same (t, {
    x = 1,
    y = { z = 3 },
  })
  -- Add table to value:
  d.x = { a = true }
  assert.are.same (t, {
    x = { [VALUE] = 1, a = true },
    y = { z = 3 },
  })
  reverse ()
  assert.are.same (t, {
    x = 1,
    y = { z = 3 },
  })
  -- Add value to table:
  d.y = true
  assert.are.same (t, {
    x = 1,
    y = { [VALUE] = true, z = 3 },
  })
  reverse ()
  assert.are.same (t, {
    x = 1,
    y = { z = 3 },
  })
  -- Replace table by table:
  d.y = { a = true }
  assert.are.same (t, {
    x = 1,
    y = { a = true },
  })
  reverse ()
  assert.are.same (t, {
    x = 1,
    y = { z = 3 },
  })
end

do
  local reverse
  Data.on_write ["me"] = function (t, v, r)
    ignore (t, v)
    reverse = r
  end
  local t = {
    a = {
      b = {
        c = { d = false }
      }
    }
  }
  local d = data (t)
  d.a.b.c = { d = true }
  Data.on_write ["me"] = nil
  d.a.b.c = {}
  d.a.b   = {}
  d.a     = {}
  assert.are.same (t, {})
  reverse ()
  assert.are.same (t, {
    a = {
      b = {
        c = {
          d = false
        }
      }
    }
  })
end
