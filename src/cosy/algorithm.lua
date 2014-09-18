local Algorithm = {}

function Algorithm.map (data)
  if type (data) ~= "table" then
    return function () end
  end
  return coroutine.wrap (
    function ()
      for k, v in pairs (data) do
        coroutine.yield (k, v)
      end
    end
  )
end

function Algorithm.seq (data)
  if type (data) ~= "table" then
    return function () end
  end
  local f = coroutine.wrap (
    function ()
      for _, v in ipairs (data) do
        coroutine.yield (v)
      end
    end
  )
  return f
end

function Algorithm.set (data)
  if type (data) ~= "table" then
    return function () end
  end
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

return Algorithm
