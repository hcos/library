local assert   = require "luassert"
local is_proxy = require "cosy.util.is_proxy"
local proxy    = require "cosy.util.proxy"

do

  local a_proxy = proxy ()

  local NIL = {}
  for _, value in ipairs {
    NIL,
    true,
    0,
    "",
    { "" },
    function () end,
    coroutine.create (function () end),
  } do
    if value == NIL then
      value = nil
    end
    assert.is_falsy (is_proxy (value))
    assert.is_true  (is_proxy (a_proxy (value)))
  end

end
