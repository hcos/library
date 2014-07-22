local proxy    = require "cosy.util.proxy"
local tags     = require "cosy.util.tags"
local is_proxy = require "cosy.util.is_proxy"
local is_tag   = require "cosy.util.is_tag"
local map      = require "cosy.util.map"
local seq      = require "cosy.util.seq"
local raw      = require "cosy.util.raw"

local PATH    = tags.PATH
local PATCHES = tags.PATCHES
local NAME    = tags.NAME

local guess_patch = proxy ()

local forward = guess_patch.__newindex

local function path_of (path)
  local result
  for p in seq (path) do
    if type (p) == "string" then
      local i, j = string.find (p, "[_%a][_%w]*")
      if i == 1 and j == #p then
        result = result .. "." .. p
      else
        result = result .. "['" .. p .. "']"
      end
    elseif type (p) == "number" then
      result = result .. "[" .. tostring (p) .. "]"
    elseif type (p) == "boolean" then
      result = result .. "[" .. tostring (p) .. "]"
    elseif type (p) == "table" and is_tag (p) then
      result = result .. "[tags." .. p [NAME] .. "]"
    elseif type (p) == "table" and not result then
      result = tostring (p [NAME])
    elseif type (p) == "table" then
      result = result .. "[" .. path_of (p [PATH]) .. "]"
    else
      assert (false)
    end
  end
  return result
end

local function value_of (value)
  if value == nil then
    return "nil"
  elseif type (value) == "string" then
    return  "[[" .. value .. "]]"
  elseif type (value) == "number" then
    return tostring (value)
  elseif type (value) == "boolean" then
    return tostring (value)
  elseif type (value) == "table" and is_tag (value) then
    return "tags." .. value [NAME]
  elseif type (value) == "table" then
    return "{}"
  else
    assert (false)
  end
end

local function perform (self, key, old_value, seen)
  if is_tag (key) and not key.is_persistent then
    return
  end
  local new_value = self [key]
  local key_path  = new_value [PATH]
  assert (key_path and #key_path ~= 0)
  print (#key_path)
  local viewed
  local raw_old_value = raw (old_value)
  if type (raw_old_value) == "table" then
    viewed = seen [raw_old_value]
    seen [raw_old_value] = new_value
  end
  local recursive = false
  local patch_str = path_of (key_path) .. " = "
  if viewed then
    patch_str = patch_str .. path_of (viewed [PATH])
  elseif is_proxy (old_value) then
    patch_str = patch_str .. path_of (old_value [PATH])
  else
    patch_str = patch_str .. value_of (old_value)
    recursive = type (old_value) == "table" and not is_tag (old_value)
  end
  print (patch_str)
  local model = key_path [1] [raw (key_path [2])]
  print (raw (model))
  if model and #key_path > 2 then
    local patches = model [PATCHES]
    print (raw (patches))
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
  forward (self, key, value)
  if not is_tag (self) or raw (self).is_persistent then
    perform (self, key, value, {})
  end
end

return guess_patch
