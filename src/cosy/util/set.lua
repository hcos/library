-- Iterator over Sets
-- ==================
--
-- This iterator allows to retrieve the keys associated to neither `nil` nor
-- `false` in a data. Thus, it presents data as a set.
--
-- Its usage is:
--
--       for k in set (data) do ... end
--
local raw = require "cosy.util.raw"

local function set (data)
  if type (data) ~= "table" then
    return function () end
  end
  data = raw (data)
  local f = coroutine.wrap (
    function ()
      for k, v in pairs (data) do
        if v then
          coroutine.yield (k)
        end
      end
    end
  )
  return f
end

return set
