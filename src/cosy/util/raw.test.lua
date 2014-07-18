-- `raw`
-- =====
--
local assert = require "luassert"
local raw    = require "cosy.util.raw"
local proxy  = require "cosy.util.proxy"

do
  local NIL = {}
  -- When applied on non table values, the `raw` function returns the value
  -- unchanged:
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
    assert.are.equal (raw (value), value)
    local p = proxy ()
    assert.are.equal (raw (p (value)), value)
    local q = proxy ()
    assert.are.equal (raw (p (q (value))), value)
  end
end


