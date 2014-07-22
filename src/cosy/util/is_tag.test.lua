local assert = require "luassert"
local is_tag = require "cosy.util.is_tag"
local tags   = require "cosy.util.tags"

do
  assert.is_falsy (is_tag (nil))
  for _, x in ipairs {
    true,
    0,
    "",
    function () end,
    coroutine.create (function () end),
  } do
    assert.is_falsy (is_tag (x))
  end
end

do
  local t = tags.T
  assert.is_true (is_tag (t))
end
