-- `proxy`
-- =======
--
local assert = require "luassert"
local proxy  = require "cosy.util.proxy"
local tags   = require "cosy.util.tags"
local raw    = require "cosy.util.raw"

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
    local value = {}
    local p = proxy { read_only = true}
    local o = p (value)
    assert.has.error (function () o [1] = true end)
  end
  do
    local value = {}
    local p = proxy { read_only = false }
    local o = p (value)
    assert.has.no.error (function () o [1] = true end)
    assert.are.same (value, { true })
  end
  do
    local data = {
      x = {}
    }
    local p = proxy ()
    assert.are.equal (getmetatable (p (data) . x), p)
  end
end


