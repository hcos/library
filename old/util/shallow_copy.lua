-- Shallow Copy
-- ============

-- This `clone` function performs a shallow copy of a table. If its
-- parameter is `nil`, it returns an empty table.
--
-- __Trick:__ This function contains two implementations of the shallow
-- copy: one for Lua 5.2 using `table.(un)pack`, the other one for previous
-- Lua versions, performing a table copy through iteration. The Lua 5.2
-- version is more efficient.
--
local clone
if table.pack and table.unpack then -- Lua 5.2
  clone = function (data)
    if type (data) ~= "table" then
      return data
    else
      local result = table.pack (table.unpack (data))
      result.n = nil
      return result
    end
  end
else
  clone = function (data)
    if type (data) ~= "table" then
      return data
    else
      local result = {}
      for k, v in pairs (data) do
        result[k] = v
      end
      return result
    end
  end
end

-- This module only exports the `clone` function.
return clone
