local Runner = require "busted.runner"
require "cosy.loader"
Runner ()

local _ = require "cosy.string"

describe ("cosy.string", function ()

  it ("replaces {{{key}}} by its value using the % operator", function ()
    assert.are.equal ("prefix {{{key}}} suffix" % {
      key = "value",
    }, "prefix value suffix")
  end)

  it ("extracts {{{key}}} from its value using the / operator", function ()
    assert.are.same ("prefix {{{key}}} suffix" / "prefix value suffix", {
      key = "value",
    })
  end)

end)
