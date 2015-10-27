local Serpent = require "serpent"

--[[

local lines = {
  luaH_zet = 13,
  luaH_set = 10,
  luaH_get = 24,
  luaH_present = 48,
}
local lines = {
  luaH_set = { "int", true},
  luaH_get = { "bool", false},
  luaH_present = { "float", true},
}

]]

--[==[

local lines = {
  luaH_set = { "int", true},
  luaH_get = { "bool", false},
  luaH_present = { "float", true},
  luaH_get = { "long", false},
}

print ("lines1 :\n",Serpent.dump(lines))
local a={}
print ("a1 :\n",Serpent.dump(a))
for n in pairs(lines) do table.insert(a, n) end
print ("before sort : a2 :\n",Serpent.dump(a))

table.sort(a)
for i,n in ipairs(a) do print (n) end
print ("after sort :a3 :\n",Serpent.dump(a))




local function apha_sort (opt)
--  print ("before sort : array :\n",opt)
  print ("\ninside apha_sort : opt :\n",Serpent.dump(opt))
end

local lines = {
  luaH_set = { "int", true},
  luaH_get = { "bool", false},
  luaH_present = { "float", true},
}

apha_sort (lines)

--for parameter, x in pairs (subt) do
  --Options.set (command, part, parameter, x.type, x.description)
--end

]==]

print ("\n--------------------\n")
print ("\n--------------------\n")
print ("\n--------------------\n")


local function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

local lines = {
  luaH_set = { "int", true},
  luaH_get = { "bool", false},
  luaH_present = { "float", true},
}

for name, line in pairsByKeys(lines) do
  print (name,Serpent.dump(line))
   -- print(name, line)
end
