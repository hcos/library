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

function Patches:push (p)
  assert (type (p) == "table")
  local ids     = self.ids
  local patches = self.patches
  patches [#patches + 1] = p
  p.id = #ids + 1
  ids [#ids + 1] = p
  return p
end

function Patches:pop ()
  local ids      = self.ids
  local patches  = self.patches
  local patch    = patches [1]
  ids [patch.id] = nil
  table.remove (patches, 1)
end

function Patches:__ipairs ()
  return coroutine.wrap (
    function ()
      for i, p in ipairs (self.patches) do
        coroutine.yield (i, p)
      end
    end
  )
end

function Patches:__len ()
  return #(self.patches)
end

function Patches:__index (n)
  if type (n) == "number" then
    return self.patches [n]
  else
    return Patches [n]
  end
end

function Patches:__newindex ()
  assert (false)
end

return Patches
