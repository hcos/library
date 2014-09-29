local Data = require "cosy.data"

local Algorithm = {}

function Algorithm.map (data)
  assert (Data.is (data))
  return coroutine.wrap (
    function ()
      for k in pairs (data) do
        coroutine.yield (k)
      end
    end
  )
end

function Algorithm.seq (data)
  assert (Data.is (data))
  return coroutine.wrap (
    function ()
      for i in ipairs (data) do
        coroutine.yield (i)
      end
    end
  )
end

function Algorithm.set (data)
  assert (Data.is (data))
  return coroutine.wrap (
    function ()
      for k, v in pairs (data) do
        if v == true then
          coroutine.yield (k)
        end
      end
    end
  )
end

function Algorithm.reversed (iterator)
  local results = {}
  for v in iterator do
    results [#results + 1] = v
  end
  return coroutine.wrap (
    function ()
      for i = #results, 1, -1 do
        coroutine.yield (results [i])
      end
    end
  )
end

function Algorithm.sorted (iterator)
  local results = {}
  for v in iterator do
    results [#results + 1] = v
  end
  table.sort (results, function (l, r)
    return tostring (l) < tostring (r)
  end)
  return coroutine.wrap (
    function ()
      for r in ipairs (results) do
        coroutine.yield (r)
      end
    end
  )
end

function Algorithm.filter (x, f)
  assert (Data.is (x) or type (x) == "function")
  return coroutine.wrap (
    function ()
      local iterator
      if type (x) == "function" then
        iterator = x
      else
        iterator = Algorithm.map (x)
      end
      for v in iterator do
        if f (v) then
          coroutine.yield (v)
        end
      end
    end
  )
end

return Algorithm
