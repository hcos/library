local tags      = require "cosy.lang.tags"
local type      = require "cosy.util.type"
local raw       = require "cosy.lang.data" . raw
local map       = require "cosy.lang.iterators" . map
local is_empty  = require "cosy.lang.iterators" . is_empty

local PARENTS = tags.PARENTS

local function update (data)
  if not type (data) . table then
    return
  end
  for key, value in map (data) do
    local parents = value [PARENTS]
    if not parents then
      value [PARENTS] = {}
    end
    if not parents [data] then
      parents [data] = {}
    end
    if not parents [data] [key] then
      parents [data] [key] = true
      update (value)
    end
  end
end


local function handler (data, key)
  if key == PARENTS then
    return
  end
  local raw_data = raw (data)
  --
  local old_value = data [key]
  if type (old_value) . table then
    local old_parents = old_value [PARENTS] or {}
    local ks = old_parents [raw_data] or {}
    ks [key] = nil
    if is_empty [ks] then
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
  --
  local new_value = data [key]
  if type (new_value) . table then
    update (new_value)
    local new_parents = new_value [PARENTS] or {}
    if not new_parents [raw_data] then
      new_parents [raw_data] = {}
    end
    new_parents [raw_data] [key] = true
    new_value [PARENTS] = new_parents
  end
end

return handler
