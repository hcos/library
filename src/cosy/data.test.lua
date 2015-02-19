               require "busted"
local assert = require "luassert"
local Data   = require "cosy.data"

local Platform = require "cosy.platform"
Platform.logger.enabled = false

describe ("c3 linearization", function ()

  local repository

  before_each (function ()
    repository = Data.new {}
  end)

  it ("works as expected", function ()
    -- See: [C3 Linearization](http://en.wikipedia.org/wiki/C3_linearization)
    repository.o = {
      name = "o",
    }
    repository.a = {
      name = "a",
      [Data.DEPENDS] = { repository.o },
    }
    repository.b = {
      name = "b",
      [Data.DEPENDS] = { repository.o },
    }
    repository.c = {
      name = "c",
      [Data.DEPENDS] = { repository.o },
    }
    repository.d = {
      name = "d",
      [Data.DEPENDS] = { repository.o },
    }
    repository.e = {
      name = "e",
      [Data.DEPENDS] = { repository.o },
    }
    repository.i = {
      name = "i",
      [Data.DEPENDS] = { repository.c, repository.b, repository.a },
    }
    repository.j = {
      name = "j",
      [Data.DEPENDS] = { repository.e, repository.b, repository.d },
    }
    repository.k = {
      name = "k",
      [Data.DEPENDS] = { repository.a, repository.d },
    }
    repository.z = {
      name = "z",
      [Data.DEPENDS] = { repository.k, repository.j, repository.i },
    }
    
    local o = Data.raw (repository, "o")
    local a = Data.raw (repository, "a")
    local b = Data.raw (repository, "b")
    local c = Data.raw (repository, "c")
    local d = Data.raw (repository, "d")
    local e = Data.raw (repository, "e")
    local i = Data.raw (repository, "i")
    local j = Data.raw (repository, "j")
    local k = Data.raw (repository, "k")
    local z = Data.raw (repository, "z")
    
    assert.are.same (Data.linearize (repository, "o"), {
      o
    })
    assert.are.same (Data.linearize (repository, "a"), {
      o, a,
    })
    assert.are.same (Data.linearize (repository, "b"), {
      o, b,
    })
    assert.are.same (Data.linearize (repository, "c"), {
      o, c,
    })
    assert.are.same (Data.linearize (repository, "d"), {
      o, d,
    })
    assert.are.same (Data.linearize (repository, "e"), {
      o, e,
    })
    assert.are.same (Data.linearize (repository, "i"), {
      o, c, b, a, i
    })
    assert.are.same (Data.linearize (repository, "j"), {
      o, e, b, d, j
    })
    assert.are.same (Data.linearize (repository, "k"), {
      o, a, d, k
    })
    assert.are.same (Data.linearize (repository, "z"), {
      o, e, c, b, a, d, k, j, i, z,
    })
  end)

end)

describe ("a layer", function ()

  local repository

  before_each (function ()
    repository = Data.new {}
  end)

  it ("allows to read values", function ()
    repository.c1 = {
      a = 1,
    }
    assert.are.equal (repository.c1.a._, 1)
    assert.is_nil    (repository.c1.b._)
  end)

  it ("allows to write values", function ()
    repository.c1 = {}
    repository.c1.a._ = 1
    assert.are.equal (repository.c1.a._, 1)
    assert.is_nil    (repository.c1.b._)
  end)

  it ("invokes filter on read", function ()
    repository.c1 = {
      a = 1,
    }
    local s = spy.new (function () end)
    Data.options (repository) .filter = s
    local _ = repository.c1.a._
    assert.spy (s).was.called ()
  end)

  it ("invokes hook on write", function ()
    repository.c1 = {
      a = 1,
    }
    local s = spy.new (function () end)
    Data.options (repository) .on_write.name = s
    repository.c1.a._ = 2
    assert.spy (s).was.called ()
  end)

  it ("allows to overwrite values", function ()
    repository.c1 = {
      a = 1,
      b = {
        x = 1,
      },
    }
    repository.c1.a._ = 2
    assert.are.equal (repository.c1.a._, 2)
    assert.has.error (function ()
      repository.c1.a._ = { y = 1 }
    end)
    repository.c1.b = { x = 2 }
    assert.are.equal (repository.c1.b.x._, 2)
    repository.c1.b._ = 2
    assert.are.equal (repository.c1.b._, 2)
    assert.are.equal (repository.c1.b.x._, 2)
    repository.c1.b = 2
    assert.are.equal (repository.c1.b._, 2)
    assert.is_nil    (repository.c1.b.x._)
  end)

  it ("writes in the nearest layer", function ()
    repository.c1 = {
      a = 1,
    }
    repository.c2 = {
      [Data.DEPENDS] = { repository.c1 },
    }
    repository.c2.a = 2
    assert.are.equal (repository.c2.a._, 2)
    assert.are_equal (repository.c1.a._, 1)
  end)

  it ("handles proxies in depends", function ()
    repository.c1 = {
      a = 1,
    }
    repository.c2 = {
      [Data.DEPENDS] = { repository.c1 },
    }
    assert.are.equal (repository.c2.a._, 1)
  end)

  it ("exposes the nearest value", function ()
    repository.c1 = {
      a = 1,
    }
    repository.c2 = {
      a = 2,
      [Data.DEPENDS] = { repository.c1 },
    }
    assert.are.equal (repository.c1.a._, 1)
    assert.are.equal (repository.c2.a._, 2)
  end)


  it ("uses its dependencies from last to first", function ()
    repository.c1 = {
      a = 1,
    }
    repository.c2 = {
      a = 2,
    }
    repository.c3 = {
      [Data.DEPENDS] = { repository.c1, repository.c2 },
    }
    assert.are.equal (repository.c3.a._, 2)
  end)

  it ("allows diamond in dependencies", function ()
    repository.c1 = {
      a = 1,
      b = 1,
    }
    repository.c2 = {
      b = 2,
      [Data.DEPENDS] = { repository.c1 },
    }
    repository.c3 = {
      b = 3,
      [Data.DEPENDS] = { repository.c1 },
    }
    repository.c4 = {
      [Data.DEPENDS] = { repository.c2, repository.c3 },
    }
    assert.are.equal (repository.c4.a._, 1)
    assert.are.equal (repository.c4.b._, 3)
  end)

  it ("merges layers in all the data tree", function ()
    repository.c1 = {
      a = {
        x = 1,
        y = 1,
      },
    }
    repository.c2 = {
      a = {
        y = 2,
      },
      [Data.DEPENDS] = { repository.c1 },
    }
    assert.are.equal (repository.c2.a.x._, 1)
    assert.are.equal (repository.c2.a.y._, 2)
  end)
--[[
  it ("is efficient enough", function ()
    do
      local quantity = 1000
      local start    = Platform.time ()
      local depends  = {}
      for i = 1, quantity do
        repository [i] = {
          [i] = i,
        }
        depends [#depends+1] = repository [i]
      end
      repository.all = {
        [Data.DEPENDS] = depends
      }
      local finish   = Platform.time ()
      print ("# create / second:", math.floor (quantity / (finish - start)))
    end
    for _, depth in ipairs {
      1, 2, 5,
      10, 20, 50,
      100, 200, 500,
    } do
      local quantity = 10000
      local depends  = {}
      for i = 1, depth do
        repository [i] = {
          [i] = i,
        }
        depends [#depends+1] = repository [i]
      end
      repository.all = {
        [Data.DEPENDS] = depends
      }
      local start    = Platform.time ()
      for i = 1, quantity do
        local _ = repository.all [i % depth + 1]._
      end
      local finish   = Platform.time ()
      print ("# read / second / depth", depth, math.floor (quantity / (finish - start)))
    end
  end)
--]]
end)

describe ("a reference", function ()

  local _ = Data.placeholder
  local repository

  before_each (function ()
    repository = Data.new {}
  end)

  it ("handles proxies without layer", function ()
    repository.c1 = {
      a = 1,
      b = _.a,
    }
    assert.are.equal (repository.c1.b()._, 1)
  end)

  it ("writes references", function ()
    repository.c1 = {
      a = 1,
    }
    repository.c1.b = repository.c1.a
    assert.are.equal (repository.c1.b()._, 1)
  end)
  
  it ("can follow multiple redirects", function ()
    repository.c1 = {
      a = 1,
      b = _.a,
      c = _.b,
    }
    assert.are.equal (repository.c1.c()()._, 1)
    assert.are.equal (repository.c1.c(2)._ , 1)
    assert.is_nil    (repository.c1.c(3)._)
  end)

  it ("is followed from the top layer", function ()
    repository.c1 = {
      b = _.a,
    }
    repository.c2 = {
      c = _.b,
    }
    repository.c3 = {
      a = 1,
      [Data.DEPENDS] = { repository.c1, repository.c2 },
    }
    assert.are.equal (repository.c3.c()()._, 1)
    assert.are.equal (repository.c3.c(2)._ , 1)
  end)

  it ("can also have a value", function ()
    repository.c1 = {
      a = 1,
      b = _.a,
      c = _.b,
    }
    repository.c2 = {
      b = 2,
      [Data.DEPENDS] = { repository.c1 },
    }
    assert.are.equal (repository.c2.c()._, 2)
  end)

end)

describe ("a repository", function ()

  local repository

  before_each (function ()
    repository = Data.new {}
  end)

  it ("can be exported to Lua table", function ()
    repository.c1 = {
      a = 1,
    }
    repository.c2 = {
      [Data.DEPENDS] = { repository.c1 },
    }
    assert.has.no.error (function ()
      Platform.table.encode (Data.raw (repository))
    end)
  end)

  it ("can be exported to JSON", function ()
    repository.c1 = {
      a = 1,
    }
    repository.c2 = {
      [Data.DEPENDS] = { repository.c1 },
    }
    assert.has.no.error (function ()
      Platform.json.encode (Data.raw (repository))
    end)
  end)

  it ("can be exported to YAML", function ()
    repository.c1 = {
      a = 1,
    }
    repository.c2 = {
      [Data.DEPENDS] = { repository.c1 },
    }
    assert.has.no.error (function ()
      Platform.yaml.encode (Data.raw (repository))
    end)
  end)

end)