local assert   = require "luassert"
local value_of = require "cosy.util.value_of"
local tags     = require "cosy.util.tags"

do
  local NIL = {}
  for _, value in ipairs {
    NIL,
    true,
    1,
  } do
    if value == NIL then
      value = nil
    end
    assert.are.equal (value_of (value), tostring (value))
  end
end

do
  assert.are.equal (value_of (""), [==[""]==])
  assert.are.equal (value_of ('"'), [==['"']==])
  assert.are.equal (value_of ("'"), [==["'"]==])
  assert.are.equal (value_of ([==["']==]), [==[[["']]]==])
  assert.are.equal (value_of ([==[[["']==]), [==[[=[[["']=]]==])
end

do
  assert.are.equal (value_of (tags.TAG), "tags.TAG")
end

do
  local t = {}
  local seen = {}
  assert.is_falsy (value_of (t))
  assert.is_falsy (value_of (t, seen))
  seen [t] = { { [tags.NAME] = "x" }, "a", "b" }
  assert.are.equal (value_of (t, seen), "x.a.b")
end

do
  local value = function () end
  assert.has.no.error (function () return value_of (value) end)
end

do
  local value = coroutine.create (function () end)
  assert.has.error (function () return value_of (value) end)
end
