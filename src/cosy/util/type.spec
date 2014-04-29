local assert = require "luassert"
local itype  = require "cosy.util.type"

test ("cosy.util.type", function ()
  assert.are.equal (type (true), itype (true))
  assert.are.equal (type (1   ), itype (1   ))
  assert.are.equal (type (""  ), itype (""  ))
  assert.are.equal (type ({}  ), itype ({}  ))

  itype.object = function (x)
    return x.is_object
  end

  assert.are.equal (type ({}  ), itype ({}  ))
  assert.are_not.equal (type ({}  ), itype ({ is_object = true }))
  assert.are.equal (itype ({ is_object = true }), "object")
end)
