local raw = require "cosy.util.raw"

local function size (data)
  if type (data) ~= "table" then
    return nil
  end
  data = raw (data)
  local result = 0
  for _ in pairs (data) do
    result = result + 1
  end
  return result
end

return size
