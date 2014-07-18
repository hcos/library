string.rpad = function (string, len, char)
  char = char or " "
  return string.rep (char, len - #string) .. string
end 

string.lpad = function (string, len, char)
  char = char or " "
  return string .. string.rep (char, len - #string)
end 

local function measure (functions)
  -- Find the required number of iterations:
  local any_f
  for _, f in pairs (functions) do
    any_f = f
  end
  local iterations = 1
  while true do
    local start = os.clock ()
    for _=1, iterations do
      any_f ()
    end
    local duration = os.clock () - start
    if duration > 1 then
      break
    end
    if duration == 0 then
      iterations = iterations * 1000
    else
      iterations = iterations * (1 / duration)
    end
  end
  -- Perform benchmarks:
  local result = {}
  for k, f in pairs (functions) do
    collectgarbage ()
    local start = os.clock ()
    for _=1, iterations do
      f ()
    end
    local duration = os.clock () - start
    result [k] = duration
  end
  local by_key = {}
  local size   = 0
  for k, d in pairs (result) do
    by_key [#by_key + 1] = k
    size = math.max (size, #k)
  end
  table.sort (by_key)
  for _, k in ipairs (by_key) do
    print (tostring (k) : lpad (size) .. ": " .. tostring (result[k]))
  end
  return result
end

return measure
