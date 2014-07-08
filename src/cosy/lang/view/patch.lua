-- Patching Mechanism
-- ==================
--
-- A patch is a function that updates a model. It can change values within
-- the model, but also extend its formalism.
--
-- When applying a patch, we need to create a function to unapply it.
-- This function simply replays in reverse order the changes that have been
-- applied on the data.

local tags = require "cosy.lang.tags"

-- Patches are stored per model. Unpatches are also stored in the same way.
-- Structure:
--
-- cosy.model.patches: sequence of patches + unpatches

local handler_mt = {}

function handler_mt:__call (data, key)
  if type (key) . tag and not key.persistent then
    return
  end
  local patch = self.patch
  patch.unpatch = {}
  patch.unpatch.data  = data
  patch.unpatch.key   = key
  patch.unpatch.value = data [key]
end

return function (patch)
  return setmetatable ({}, handler_mt)
end
