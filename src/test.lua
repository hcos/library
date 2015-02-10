require "compat52"
local serpent = require "serpent"


local PARENTS = "parents"
local LAYERS  = "layers"

-- https://xivilization.net/~marek/blog/2014/12/08/implementing-c3-linearization/
local function c3 (data)
  if #(data [PARENTS]) == 0 then
    data [LAYERS] = { data }
  else
    local n  = { 1 }
    local l  = { { data } }
    local parents = data [PARENTS]
    for i = #parents, 1, -1 do
      local parent = parents [i]
      local layers = parent  [LAYERS]
      if layers then
        l [#l+1] = layers
        n [#n+1] = #layers
      end
    end
    l [#l+1] = parents
    n [#n+1] = #parents
    local tails  = {}
    for i = 1, #l do
      local v = l [i]
      for j = 1, #v do
        local w   = v [j]
        tails [w] = (tails [w] or 0) + 1
      end
    end
    local layers = {}
    while #l ~= 0 do
      for i = 1, #l do
        local vl, vn  = l [i], n [i]
        local first   = vl [vn]
        tails [first] = tails [first] - 1
      end
      local head
      for i = 1, #l do
        local vl, vn = l [i], n [i]
        local first  = vl [vn]
        if tails [first] == 0 then
          head = first
          break
        end
      end
      if head == nil then
        error "Linearization failed."
      end
      layers [#layers + 1] = head
      for i = 1, #l do
        local vl, vn = l [i], n [i]
        local first  = vl [vn]
        if first == head then
          n [i] = n [i] - 1
        else
          tails [first] = tails [first] + 1
        end
      end
      local nl, nn = {}, {}
      for i = 1, #l do
        if n [i] ~= 0 then
          nl [#nl+1] = l [i]
          nn [#nn+1] = n [i]
        end
      end
      l, n = nl, nn
    end
    for i = 1, #layers / 2 do
      layers [i], layers [#layers-i+1] = layers [#layers-i+1], layers [i]
    end
    data [LAYERS] = layers
  end
end

local function class (name, parents)
  local ps = {}
  if parents then
    for i = 1, #parents do
      ps [i] = parents [#parents-i+1]
    end
  end
  local data = setmetatable ({
    [PARENTS] = ps,
  }, {
    __tostring = function (x) return name end,
  })
--  print ("===== " .. tostring (data) .. " =====")
  c3 (data)
--  print ("parents:", serpent.dump (data [PARENTS]))
--  print ("layers :", serpent.dump (data [LAYERS ]))
  return data
end

local profiler = require "profiler"

profiler.start "test.log"
for i = 1, 5000 do
  local o = class ("o")
  local a = class ("a", { o })
  local b = class ("b", { o })
  local c = class ("c", { o })
  local d = class ("d", { o })
  local e = class ("e", { o })
  local k1 = class ("k1", { a, b, c })
  local k2 = class ("k2", { d, b, e })
  local k3 = class ("k3", { d, a })
  local z = class ("z", { k1, k2, k3 })
end
profiler.stop ()
