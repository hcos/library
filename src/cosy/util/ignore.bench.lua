-- Benchmarks for `ignore`
-- =======================
--
local ignore  = require "cosy.util.ignore"
local measure = require "cosy.util.bench"

do
  measure {
    ["with unused" ] =  function ()
                        end,
    ["with ignore" ] =  function (a, b, c)
                          ignore (a, b, c)
                        end,
    ["with local"  ] =  function (a, b, c)
                          local _ = a, b, c
                        end,
  }
end
