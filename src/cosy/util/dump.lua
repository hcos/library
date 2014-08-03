local raw           = require "cosy.util.raw"
local map           = require "cosy.util.map"
local tags          = require "cosy.util.tags"
local path_of       = require "cosy.util.path_of"
local value_of      = require "cosy.util.value_of"
local is_tag        = require "cosy.util.is_tag"
local rawify        = require "cosy.proxy.rawify"
local remember_path = require "cosy.proxy.remember_path"

local IS_VOLATILE = tags.IS_VOLATILE
local PATH        = tags.PATH

local function dump_data (x, seen, lines)
  local path = x [PATH]
  seen [x] = path
  lines [#lines + 1] = path_of (path) .. " = " ..
                       path_of (path) .. " or {}"
  for k, v in map (x) do
    if not (is_tag (k) and k [IS_VOLATILE]) then
      lines [#lines + 1] = path_of (path .. k) .. " = " ..
                           value_of (v, seen)
      if type (v) == "table" and not seen [v] then
        dump_data (v, seen, lines)
      end
    end
  end
end

local function dump (resource)
  assert (resource [tags.RESOURCE])
  resource = remember_path (raw (resource))
  local lines = {}
  dump_data (resource, rawify {}, lines)
  return table.concat (lines, "\n")
end

return dump
