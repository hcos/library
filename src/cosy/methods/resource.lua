return function (loader, id)

  local Methods  = {}

  local Configuration = loader.load "cosy.configuration"
  local I18n          = loader.load "cosy.i18n"
  local Parameters    = loader.load "cosy.parameters"

  Configuration.load {
    "cosy.methods",
    "cosy.parameters",
  }

  local i18n   = I18n.load {
    "cosy.methods",
    "cosy.library",
    "cosy.parameters",
  }
  i18n._locale = Configuration.locale

  function Methods.create (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
        project        = Parameters.project,
        name           = Parameters.resource.identifier,
      },
    })
    local user    = request.authentication.user
    local project = request.project
    if project.username ~= user.username then
      error {
        _    = i18n ["resource:forbidden"],
        name = request.name,
      }
    end
    local resource = project / request.name
    if resource then
      error {
        _    = i18n ["resource:exist"],
        name = request.name,
      }
    end
    resource             = request.project + request.name
    resource.id          = request.name
    resource.type        = id
    resource.username    = user.username
    resource.projectname = project.projectname
    resource.value       = nil
    resource.history     = {}
    local info = store / "info"
    info ["#" .. id] = (info ["#" .. id] or 0) + 1
  end

  function Methods.copy (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
        [id]           = Parameters.resource [id],
        project        = Parameters.project,
        name           = Parameters.resource.identifier,
      },
    })
    local user     = request.authentication.user
    local project  = request.project
    if project.username ~= user.username then
      error {
        _    = i18n ["resource:forbidden"],
        name = request.name,
      }
    end
    local resource = project / request.name
    if resource then
      error {
        _    = i18n ["resource:exist"],
        name = request.name,
      }
    end
    local source = request [id]
    resource             = request.project + request.name
    resource.id          = request.name
    resource.type        = id
    resource.username    = user.username
    resource.projectname = project.projectname
    resource.value       = source.value
    resource.history     = source.history
    local info = store / "info"
    info ["#" .. id] = info ["#" .. id] + 1
  end

  function Methods.get (request, store)
    Parameters.check (store, request, {
      required = {
        [id] = Parameters.resource [id],
      },
      optional = {
        authentication = Parameters.token.authentication,
        history        = Parameters.boolean,
      },
    })
  end

  function Methods.set (request, store)
    Parameters.check (store, request, {
      required = {
        [id] = Parameters.resource [id],
      },
      optional = {
        authentication = Parameters.token.authentication,
        history        = Parameters.boolean,
      },
    })
  end

  function Methods.delete (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
        [id]           = Parameters.resource [id],
      },
    })
    local resource = request.resource
    if not resource then
      error {
        _    = i18n ["resource:miss"],
        name = resource.id,
      }
    end
    local user = request.authentication.user
    if resource.username ~= user.username then
      error {
        _    = i18n ["resource:forbidden"],
        name = resource.id,
      }
    end
    local _ = user - resource.id
    local info = store / "info"
    info ["#" .. id] = info ["#" .. id] - 1
  end

  return Methods

end
