-- These lines are required to correctly run tests:
require "busted.runner" ()
local loader = require "cosy.loader.lua" {
  logto = false,
}
loader.load "cosy.string"

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
