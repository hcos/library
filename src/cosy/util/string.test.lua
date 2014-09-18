local assert = require "luassert"
require "cosy.util.string"

-- replace
do
  assert.are.equal ("" % {}, "")
  assert.are.equal ("$a" % { a = 1}, "$a")
  assert.are.equal ("${a}" % { a = 1 }, "1")
end

-- quote
do
  assert.are.equal (string.quote "a", '"a"')
  assert.are.equal (string.quote "[[", '"[["')
  assert.are.equal (string.quote '"', [['"']])
  assert.are.equal (string.quote "'", [["'"]])
  assert.are.equal (string.quote [==['[["]==], [==[[=['[["]=]]==])
end
