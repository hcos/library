local assert = require "luassert"
local tags   = require "cosy.lang.tags"

test ("cosy.lang.data.tags", function ()
  assert.are.equal (tostring(tags.TAG), "[TAG]")
end)
