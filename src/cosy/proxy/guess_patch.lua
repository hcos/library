local proxy    = require "cosy.util.proxy"
local tags     = require "cosy.util.tags"
local is_proxy = require "cosy.util.is_proxy"
local is_tag   = require "cosy.util.is_tag"
local map      = require "cosy.util.map"
local rawify   = require "cosy.proxy.rawify"
local path_of  = require "cosy.util.path_of"
local value_of = require "cosy.util.value_of"

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
  if type (new_value) == "table" and not viewed then
    seen [new_value] = key_path
  end
  local recursive = false
  local patch_str = path_of (key_path) .. " = "
  if viewed then
    patch_str = patch_str .. path_of (viewed)
  elseif is_proxy (new_value) then
    patch_str = patch_str .. path_of (new_value [PATH])
  else
    patch_str = patch_str .. value_of (new_value, seen)
    recursive = type (new_value) == "table" and not is_tag (new_value)
  end
  local model = key_path [1] [key_path [2]]
  if model and #key_path > 2 then
    local patches = model [PATCHES]
    patches [#patches + 1] = {
      apply   = patch_str,
      unapply = function () self [key] = old_value end,
    }
  end
  if recursive then
    for k, v in map (new_value) do
      perform (new_value, k, v, seen)
    end
  end
end

function guess_patch:__newindex (key, value)
  local old_value = self [key]
  forward (self, key, value)
  local new_value = self [key]
  perform (self, key, new_value, old_value, rawify {})
end

return guess_patch
