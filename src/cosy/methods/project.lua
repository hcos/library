return function (loader)

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
    "cosy.parameters",
  }
  i18n._locale = Configuration.locale

  function Methods.create (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
        identifier     = Parameters.resource.identifier,
      },
      optional = {
        is_private = Parameters.is_private,
      },
    })
    local user    = request.authentication.user
    local project = user / request.identifier
    if project then
      error {
        _    = i18n ["resource:exist"],
        name = request.identifier,
      }
    end
    project             = user + request.identifier
    project.permissions = {}
    project.identifier  = request.identifier
    project.type        = "project"
    local info = store / "info"
    info ["#project"] = (info ["#project"] or 0) + 1
  end

  function Methods.delete (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
        project        = Parameters.project,
      },
    })
    local project = request.project
    if not project then
      error {
        _    = i18n ["resource:miss"],
        name = request.project.rawname,
      }
    end
    local user = request.authentication.user
    if not (user < project) then
      error {
        _    = i18n ["resource:forbidden"],
        name = tostring (project),
      }
    end
    local _ = - project
    local info = store / "info"
    info ["#project"] = info ["#project"] - 1
  end

  return Methods

end
