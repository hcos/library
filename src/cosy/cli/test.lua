local Runner = require "busted.runner"
require "cosy.loader"
Runner ()

local _ = require "cosy.cli"

describe ("cosy.string", function ()


  it ("dummy test 01", function ()
    assert.are.same ( { key = "value", }, { key = "value", })
    assert.True (1 == 1)
    assert.is_true (1 == 1)
    assert.falsy (nil)
    assert.has_error (function() error("what") end, "what")
  end)

end)



--
--local Runner = require "busted.runner"
--require "cosy.loader"
--Runner ()
--
--local _ = require "cosy.cli"
--
--describe ("cosy.cli", function ()
--
--  it ("dummy test", function ()
--    assert.true (1 == 1)
--  end)
--
--end)
