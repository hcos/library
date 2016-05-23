local Loader = require "cosy.loader.lua" {
  logto = false,
  alias = "examples",
}
local Cosy   = Loader.load "cosy.library"
local data   = {}
local client = assert (Cosy.connect "http://127.0.0.1:8080/", data)

-- Instantiate model:
print ("create", client.model.create {
  project = project_identifier,
  name    = "my-resource",
})

-- List models:
local models = client.server.filter {
  iterator = [[
    return function (coroutine, store)
      for resource in store / "data" * ".*" * ".*" * ".*" do
        if resource.type == "model" then
          coroutine.yield (resource.identifier)
        end
      end
    end
  ]],
}
for identifier in models do
  print (identifier)
end

-- Load model:
local model = client.model.get {
  model = identifier,
}

-- List formalisms:
-- Same as list models, we currently do not have a flag to distinguish them.

-- List services:
-- Same as list models, we currently do not have a flag to distinguish them.
