local assert = require "luassert"
local make   = require "cosy.proxy.remember_path"
local tags   = require "cosy.util.tags"

local PATH   = tags.PATH

do
  local p = make (nil)
  assert.has.error (function () return p.x end)
end

do
  local data = {}
  local p = make (data)
  assert.are.same (p [PATH], { data })
end

do
  local data = {
    some_key = {}
  }
  local p = make (data)
  local q = p.some_key
  assert.are.same (p [PATH], { data })
  assert.are.same (q [PATH], { data, "some_key" })
end

do
  local data = {}
  local p = make (data)
  local NIL = {}
  for _, value in ipairs {
    NIL,
    true,
    0,
    "",
    { "" },
    function () end,
    coroutine.create (function () end),
  } do
    if value == NIL then
      value = nil
    end
    p.some_key = value
    assert.are.same (p [PATH], { data })
    assert.are.equal (p.some_key, value)
  end
end

do
  local data = {}
  local p = make (data)
  local NIL = {}
  for _, value in ipairs {
    NIL,
    true,
    0,
    "",
    { "" },
    function () end,
    coroutine.create (function () end),
  } do
    if value == NIL then
      value = nil
    end
    local q = make (value)
    assert.are.same (p [PATH], { data })
    assert.are.equal (q, value)
  end
end

do
  local data = {}
  local p = make (data)
  local _ = p [tags.TAG]
  assert.has.no.error (function () return p [nil] end)
  assert.has.no.error (function () return p [true] end)
  assert.has.no.error (function () return p [1] end)
  assert.has.no.error (function () return p [""] end)
  assert.has.no.error (function () return p [{""}] end)
  assert.has.no.error (function () return p [function () end] end)
  assert.has.no.error (function () return p [coroutine.create (function () end)] end)
  assert.has.no.error (function () return p [tags.TAG] end)
  assert.has.no.error (function () return p [p] end)
end
