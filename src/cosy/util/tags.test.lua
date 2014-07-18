-- `tags`
-- ======
--
local assert = require "luassert"
local tags   = require "cosy.util.tags"

do

  -- A tag is returned on demand:
  assert.are.equal (type (tags.TAG), "table")

  -- The same tag is returned each time it accessed:
  assert.are.equal (tags.TAG, tags.TAG)

  -- Tags are unique:
  assert.are_not.equal (tags.TAG, tags.OTHER_TAG)

end
