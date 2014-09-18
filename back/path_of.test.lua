local assert  = require "luassert"
local path_of = require "cosy.util.path_of"
local tags    = require "cosy.util.tags"

do
  local p = nil
  assert.is_falsy (path_of (p))
end

do
  local p = {}
  assert.is_falsy (path_of (p))
end

do
  local root = {
    [tags.NAME] = "root"
  }
  do
    local p = { root, true }
    assert.are.equal (path_of (p), "root [true]")
  end
  do
    local p = { root, 1 }
    assert.are.equal (path_of (p), "root [1]")
  end
  do
    local p = { root, "an_identifier" }
    assert.are.equal (path_of (p), 'root.an_identifier')
  end
  do
    local p = { root, "some words" }
    assert.are.equal (path_of (p), 'root [ "some words" ]')
  end
  do
    local p = { root, [["']] }
    assert.are.equal (path_of (p),
      "root [ [[" .. [["']].. "]] ]")
  end
  do
    local p = { root }
    assert.are.equal (path_of (p), "root")
  end
  do
    local p = { root, tags.NAME }
    assert.are.equal (path_of (p), "root [tags.NAME]")
  end
  do
    assert.has.error (function ()
      return path_of ({ "a" })
    end)
    assert.has.error (function ()
      return path_of ({ function () end })
    end)
    assert.has.error (function ()
      return path_of ({ coroutine.create (function () end) })
    end)
  end
end
