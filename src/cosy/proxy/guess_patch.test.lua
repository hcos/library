local assert = require "luassert"
local path   = require "cosy.proxy.remember_path"
local guess  = require "cosy.proxy.guess_patch"
local tags   = require "cosy.util.tags"
local raw    = require "cosy.util.raw"

local function make (value)
  return guess (path (value))
end

do
  local root = make {
    [tags.NAME] = "root",
  }
  root.model = {}
  root.model = {
    [tags.PATCHES] = {},
  }
  local t = {}
  root.model.a = 1
  root.model.x = {
    a = t,
    b = {
      y = t,
    },
  }
  root.model [root.model.b] = true
  --[[
  --]]
end
