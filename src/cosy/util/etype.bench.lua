-- Benchmarks for `etype`
-- ======================
--
local etype   = require "cosy.util.etype"
local measure = require "cosy.bench"

do
  etype.object = function (_)
    return true
  end
  measure {
    ["type" ]         = function ()
                          return type ("")
                        end,
    ["etype" ]        = function ()
                          return etype ("") . string
                        end,
    ["etype custom" ] = function ()
                          return etype ("") . object
                        end,
  }
end
