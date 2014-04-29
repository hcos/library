local assert = require "luassert"
local tags   = require "cosy.lang.data.tags"

test ("cosy.lang.data.tags", function ()
  assert.are.equal (tostring(tags.TAG), "[TAG]")
end)
