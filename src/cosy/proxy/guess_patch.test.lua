local assert = require "luassert"
local path   = require "cosy.proxy.remember_path"
local guess  = require "cosy.proxy.guess_patch"
local tags   = require "cosy.util.tags"
local PATH   = tags.PATH
local NAME   = tags.NAME

local function make (value)
  return guess (path (value))
end

do
  local data = {
  }
  local t = {}
  local p = make (data)
  p.x = {
    a = t,
    b = {
      y = t,
    },
  }
  p [p.b] = true
end

