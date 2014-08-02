-- Iterator over Reversed Sequences
-- ================================
--
-- This iterator allows to retrieve the values associated to successive
-- integer keys in a data (starting from `1`). Thus, it presents data as
-- a list.
--
-- Its usage is:
--
--       for v in rev (data) do ... end
--
local raw = require "cosy.util.raw"

local function rev (data)
  if type (data) ~= "table" then
    return function () end
  end
  data = raw (data)
  local f = coroutine.wrap (
    function ()
      for i = #data, 1, -1 do
        coroutine.yield (data [i])
      end
    end
  )
  return f
end

return rev
