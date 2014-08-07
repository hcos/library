local assert = require "luassert"
require "cosy.util.string"

do
  assert.are.equal ("" % {}, "")
end

do
  assert.are.equal ("$a" % { a = 1}, "$a")
end

do
  assert.are.equal ("${a}" % { a = 1 }, "1")
end
