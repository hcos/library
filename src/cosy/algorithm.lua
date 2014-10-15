local Data = require "cosy.data"

local Algorithm = {}

function Algorithm.map (data)
  assert (Data.is (data))
  return coroutine.wrap (
    function ()
      for k, v in pairs (data) do
        coroutine.yield (k, v)
      end
    end
  )
end

function Algorithm.seq (data)
  assert (Data.is (data))
  return coroutine.wrap (
    function ()
      for i, v in ipairs (data) do
        coroutine.yield (i, v)
      end
    end
  )
end

function Algorithm.set (data)
  assert (Data.is (data))
  return coroutine.wrap (
    function ()
      for k, v in pairs (data) do
        if v () == true then
          coroutine.yield (k, v)
        end
      end
    end
  )
end

function Algorithm.reversed (iterator)
  local keys   = {}
  local values = {}
  for k, v in iterator do
    keys   [#keys   + 1] = k
    values [#values + 1] = v
  end
  local size = #keys
  for i = 1, size / 2 do
    keys   [i], keys   [size+1-i] = keys   [size+1-i], keys   [i]
    values [i], values [size+1-i] = values [size+1-i], values [i]
  end
  return coroutine.wrap (
    function ()
      for i = 1, size do
        coroutine.yield (keys [i], values [i])
      end
    end
  )
end

function Algorithm.sorted (iterator)
  local keys    = {}
  local results = {}
  for k, v in iterator do
    keys [#keys + 1] = k
    results [k] = v
  end
  table.sort (keys, function (l, r)
    if type (l) == type (r) then
      return l < r
    else
      return type (l) < type (r)
    end
  end)
  return coroutine.wrap (
    function ()
      for _, k in ipairs (keys) do
        coroutine.yield (k, results [k])
      end
    end
  )
end

function Algorithm.filtered (iterator, f)
  assert (type (f) == "function")
  return coroutine.wrap (
    function ()
      for k, v in iterator do
        if f (k, v) then
          coroutine.yield (k, v)
        end
      end
    end
  )
end

return Algorithm
