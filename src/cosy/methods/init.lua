if _G.js then
  error "Not available"
end

return function (loader)

  local Configuration = loader.load "cosy.configuration"

  Configuration.load {
    "cosy.methods",
  }

  local Methods  = {}

  Methods.server  = loader.load "cosy.methods.server"
  Methods.user    = loader.load "cosy.methods.user"
  Methods.project = loader.load "cosy.methods.project"

  for id in pairs (Configuration.resource.project ["/"]) do
    local module = loader.require ("cosy.methods.resource" % {
      id = id,
    })
    Methods [id] = module (loader, id)
  end

  return Methods

end
