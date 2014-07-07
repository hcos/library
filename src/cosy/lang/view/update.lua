local cosy      = require "cosy.lang.cosy"

local raw       = require "cosy.lang.data" . raw
local tags      = require "cosy.lang.tags"
local type      = require "cosy.util.type"
local map       = require "cosy.lang.iterators" . map
local serpent   = require "serpent"

local NAME    = tags.NAME
local PARENTS = tags.PARENTS

local function path_to (data, key)
  local path
  if raw (data) == cosy then
    path = { cosy }
  elseif type (data) . string then
    path = { data }
  elseif type (data) . number then
    path = { data }
  elseif type (data) . tag then
    path = { "cosy", "tags", data [NAME] }
  else
    local parents = data [PARENTS]
    if not parents then
      path = { raw (data), new = true }
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
    return serpent.dump (path [1])
  end
  local result
  for _, p in ipairs (path) do
    if p == cosy then
      result = "cosy"
    elseif type (p) . string then
      if result then
        result = result .. " ['" .. p .. "']"
      else
        result = "'" .. p .. "'"
      end
    elseif type (p) . number then
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

local handler_mt = {}
local handler = setmetatable ({
  updates = {}
}, handler_mt)

function handler_mt:__call (data, key)
  if key == tags.PARENTS then
    return
  end
  coroutine.yield ()
  local lhs = path_for (path_to (data, key))
  local rhs = path_for (path_to (data [key]))
  self.updates [#(self.updates) + 1] = lhs .. " = " .. rhs
end

return handler

--[[
observed [#observed + 1] = handler
observed [#observed + 1] = parent


view = observed (cosy)
view.a = 1
view.b = {}

view.b [tags.TAG] = 1
view.d = view.b
view.c = { 1, 2, 3 }
view [view.b] = view.b

print (serpent.block (handler.updates))
--]]
