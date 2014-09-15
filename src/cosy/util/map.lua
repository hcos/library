-- Iterator over Maps
-- ==================
--
-- This iterator allows to retrieve the key / values pairs in a data. Thus,
-- it presents data as a map.
--
-- Its usage is:
--
--       for k, v in map (data) do ... end
--
local raw = require "cosy.util.raw"

local function map (data)
  if type (data) ~= "table" then
    return function () end
  end
  data = raw (data)
  return coroutine.wrap (
    function ()
      for k, v in pairs (data) do
        coroutine.yield (k, v)
      end
    end
  )
end

return map
