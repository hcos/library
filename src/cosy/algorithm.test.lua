local assert    = require "luassert"
local Algorithm = require "cosy.algorithm"

-- map
do
  local data = {
    [1] = "one",
    [2] = "two",
    [3] = false,
    [5] = true,
    a   = "three",
    b   = "four",
    z   = false,
  }
  local keys = {}
  local values = {}
  for k, v in Algorithm.map (data) do
    keys [k] = true
    values [v] = true
  end
  assert.are.same (keys, {
    [1]   = true,
    [2]   = true,
    [3]   = true,
    [5]   = true,
    ["a"] = true,
    ["b"] = true,
    ["z"] = true,
  })
  assert.are.same (values, {
    ["one"  ] = true,
    ["two"  ] = true,
    ["three"] = true,
    ["four" ] = true,
    [false  ] = true,
    [true   ] = true,
  })
end

-- seq
do
  local data = {
    [1] = "one",
    [2] = "two",
    [3] = false,
    [5] = true,
    a   = "three",
    b   = "four",
    z   = false,
  }
  local values = {}
  for v in Algorithm.seq (data) do
    values [#values + 1] = v
  end
  assert.are.same (values, {
    "one", "two", false,
  })
end

-- set
do
  local data = {
    [1] = "one",
    [2] = "two",
    [3] = false,
    [5] = true,
    a   = "three",
    b   = "four",
    z   = false,
  }
  local keys = {}
  for k in Algorithm.set (data) do
    keys [k] = true
  end
  assert.are.same (keys, {
    [1  ] = true,
    [2  ] = true,
    [5  ] = true,
    ["a"] = true,
    ["b"] = true,
  })
end
