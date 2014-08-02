-- `proxy`
-- =======
--
local assert = require "luassert"
local proxy  = require "cosy.util.proxy"
local tags   = require "cosy.util.tags"
local raw    = require "cosy.util.raw"
local ignore = require "cosy.util.ignore"

do
  local NIL = {}
  for _, value in ipairs {
    NIL,
    true,
    0,
    "",
    function () end,
    coroutine.create (function () end),
  } do
    if value == NIL then
      value = nil
    end
    --
    local make = proxy ()
    assert.has.no.error (function () make (value) end)
    -- 
    local result = make (value)
    assert.are.equal (result, value)
  end
end

do
  local DATA  = tags.DATA
  for _, value in ipairs {
    {""}
  } do
    local p = proxy ()
    assert.has.no.error (function () p (value) end)
    local o = p (value)
    assert.are.equal (raw (o), value)
    assert.are.equal (rawget (o, DATA), value)
    assert.are.equal (tostring (o), tostring (value))
    local ok, size = pcall (function () return # value end)
    if ok then
      assert.has.no.error (function () return # o end)
      assert.are.equal (# o , size)
    end
    assert.has.no.error (function () return o [1] end)
    assert.has.no.error (function () o [1] = true end)
    local p1 = proxy ()
    local p2 = proxy ()
    local r = p1 (p2 (value))
    assert.are.equal (getmetatable (r), p1)
    assert.are.equal (getmetatable (rawget (r, DATA)), p2)
    assert.are.equal (rawget (rawget (r, DATA), DATA), value)
    assert.are.equal (r, o)
    assert.are.equal (o, r)
  end
  do
    local data = {
      x = {}
    }
    local p = proxy ()
    assert.are.equal (getmetatable (p (data) . x), p)
  end
  do
    local mt = {}
    local value = setmetatable ({}, mt)
    local p = proxy ()
    local o = p (value)
    assert.has.error (function () return o ()   end)
    assert.has.error (function () return -o     end)
    assert.has.error (function () return o + 1  end)
    assert.has.error (function () return o - 1  end)
    assert.has.error (function () return o * 1  end)
    assert.has.error (function () return o / 1  end)
    assert.has.error (function () return o % 1  end)
    assert.has.error (function () return o ^ 1  end)
    assert.has.error (function () return o .. 1 end)
  end
  do
    local mt = {
      __call   = function () return "ok" end,
      __unm    = function () return "ok" end,
      __add    = function () return "ok" end,
      __sub    = function () return "ok" end,
      __mul    = function () return "ok" end,
      __div    = function () return "ok" end,
      __mod    = function () return "ok" end,
      __pow    = function () return "ok" end,
      __concat = function () return "ok" end,
    }
    local value = setmetatable ({}, mt)
    local p = proxy ()
    local o = p (value)
    assert.has.no.error (function () return o ()   end)
    assert.has.no.error (function () return -o     end)
    assert.has.no.error (function () return o + 1  end)
    assert.has.no.error (function () return o - 1  end)
    assert.has.no.error (function () return o * 1  end)
    assert.has.no.error (function () return o / 1  end)
    assert.has.no.error (function () return o % 1  end)
    assert.has.no.error (function () return o ^ 1  end)
    assert.has.no.error (function () return o .. 1 end)
    assert.are.equal (o ()  , "ok")
    assert.are.equal (-o    , "ok")
    assert.are.equal (o + 1 , "ok")
    assert.are.equal (o - 1 , "ok")
    assert.are.equal (o * 1 , "ok")
    assert.are.equal (o / 1 , "ok")
    assert.are.equal (o % 1 , "ok")
    assert.are.equal (o ^ 1 , "ok")
    assert.are.equal (o .. 1, "ok")
  end
  do
    local mt = {
      __call   = function () return "ok" end,
      __unm    = function () return "ok" end,
      __add    = function () return "ok" end,
      __sub    = function () return "ok" end,
      __mul    = function () return "ok" end,
      __div    = function () return "ok" end,
      __mod    = function () return "ok" end,
      __pow    = function () return "ok" end,
      __concat = function () return "ok" end,
    }
    local value = setmetatable ({}, mt)
    local p = proxy ()
    local o = p (value)
    assert.has.no.error (function () return o ()   end)
    assert.has.no.error (function () return -o     end)
    assert.has.no.error (function () return 1 + o  end)
    assert.has.no.error (function () return 1 - o  end)
    assert.has.no.error (function () return 1 * o  end)
    assert.has.no.error (function () return 1 / o  end)
    assert.has.no.error (function () return 1 % o  end)
    assert.has.no.error (function () return 1 ^ o  end)
    assert.has.no.error (function () return 1 .. o end)
    assert.are.equal (o ()  , "ok")
    assert.are.equal (-o    , "ok")
    assert.are.equal (1 + o , "ok")
    assert.are.equal (1 - o , "ok")
    assert.are.equal (1 * o , "ok")
    assert.are.equal (1 / o , "ok")
    assert.are.equal (1 % o , "ok")
    assert.are.equal (1 ^ o , "ok")
    assert.are.equal (1 .. o, "ok")
  end
  do
    local mt = {
    }
    local v = setmetatable ({}, mt)
    local w = setmetatable ({}, mt)
    local p = proxy ()
    local p1 = p (v)
    local p2 = p (v)
    local p3 = p (w)
    assert.are.equal (p1, p2)
    assert.are_not.equal (p1, p3)
  end
  do
    local mt = {
      __eq = function () return true end,
      __lt = function () return true end,
      __le = function () return true end,
    }
    local value = setmetatable ({}, mt)
    local p = proxy ()
    assert.has.no.error (function () return p (value) end)
    local o1 = p (value)
    local o2 = p (value)
    assert.has.no.error (function () return value == o1 end)
    assert.has.no.error (function () return value <  o1 end)
    assert.has.no.error (function () return value <= o1 end)
    assert.is_true (value == o1)
    assert.is_true (value <  o1)
    assert.is_true (value <= o1)
    assert.has.no.error (function () return o1 == value end)
    assert.has.no.error (function () return o1 <  value end)
    assert.has.no.error (function () return o1 <= value end)
    assert.is_true (o1 == value)
    assert.is_true (o1 <  value)
    assert.is_true (o1 <= value)
    assert.has.no.error (function () return o1 == o2 end)
    assert.has.no.error (function () return o1 <  o2 end)
    assert.has.no.error (function () return o1 <= o2 end)
    assert.is_true (o1 == o2)
    assert.is_true (o1 <  o2)
    assert.is_true (o1 <= o2)
  end
end

do
  local stack = {}
  local p1 = proxy ()
  local p1_mt = getmetatable (p1)
  local p1_forward = p1_mt.__call
  p1_mt.__call = function (self, x)
    stack [#stack + 1] = "p1"
    return p1_forward (self, x)
  end
  local p2 = proxy ()
  local p2_mt = getmetatable (p2)
  local p2_forward = p2_mt.__call
  p2_mt.__call = function (self, x)
    stack [#stack + 1] = "p2"
    return p2_forward (self, x)
  end
  local f1 = function (x)
    stack [#stack + 1] = "f1"
    return x
  end
  local f2 = function (x)
    stack [#stack + 1] = "f2"
    return x
  end
  local w1 = p1 .. p2
  ignore (w1)
  local w2 = f1 .. p1
  ignore (w2)
  local w3 = p1 .. f1
  ignore (w3)
  local w4 = f1 .. p1 .. p2 .. f2
  assert.are.equal (#stack, 0)
  w4 (1)
  assert.are.equal (#stack, 4)
  assert.are.equal (stack [1], "f2")
  assert.are.equal (stack [2], "p2")
  assert.are.equal (stack [3], "p1")
  assert.are.equal (stack [4], "f1")
end
