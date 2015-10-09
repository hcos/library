-- These lines are required to correctly run tests:
local Runner = require "busted.runner"
require "cosy.loader"
Runner ()

local Scheduler = require "cosy.scheduler"
local Store     = require "cosy.store"

describe ("cosy.store", function ()

  before_each (function ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      store.redis:flushall ()
    end)
  end)

  it ("can be instantiated", function ()
    Scheduler.addthread (function ()
      local _ = Store.new ()
    end)
  end)

  it ("does not return a missing document", function ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      local view  = Store.toview (store)
      assert.is_nil (view / "a")
    end)
  end)

  it ("returns an iterator, even with no documents", function ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      local view  = Store.toview (store)
      assert.is_not_nil (view * "a")
    end)
  end)

  it ("allows to create a document", function ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      local view  = Store.toview (store)
      local _     = view + "key"
      assert.is_not_nil (view / "key")
    end)
  end)

  it ("allows set fields in a document", function ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      local view  = Store.toview (store)
      local document = view + "key"
      document.field = "value"
      assert.are.equal ((view / "key").field, "value")
    end)
  end)

  it ("stores documents on commit", function ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      local view  = Store.toview (store)
      local document = view + "key"
      document.field = "value"
      Store.commit (store)
    end)
    Scheduler.loop ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      local view  = Store.toview (store)
      assert.are.equal ((view / "key").field, "value")
    end)
  end)

end)

--[==[
Scheduler.addthread (function ()
  local store = Store.new ()
  store.redis:flushall ()
  local view  = Store.toview (store)
  assert (view / "a" == nil) -- does not exist
  assert (view * "a" ~= nil) -- iterator, so not nil
  local a = view + "a" -- creation
  a.field = "value"
  local b = view + "b"
  b.field = "value"
  Store.commit (store)
end)

Scheduler.loop ()

Scheduler.addthread (function ()
  local store = Store.new ()
  local view  = Store.toview (store)
  assert (view / "a")
  assert (view / "b")
  for d in (view * ".*") () do
    print (d)
  end
  local a = view / "a"
  assert (a.field == "value")
  assert (a.other == nil)
  local _ = - a
  local _ = view - "b"
  assert (view / "a" == nil)
  assert (view / "b" == nil)
  Store.cancel (store)
end)

Scheduler.loop ()

Scheduler.addthread (function ()
  local store = Store.new ()
  local view  = Store.toview (store)
  assert (view / "a")
  assert (view / "b")
  local a = view / "a"
  local _ = - a
  local _ = view - "b"
  assert (view / "a" == nil)
  assert (view / "b" == nil)
  Store.commit (store)
end)

Scheduler.loop ()

Scheduler.addthread (function ()
  local store = Store.new ()
  local view  = Store.toview (store)
  assert (view / "a" == nil)
  assert (view / "b" == nil)
end)

Scheduler.loop ()
--]==]
