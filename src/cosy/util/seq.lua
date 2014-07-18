-- Iterator over Sequences
-- =======================
--
-- This iterator allows to retrieve the values associated to successive
-- integer keys in a data (starting from `1`). Thus, it presents data as
-- a list.
--
-- Its usage is:
--
--       for v in seq (data) do ... end
--
local raw = require "cosy.util.raw"

local function seq (data)
  if type (data) ~= "table" then
    return function () end
  end
  data = raw (data)
  local f = coroutine.wrap (
    function ()
      for _, v in ipairs (data) do
        coroutine.yield (v)
      end
    end
  )
  return f
end

return seq
