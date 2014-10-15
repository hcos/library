local assert    = require "luassert"
local Data      = require "cosy.data"
local Algorithm = require "cosy.algorithm"

-- map
do
  local data = Data.new {
    [1] = "one",
    [2] = "two",
    [3] = false,
    [5] = true,
    a   = "three",
    b   = "four",
    z   = false,
  }
  local keys   = {}
  for k, v in Algorithm.map (data) do
    keys   [k] = true
    assert.are.equal (data [k], v)
  end
  assert.are.same (keys, {
    [1] = true,
    [2] = true,
    [3] = true,
    [5] = true,
    a   = true,
    b   = true,
    z   = true,
  })
end

-- seq
do
  local data = Data.new {
    [1] = "one",
    [2] = "two",
    [3] = false,
    [5] = true,
    a   = "three",
    b   = "four",
    z   = false,
  }
  local values = {}
  for _, v in Algorithm.seq (data) do
    values [#values + 1] = v
  end
  assert.are.same (values, {
    data [1], data [2], data [3]
  })
end

-- set
do
  local data = Data.new {
    [1] = "one",
    [2] = "two",
    [3] = false,
    [5] = true,
    a   = "three",
    b   = "four",
    z   = false,
  }
  local keys = {}
  for k, v in Algorithm.set (data) do
    keys [k] = true
    assert.are.equal (data [k], v)
  end
  assert.are.same (keys, {
    [5  ] = true,
  })
end

-- reversed
do
  local data = Data.new {
    [1] = "one",
    [2] = "two",
    [3] = false,
    [5] = true,
    a   = "three",
    b   = "four",
    z   = false,
  }
  local values = {}
  for _, v in Algorithm.reversed (Algorithm.seq (data)) do
    values [#values + 1] = v
  end
  assert.are.same (values, {
    data [3], data [2], data [1]
  })
end

-- sorted
do
  local data = Data.new {
    [1] = "one",
    [2] = "two",
    [3] = false,
    [5] = true,
    a   = "three",
    b   = "four",
    z   = false,
  }
  local keys   = {}
  for k, v in Algorithm.sorted (Algorithm.map (data)) do
    keys [#keys   + 1] = k
    assert.are.equal (data [k], v)
  end
  assert.are.same (keys, {
    1, 2, 3, 5, "a", "b", "z",
  })
end

-- filtered
do
  local data = Data.new {
    [1] = "one",
    [2] = "two",
    [3] = false,
    [5] = true,
    a   = "three",
    b   = "four",
    z   = false,
  }
  local function filter (k, v)
    return k ~= 3
  end
  local keys   = {}
  for k, v in Algorithm.filtered (Algorithm.map (data), filter) do
    keys [k] = true
    assert.are.equal (data [k], v)
  end
  assert.are.same (keys, {
    [1]   = true,
    [2]   = true,
    [5]   = true,
    ["a"] = true,
    ["b"] = true,
    ["z"] = true,
  })
end
