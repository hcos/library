-- Benchmarks for `proxy`
-- ======================
--
local proxy   = require "cosy.util.proxy"
local measure = require "cosy.bench"

do
  local r = { "" }
  local o = proxy () (r)
  measure {
    ["raw" ]        = function ()
                        return r [1]
                      end,
    ["with proxy" ] = function ()
                        return o [1]
                      end,
  }
end

