local assert = require "luassert"
local rawify = require "cosy.proxy.rawify"
local path   = require "cosy.proxy.remember_path"
local guess  = require "cosy.proxy.guess_patch"
local tags   = require "cosy.util.tags"

local make = guess .. path .. rawify

do
  local root = make {
      [tags.NAME] = "root",
      model = {
        [tags.PATCHES] = {
          [tags.IS_VOLATILE] = true,
        },
      },
    }
  local TAG = tags.TAG
  root.model.x = nil

  assert.has.error    (function () root.model [nil] = true end)
  assert.has.no.error (function () root.model.x = nil end)

  assert.has.no.error (function () root.model [true] = true end)
  assert.has.no.error (function () root.model.x = true end)

  assert.has.no.error (function () root.model [1] = true end)
  assert.has.no.error (function () root.model.x = 1 end)

  assert.has.no.error (function () root.model [""] = true end)
  assert.has.no.error (function () root.model.x = "" end)

  assert.has.error    (function () root.model [{""}] = true end)
  assert.has.no.error (function () root.model.x = {""} end)

  assert.has.error    (function () root.model [function () end] = true end)
  assert.has.no.error (function () root.model.x = function () end end)

  assert.has.error    (function () root.model [coroutine.create (function () end)] = true end)
  assert.has.error    (function () root.model.x = coroutine.create (function () end) end)

  assert.has.no.error (function () root.model [tags.TAG] = true end)
  assert.has.no.error (function () root.model.x = tags.TAG end)

  TAG.is_persistent = true
  assert.has.no.error (function () root.model [tags.TAG] = true end)
  assert.has.no.error (function () root.model.x = tags.TAG end)

  assert.has.no.error (function () root.model [root.model] = true end)
  assert.has.no.error (function () root.model.x = root.model end)

  local t = {}
  assert.has.no.error (function () root.model.x = { a = t, b = t } end)
end

do
  local root = make {
      [tags.NAME] = "root",
      model = {
        [tags.PATCHES] = {
          [tags.IS_VOLATILE] = true,
        },
      },
    }
  local t = {}
  t.a = {}
  t.b = t.a
  assert.has.no.error (function () root.model.t = t end)
end
