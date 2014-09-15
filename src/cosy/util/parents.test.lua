local assert  = require "luassert"
local parents = require "cosy.util.parents"
local tags    = require "cosy.util.tags"

local TYPE       = tags.TYPE
local PROTOTYPES = tags.PROTOTYPES

local data = {
  t1 = {},
  t2 = {},
  t3 = {},
  t  = {},
  x  = {},
}

data.x [TYPE] = data.t
data.t [PROTOTYPES] = {
  [data.t2] = true,
  [data.t3] = true,
}
data.t2 [PROTOTYPES] = {
  [data.t1] = true,
}
data.t3 [PROTOTYPES] = {
  [data.t1] = true,
}

do
  local s = {}
  for x in parents (data.t1) do
    s [x] = true
  end
  assert.are.same (s, {
    [data.t1] = true,
  })
end

do
  local s = {}
  for x in parents (data.t2) do
    s [x] = true
  end
  assert.are.same (s, {
    [data.t1] = true,
    [data.t2] = true,
  })
end

do
  local s = {}
  for x in parents (data.t3) do
    s [x] = true
  end
  assert.are.same (s, {
    [data.t1] = true,
    [data.t3] = true,
  })
end

do
  local s = {}
  for x in parents (data.t) do
    s [x] = true
  end
  assert.are.same (s, {
    [data.t1] = true,
    [data.t2] = true,
    [data.t3] = true,
    [data.t ] = true,
  })
end

do
  local s = {}
  for x in parents (data.x) do
    s [x] = true
  end
  assert.are.same (s, {
    [data.t1] = true,
    [data.t2] = true,
    [data.t3] = true,
    [data.t ] = true,
    [data.x ] = true,
  })
end
