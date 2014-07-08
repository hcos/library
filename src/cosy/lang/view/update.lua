local cosy      = require "cosy.lang.cosy"
local raw       = require "cosy.lang.data" . raw
local tags      = require "cosy.lang.tags"
local type      = require "cosy.util.type"
local map       = require "cosy.lang.iterators" . map
local is_empty  = require "cosy.lang.iterators" . is_empty
local serpent   = require "serpent"

local NAME    = tags.NAME
local PARENTS = tags.PARENTS
local UPDATES = tags.UPDATES

local function path_to (data, key)
  local path
  if raw (data) == raw (cosy) then
    path = { cosy }
  elseif type (data) . string then
    path = { data }
  elseif type (data) . number then
    path = { data }
  elseif type (data) . boolean then
    path = { data }
  elseif type (data) . tag then
    path = { cosy, "tags", data [NAME] }
  else
    local parents = data [PARENTS]
    if not parents then
      path = { data, new = true }
    else
      -- Select one parent, ask path to it
      for p, keys in map (parents) do
        for key in pairs (keys) do
          path = path_to (p, key)
        end
      end
    end
  end
  if not key then
    return path
  end
  -- Add key:
  if type (key) . table then
    path [#path + 1] = path_to (key)
  else
    for _, p in ipairs (path_to (key)) do
      path [#path + 1] = p
    end
  end
  return path
end

local function path_for (path)
  if #path == 1 and path.new then
    return "{}"
  end
  local result
  for _, p in ipairs (path) do
    if p == raw (cosy) then
      result = "cosy"
    elseif type (p) . string then
      if result then
        local i, j = string.find (p, "[_%a][_%w]*")
        if i == 1 and j == #p then
          result = result .. "." .. p
        else
          result = result .. " ['" .. p .. "']"
        end
      else
        result = "'" .. p .. "'"
      end
    elseif type (p) . number then
      if result then
        result = result .. " [" .. tostring (p) .. "]"
      else
        result = tostring (p)
      end
    elseif type (p) . boolean then
      if result then
        result = result .. " [" .. tostring (p) .. "]"
      else
        result = tostring (p)
      end
    elseif type (p) . table then
      result = result .. " [" .. path_for (p) .. "]"
    end
  end
  return result
end

function handler (data, key)
  if type (key) . tag and not key.persistent then
    return
  end
  local raw_data = raw (data)
  local raw_key  = raw (key)
  --
  local old_value = raw (data [key])
  if type (old_value) . table and old_value [PARENTS] then
    local old_parents = old_value [PARENTS]
    local ks = old_parents [raw_data] or {}
    ks [raw_key] = nil
    if is_empty (ks) then
      old_parents [raw_data] = nil
    end
    if is_empty (old_parents) then
      old_value [PARENTS] = nil
    else
      old_value [PARENTS] = old_parents
    end
  end
  --
  coroutine.yield ()
  local lhs_path = path_to (data, key)
  local lhs = path_for (lhs_path)
  local rhs_path = path_to (data [key])
  local rhs = path_for (rhs_path)
  if lhs_path [1] == raw (cosy) and #lhs_path > 2 then
    local model = cosy [lhs_path [2]]
    model [UPDATES] = model [UPDATES] or {}
    model [UPDATES] [#(model [UPDATES]) + 1] = lhs .. " = " .. rhs
  end
  --
  local new_value = data [key]
  if type (new_value) . table then
    local new_parents = new_value [PARENTS] or {}
    if not new_parents [raw_data] then
      new_parents [raw_data] = {}
    end
    new_parents [raw_data] [key] = true
    new_value [PARENTS] = new_parents
  end
  --
  if rhs_path.new then
    local r = data [key]
    for k, v in map (r) do
      r [k] = v
    end
  end
end

return handler
