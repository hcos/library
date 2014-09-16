-- Calque Data
-- ===========
--
-- (calque = tracing paper = layers)
--
-- In CosyVerif, we store, manipulate and exchange data, not objects.
-- These data have been represented as CAMI and FML/GrML in previous
-- versions. In the current version, they are represented as Lua values.
--
-- Data can be atomic values (Booleans, numbers, strings, functions) or
-- tables containing other data. When a data is a function, is should not
-- be considered as a method. It is *really* a just a function.
--
-- Proposal
-- ========
--
-- We use an approach similar to the use tracing paper.
-- Because things can only be built by addition, we can build a formalism or
-- model by putting all the tracing papers together. The final data is the
-- one obtained from all of the parts.
--
-- For instance, the example below shows in `result` the resulting data
-- obtained by merging `t1`, `t2` and `t3`.

do
  local t1 = {
    x = {
      a = 1,
    },
  }
  local t2 = {
    x = {
      b = 2,
    },
    y = true,
  }
  local t3 = {
    z = false,
  }
  local result = {
    x = {
      a = 1,
      b = 2,
    },
    y = true,
    z = false,
  }
end

-- CosyVerif allows to specify types and instances. The layers must be
-- extended to handle them. The example below shows an instance `i` created
-- from a type `t`. The `extends` field gives us the extended types. The
-- merge of all layers is shown in `result.i`.

do
  local m = {
    t = {
      x = {
        c = 3,
      },
    },
  }
  local model = {
    extends = { m },
    t = {
      x = {
        a = 1,
      },
      y = {
        z = true,
      },
    }
  }
  model.i = {
    extends = { model.t },
    x = {
      b = 2,
    },
  }
  local result = {
    extends = { m },
    t = {
      x = {
        a = 1,
        c = 3,
      },
      y = {
        z = true,
      },
    },
    i = {
      extends = { model.t },
      x = {
        a = 1,
        b = 2,
        c = 3,
      },
      y = {
        z = true,
      },
    },
  }
end

-- Note that:
-- * `a = 1` comes from `model.i`;
-- * `b = 2` comes from `model.t`;
-- * `c = 3` comes from `m.t` that is imported by `model.t`;
-- * `y = { z = true }` comes from `model.t`.
--
-- Although `model.t` does not specify that is extends `m.t`, it is the case
-- because `model` extends `m` and `t` is a field in both.
-- This behavior allows to specify the extension only where it is really
-- required, thus improving readability (this can be discussed, but in big
-- examples, it Data.news a clear difference).

-- Access Rules
-- ------------
--
-- We need a very simple rule to define how to merge layers.
-- The `value` function computes the value of any leaf in the data.
--
-- **Question:** what should `value` return for non leaves?

local PATH    = {}
local PARENTS = {}
local VALUE   = {}

-- Data
-- ----

local Data = {}

function Data.new (x)
  return setmetatable ({
    [PATH] = { x }
  }, Data)
end

function Data:__tostring ()
  local path = self [PATH]
  local result = "@" .. tostring (path [1]):sub (8)
  for i = 2, #path do
    result = result .. "." .. tostring (path [i])
  end
  return result
end

function Data:__index (key)
  local path = {}
  for _, x in ipairs (self [PATH]) do
    path [#path + 1] = x
  end
  path [#path + 1] = key
  return setmetatable ({
    [PATH] = path
  }, Data)
end

function Data:__newindex (key, value)
  local path = self [PATH]
  local data = path [1]
  for i = 2, #path do
    local k = path [i]
    if not data [k] then
      data [k] = {}
    end
    data = data [k]
  end
  data [key] = value
end

-- Value
-- -----

local function value (x)
  local path = x [PATH]
  local TABLE = {}
  local function _value (data, i)
    if not data then
      return nil
    end
    local key = path [i]
    if key then
      assert (type (data) == "table")
      local subdata = data [key]
      local result  = _value (subdata, i + 1)
      if result then
        return result
      end
    else
      if type (data) == "table" then
        if getmetatable (data) == Data then
          return data
        else
          return data [VALUE]
        end
      end
      return data
    end
    for _, subpath in ipairs (data [PARENTS] or {}) do
      for j = i, #path do
        subpath = subpath [path [j]]
      end
      local result = value (subpath)
      if result then
        return result
      end
    end
    return nil
  end
  local result = _value (path [1], 2)
  if result == TABLE then
    return x
  else
    return result
  end
end

-- Test
-- ----

do
  local m = Data.new {
    t = {
      x = {
        c = 3,
      },
    },
  }
  local model = Data.new {
    [PARENTS] = { m },
    t = {
      x = {
        a = 1,
      },
      y = {
        z = true,
      },
      z = m.t,
    },
  }
  model.i = {
    [PARENTS] = { model.t },
    x = {
      b = 2,
    },
    y = {
      [VALUE] = 5,
    },
  }
  print (tostring (model.i.x.a) .. " = " .. tostring (value (model.i.x.a)))
  print (tostring (model.i.x.b) .. " = " .. tostring (value (model.i.x.b)))
  print (tostring (model.i.x.c) .. " = " .. tostring (value (model.i.x.c)))
  print (tostring (model.i.x  ) .. " = " .. tostring (value (model.i.x  )))
  print (tostring (model.i.y  ) .. " = " .. tostring (value (model.i.y  )))
  print (tostring (model.i.z  ) .. " = " .. tostring (value (model.i.z  )))
end

-- Other Problems
-- ==============
--
-- We should handle access rights (read-only or read-write).
-- This can easily be done by adding a proxy over data.
