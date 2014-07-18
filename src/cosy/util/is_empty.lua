-- Test for emptiness
-- ==================
--
-- This function is not an iterator but can be useful when dealing with
-- collections.
--
-- Its usage is:
--
--      if [not] is_empty (data) then
--        ...
--      end

local raw = require "cosy.util.raw"

local function is_empty (data)
  if type (data) ~= "table" then
    return nil
  end
  data = raw (data)
  return pairs (data) (data) == nil
end

return is_empty
