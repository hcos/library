-- `ignore`
-- --------
--
local assert = require "luassert"
local ignore = require "cosy.util.ignore"

do
  local function f (a, b, c)
    ignore (a, b, c)
  end
  assert.has.no.error (f)
end
