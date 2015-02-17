               require "busted"

local assert = require "luassert"
local Layer  = require "data"

describe ("c3 linearization", function ()

  it ("works", function ()
    local o = {
      name = "o",
    }
    local a = {
      name = "a",
      [Layer.DEPENDS] = { o },
    }
    local b = {
      name = "b",
      [Layer.DEPENDS] = { o },
    }
    local c = {
      name = "c",
      [Layer.DEPENDS] = { o },
    }
    local d = {
      name = "d",
      [Layer.DEPENDS] = { o },
    }
    local e = {
      name = "e",
      [Layer.DEPENDS] = { o },
    }
    local i = {
      name = "i",
      [Layer.DEPENDS] = { c, b, a },
    }
    local j = {
      name = "j",
      [Layer.DEPENDS] = { e, b, d },
    }
    local k = {
      name = "k",
      [Layer.DEPENDS] = { a, d },
    }
    local z = {
      name = "z",
      [Layer.DEPENDS] = { k, j, i },
    }
    assert.are.same (Layer.linearize (o), {
      o
    })
    assert.are.same (Layer.linearize (a), {
      o, a,
    })
    assert.are.same (Layer.linearize (b), {
      o, b,
    })
    assert.are.same (Layer.linearize (c), {
      o, c,
    })
    assert.are.same (Layer.linearize (d), {
      o, d,
    })
    assert.are.same (Layer.linearize (e), {
      o, e,
    })
    assert.are.same (Layer.linearize (i), {
      o, c, b, a, i
    })
    assert.are.same (Layer.linearize (j), {
      o, e, b, d, j
    })
    assert.are.same (Layer.linearize (k), {
      o, a, d, k
    })
    assert.are.same (Layer.linearize (z), {
      o, e, c, b, a, d, k, j, i , z
    })
  end)

end)

describe ("layers", function ()

  it ("", function ()
    local c1 = Layer.import {
      a = 1,
      b = {
        x = 1,
      },
      name = "c1",
    }
    local c2 = Layer.import {
      a = 2,
      b = {
        y = 2,
      },
      c = 3,
      name = "c2",
      [Layer.DEPENDS] = {
        Layer.export (c1),
      },
    }
    assert.are.equal (c2.a._  , 2)
    assert.are.equal (c2.b.x._, 1)
    assert.are.equal (c2.b.y._, 2)
    assert.are.equal (c2.c._  , 3)
  end)
--[[
  it ("", function ()
    local c1 = Layer.import {
      a = {
        x = 1,
      },
    }
    local c2 = Layer.import {
      b = {
        [Layer.INHERITS] = { "a" },
      },
    }
    local c3 = Layer.above {
      c1,
      c2,
    }
    assert.are.equal (c3.a._  , 2)
  end)
--]]
end)
