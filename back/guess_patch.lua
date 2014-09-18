local proxy     = require "cosy.util.proxy"
local tags      = require "cosy.util.tags"
local is_proxy  = require "cosy.util.is_proxy"
local is_tag    = require "cosy.util.is_tag"
local map       = require "cosy.util.map"
local container = require "cosy.util.container"
local path_of   = require "cosy.util.path_of"
local value_of  = require "cosy.util.value_of"

local PATH    = tags.PATH
local PATCHES = tags.PATCHES
local IS_VOLATILE = tags.IS_VOLATILE

local guess_patch = proxy ()

local forward = guess_patch.__newindex

local function perform (self, key, new_value, old_value, seen)
  if self [IS_VOLATILE] then
    return
  end
  local key_path  = self [PATH] .. key
  local viewed    = seen [new_value]
  local recursive = false
  local patch_str = path_of (key_path) .. " = "
  if viewed then
    patch_str = patch_str .. path_of (viewed)
  elseif is_proxy (new_value) then
    patch_str = patch_str .. path_of (new_value [PATH])
  else
    patch_str = patch_str .. (value_of (new_value, seen) or "{}")
    recursive = type (new_value) == "table" and not is_tag (new_value)
  end
  local model = key_path [1]
  if model then
    local patches = model [PATCHES]
    patches [#patches + 1] = {
      status  = "applied",
      code    = patch_str,
      unapply = function () self [key] = old_value end,
    }
  end
  if type (new_value) == "table" and not viewed then
    seen [new_value] = key_path
  end
  if recursive then
    for k, v in map (new_value) do
      perform (self [key], k, v, nil, seen)
    end
  end
end

function guess_patch:__newindex (key, value)
  local old_value = self [key]
  forward (self, key, value)
  perform (self, key, value, old_value, container {})
end

return guess_patch
