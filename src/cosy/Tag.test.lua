local assert = require "luassert"
local Tag    = require "cosy.Tag"

-- Tag.new
do
  local t = Tag.new "something"
  assert.are.equal (t, Tag.something)
  assert.has.error (function () Tag.new "something" end)
end

-- Tag.*
do
  Tag.new "t1"
  assert.has.no.error (function () return Tag.t1 end)
  assert.has.error    (function () return Tag.t2 end)
end

-- Tag.is
do
  local t = Tag.new "t"
  assert.is_true  (Tag.is (t))
  assert.is_false (Tag.is (1))
  assert.is_false (Tag.is {} )
end

-- tostring
do
  local word = Tag.new "word"
  assert.are.equal (tostring (word), 'Tag [ "word" ]')
end
