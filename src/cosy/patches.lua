local Patches    = {}
local patches_mt = {}
local ids_mt     = { __mode = "v" }

Patches.__index = Patches

function Patches.new ()
  return setmetatable ({
    patches = setmetatable ({}, patches_mt),
    ids     = setmetatable ({}, ids_mt    ),
  }, Patches)
end

function Patches:insert (p)
  assert (type (p) == "table")
  local ids     = self.ids
  local patches = self.patches
  patches [#patches + 1] = p
  p.id = #ids + 1
  ids [#ids + 1] = p
  return p
end

return Patches
