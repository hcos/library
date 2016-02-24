-- These lines are required to correctly run tests:
require "busted.runner" ()
local loader = require "cosy.loader.lua" {
  logto = false,
  alias = "__busted__",
}

local Configuration = loader.load "cosy.configuration"
local File          = loader.load "cosy.file"
local Scheduler     = loader.load "cosy.scheduler"
local Store         = loader.load "cosy.store"

Configuration.load {
  "cosy.redis",
}

describe ("cosy.store", function ()

  setup (function ()
    local data = File.decode (Configuration.redis.data)
    Configuration.redis.interface = data.interface
    Configuration.redis.port      = data.port
  end)

  before_each (function ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      store.redis:flushall ()
    end)
    Scheduler.loop ()
  end)

  it ("can be instantiated", function ()
    Scheduler.addthread (function ()
      local _ = Store.new ()
    end)
    Scheduler.loop ()
  end)

  it ("does not return a missing document", function ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      local view  = Store.toview (store)
      assert.is_nil (view / "a")
    end)
    Scheduler.loop ()
  end)

  it ("returns an iterator, even with no documents", function ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      local view  = Store.toview (store)
      assert.is_not_nil (view * "a")
    end)
    Scheduler.loop ()
  end)

  it ("allows to create a document", function ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      local view  = Store.toview (store)
      local _     = view + "key"
      assert.is_not_nil (view / "key")
    end)
    Scheduler.loop ()
  end)

  it ("allows set fields in a document", function ()
    Scheduler.addthread (function ()
      local store = Store.new ()
      local view  = Store.toview (store)
      local document = view + "key"
      document.field = "value"
      assert.are.equal ((view / "key").field, "value")
    end)
    Scheduler.loop ()
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
    Scheduler.loop ()
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
