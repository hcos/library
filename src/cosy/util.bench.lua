local util   = require "cosy.util"

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

-- Benchmarks for `ignore`
-- =======================
--
do
  local ignore = util.ignore
  measure {
    ["with unused" ] =  function (a, b, c)
                        end,
    ["with ignore" ] =  function (a, b, c)
                          ignore (a, b, c)
                        end,
    ["with local"  ] =  function (a, b, c)
                          local _ = a, b, c
                        end,
  }
end

-- Benchmarks for `proxy`
-- ======================
--
-- 
do
  local proxy = util.proxy
  local p = proxy ()
  local r = { "" }
  local o = proxy (r)
  measure {
    ["raw" ]        = function ()
                        return r [1]
                      end,
    ["with proxy" ] = function ()
                        return o [1]
                      end,
  }
end

-- Benchmarks for `etype`
-- ======================
--
-- 
do
  local etype = util.etype
  etype.object = function (x)
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
