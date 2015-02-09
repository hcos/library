local serpent = require "serpent"

local PARENTS = "parents"
local LAYERS  = "layers"

-- https://xivilization.net/~marek/blog/2014/12/08/implementing-c3-linearization/
-- change: we use lists in reverse order
local function c3 (data)
  if #(data [PARENTS]) == 0 then
    data [LAYERS] = { data }
  else
    -- Build the list of dependencies:
    local l  = { { data } }
    local ps = {}
    local parents = data [PARENTS]
    for i = 1, #parents do
      local parent = parents [i]
      local layers = parent  [LAYERS]
      if layers then
        local ls = {}
        for j = 1, #layers do
          ls [j] = layers [j]
        end
        l [#l+1] = ls
      end
      ps [#parents-i+1] = parent
    end
    l [#l+1] = ps
    -- Compute layers:
    local layers = {}
    while #l ~= 0 do
      --[[
      do
        local dump = {}
        for i, v in ipairs (l) do
          dump [i] = {}
          for j, w in ipairs (v) do
            dump [i] [j] = tostring (w)
          end
        end
        print ("lists:", serpent.dump (dump))
      end
      --]]
      local tails = {}
      for _, v in ipairs (l) do
        for i = 1, #v-1 do
          tails [v [i]] = true
        end
      end
--      print ("tails:", serpent.dump (tails))
      local head
      for _, v in ipairs (l) do
        local last = v [#v]
        if tails [last] == nil then
          head = last
          break
        end
      end
 --     print ("head:", head)
      layers [#layers + 1] = head
      for _, v in ipairs (l) do
        if v [#v] == head then
          v [#v] = nil
        end
      end
      local i = 1
      repeat
        if # (l [i]) == 0 then
          table.remove (l, i)
        else
          i = i + 1
        end
      until i > #l
      --[[
      do
        local dump = {}
        for i, v in ipairs (layers) do
          dump [i] = {}
          for j, w in ipairs (v) do
            dump [i] [j] = tostring (w)
          end
        end
        print ("layers:", serpent.dump (dump))
      end
      --]]
    end
    for i = 1, #layers / 2 do
      layers [i], layers [#layers-i+1] = layers [#layers-i+1], layers [i]
    end
--    print ("layers:", serpent.dump (layers))
    data [LAYERS] = layers
  end
end
--[[
function Data.__call (parents)
  local data = {
    [PARENTS] = parents,
  }
  data [LAYERS] = merge (parents)
  local proxy = {
    [DATA] = data,
  }
  return setmetatable (proxy, Data)
end
--]]

local function class (name, parents)
  local data = setmetatable ({
    [PARENTS] = parents or {},
  }, {
    __tostring = function (x) return name end,
  })
  print ("===== " .. tostring (data) .. " =====")
  c3 (data)
  print ("parents:", serpent.dump (data [PARENTS]))
  print ("layers :", serpent.dump (data [LAYERS ]))
  return data
end

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