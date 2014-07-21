local proxy    = require "cosy.util.proxy"
local tags     = require "cosy.util.tags"
local is_proxy = require "cosy.util.is_proxy"
local _, PATH = require "cosy.proxy.path"
local raw = require "cosy.util.raw"

local DATA = tags.DATA

local guess_patch = proxy ()

local function path_of (path)
  local result
  for i, p in ipairs (path) do
    if i == 1 then
      result = "${base}" -- p [NAME]
    elseif type (p) == "string" then
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
  elseif type (value) == "table" then
    return "{}"
  else
    assert (false)
  end
end

local function perform (new_value, old_value, seen)
  local key_path   = new_value [PATH]
  assert (key_path and #key_path ~= 0)
--  if #self_path < 2 then
--    return
--  end
--  local model = self_path [1] [self_path [2]]
  local viewed = seen [old_value]
  seen [old_value] = new_value
  local patch_str = path_of (key_path) .. " = "
  if viewed then
    patch_str = patch_str .. path_of (viewed [PATH])
print (patch_str)
  elseif is_proxy (old_value) then
    patch_str = patch_str .. path_of (old_value [PATH])
print (patch_str)
  else
    patch_str = patch_str .. value_of (old_value)
print (patch_str)
    if type (old_value) == "table" then
      for k, v in pairs (raw (new_value)) do
        perform (new_value [k], v, seen)
      end
    end
  end
end

function guess_patch:__newindex (key, value)
  local below = self [DATA]
  below [key] = value
  perform (self [key], value, {})
end

return guess_patch
