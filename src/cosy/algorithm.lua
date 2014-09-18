local Algorithm = {}

function Algorithm.map (data)
  assert (type (data) == "table")
  return coroutine.wrap (
    function ()
      for k, v in pairs (data) do
        coroutine.yield (k, v)
      end
    end
  )
end

function Algorithm.seq (data)
  assert (type (data) == "table")
  return coroutine.wrap (
    function ()
      for i, v in ipairs (data) do
        coroutine.yield (i, v)
      end
    end
  )
end

function Algorithm.set (data)
  assert (type (data) == "table")
  return coroutine.wrap (
    function ()
      for k, v in pairs (data) do
        if v then
          coroutine.yield (k)
        end
      end
    end
  )
end

function Algorithm.reversed (iterator)
  local results = {}
  for k, v in iterator do
    results [#results + 1] = {
      k = k,
      v = v,
    }
  end
  return coroutine.wrap (
    function ()
      for i = #results, 1, -1 do
        local result = results [i]
        coroutine.yield (result.k, result.v)
      end
    end
  )
end

local function sort (lhs, rhs)
  if type (lhs) < type (rhs) then
    return true
  elseif type (lhs) > type (rhs) then
    return false
  else
    return lhs < rhs
  end
end

function Algorithm.sorted (iterator)
  local keys    = {}
  local results = {}
  for k, v in iterator do
    keys [#keys + 1] = k
    results [k] = v
  end
  table.sort (keys, sort)
  return coroutine.wrap (
    function ()
      for _, k in ipairs (keys) do
        coroutine.yield (k, results [k])
      end
    end
  )
end

return Algorithm
