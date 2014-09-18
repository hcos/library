local assert = require "luassert"
local make   = require "cosy.proxy.rawify"
local raw    = require "cosy.util.raw"

do
  local data = {}
  local p = make (data)
  data.x = p
  assert.are.equal (p, data)
  assert.are.equal (p.x, p)
  assert.are.equal (p.x, data)
  assert.are.equal (data.x, data)
end

do
  local data = {}
  local p = make (data)
  p.x = p
  assert.are.equal (p, data)
  assert.are.equal (p.x, p)
  assert.are.equal (p.x, data)
  assert.are.equal (data.x, data)
end

do
  local data = {}
  local p = make (data)
  p [p] = true
  assert.are.equal (p, data)
  assert.are.equal (data [data], true)
  assert.are.equal (raw (p [p]), true)
end

do
  local mt = {}
  mt.__index = mt
  mt.x = 1
  local data = setmetatable ({}, mt)
  local p = make (data)
  assert.are.equal (p.x, data.x)
  assert.are.equal (p.x, 1)
end
