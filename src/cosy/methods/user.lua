return function (loader)

  local Methods  = {}

  local Configuration = loader.load "cosy.configuration"
  local Email         = loader.load "cosy.email"
  local I18n          = loader.load "cosy.i18n"
  local Parameters    = loader.load "cosy.parameters"
  local Password      = loader.load "cosy.password"
  local Token         = loader.load "cosy.token"
  local Json          = loader.require "cjson".new ()
  local Time          = loader.require "socket".gettime

  Configuration.load {
    "cosy.nginx",
    "cosy.methods",
    "cosy.parameters",
    "cosy.server",
  }

  local i18n   = I18n.load {
    "cosy.methods",
    "cosy.server",
    "cosy.library",
    "cosy.parameters",
  }
  i18n._locale = Configuration.locale

  function Methods.create (request, store, try_only)
    Parameters.check (store, request, {
      required = {
        identifier = Parameters.user.new_identifier,
        password   = Parameters.password.checked,
        email      = Parameters.user.new_email,
        tos_digest = Parameters.tos.digest,
        locale     = Parameters.locale,
      },
      optional = {
        captcha        = Parameters.captcha,
        ip             = Parameters.ip,
        administration = Parameters.token.administration,
      },
    })
    local email = store / "email" + request.email
    email.identifier = request.identifier
    if request.locale == nil then
      request.locale = Configuration.locale
    end
    local user = store / "data" + request.identifier
    user.checked     = false
    user.email       = request.email
    user.identifier  = request.identifier
    user.lastseen    = Time ()
    user.locale      = request.locale
    user.password    = Password.hash (request.password)
    user.tos_digest  = request.tos_digest
    user.reputation  = Configuration.reputation.initial
    user.status      = "active"
    user.type        = "user"
    local info = store / "info"
    info ["#user"] = (info ["#user"] or 0) + 1
    if  not Configuration.dev_mode
    and (request.captcha == nil or request.captcha == "")
    and not request.administration then
      error {
        _   = i18n ["captcha:missing"],
        key = "captcha"
      }
    end
    if try_only then
      return true
    end
    -- Captcha validation must be done only once,
    -- so it must be __after__ the `try_only`.`
    if request.captcha then
      if not Configuration.dev_mode then
        local url  = "https://www.google.com/recaptcha/api/siteverify"
        local body = "secret="    .. Configuration.recaptcha.private_key
                  .. "&response=" .. request.captcha
                  .. "&remoteip=" .. request.ip
        local response, status = loader.request (url, body)
        assert (status == 200)
        response = Json.decode (response)
        assert (response)
        if not response.success then
          error {
            _ = i18n ["captcha:failure"],
          }
        end
      end
    elseif not request.administration then
      error {
        _ = i18n ["method:administration-only"],
      }
    end
    Email.send {
      locale  = user.locale,
      from    = {
        _     = i18n ["user:create:from"],
        name  = Configuration.http.hostname,
        email = Configuration.server.email,
      },
      to      = {
        _     = i18n ["user:create:to"],
        name  = user.identifier,
        email = user.email,
      },
      subject = {
        _          = i18n ["user:create:subject"],
        servername = Configuration.http.hostname,
        identifier = user.identifier,
      },
      body    = {
        _          = i18n ["user:create:body"],
        identifier = user.identifier,
        token      = Token.validation (user),
      },
    }
    return {
      authentication = Token.authentication (user),
    }
  end

  function Methods.send_validation (request, store, try_only)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
      },
    })
    local user = request.authentication.user
    if try_only then
      return true
    end
    Email.send {
      locale  = user.locale,
      from    = {
        _     = i18n ["user:update:from"],
        name  = Configuration.http.hostname,
        email = Configuration.server.email,
      },
      to      = {
        _     = i18n ["user:update:to"],
        name  = user.identifier,
        email = user.email,
      },
      subject = {
        _          = i18n ["user:update:subject"],
        servername = Configuration.http.hostname,
        identifier = user.identifier,
      },
      body    = {
        _          = i18n ["user:update:body"],
        host       = Configuration.http.hostname,
        identifier = user.identifier,
        token      = Token.validation (user),
      },
    }
  end

  function Methods.validate (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
      },
    })
    request.authentication.user.checked = true
  end

  function Methods.authenticate (request, store)
    local ok, err = pcall (function ()
      Parameters.check (store, request, {
        required = {
          user     = Parameters.user.active,
          password = Parameters.password,
        },
      })
    end)
    if not ok then
      if request.__DESCRIBE then
        error (err)
      else
        error {
          _ = i18n ["user:authenticate:failure"],
        }
      end
    end
    local user     = request.user
    local verified = Password.verify (request.password, user.password)
    if not verified then
      error {
        _ = i18n ["user:authenticate:failure"],
      }
    end
    if type (verified) == "string" then
      user.password = verified
    end
    user.lastseen = Time ()
    return {
      authentication = Token.authentication (user),
    }
  end

  function Methods.authentified_as (request, store)
    Parameters.check (store, request, {
      optional = {
        authentication = Parameters.token.authentication,
      },
    })
    return {
      identifier = request.authentication
               and request.authentication.user.identifier
                or nil,
    }
  end

  function Methods.update (request, store, try_only)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
      },
      optional = {
        avatar       = Parameters.avatar,
        email        = Parameters.user.new_email,
        homepage     = Parameters.homepage,
        locale       = Parameters.locale,
        name         = Parameters.name,
        organization = Parameters.organization,
        password     = Parameters.password.checked,
        position     = Parameters.position,
      },
    })
    local user = request.authentication.user
    if request.email then
      local methods       = loader.load "cosy.methods"
      local oldemail      = store / "email" / user.email
      local newemail      = store / "email" + request.email
      newemail.identifier = oldemail.identifier
      local _             = store / "email" - user.email
      user.email          = request.email
      user.checked        = false
      methods.user.send_validation ({
        authentication = Token.authentication (user),
        try_only       = try_only,
      }, store)
    end
    if request.password then
      user.password = Password.hash (request.password)
    end
    if request.position then
      user.position = {
        address   = request.position.address,
        latitude  = request.position.latitude,
        longitude = request.position.longitude,
      }
    end
    if request.avatar then
      user.avatar = {
        full  = request.avatar.normal,
        icon  = request.avatar.icon,
        ascii = request.avatar.ascii,
      }
    end
    for _, key in ipairs { "name", "homepage", "organization", "locale" } do
      if request [key] then
        user [key] = request [key]
      end
    end
    return {
      avatar         = user.avatar,
      checked        = user.checked,
      email          = user.email,
      homepage       = user.homepage,
      lastseen       = user.lastseen,
      locale         = user.locale,
      name           = user.name,
      organization   = user.organization,
      position       = user.position,
      identifier     = user.identifier,
      authentication = Token.authentication (user)
    }
  end

  function Methods.information (request, store)
    Parameters.check (store, request, {
      required = {
        user = Parameters.user,
      },
    })
    local user = request.user
    return {
      avatar       = user.avatar,
      homepage     = user.homepage,
      name         = user.name,
      organization = user.organization,
      position     = user.position,
      identifier   = user.identifier,
    }
  end

  function Methods.recover (request, store, try_only)
    Parameters.check (store, request, {
      required = {
        validation = Parameters.token.validation,
        password   = Parameters.password.checked,
      },
    })
    local user    = request.validation.user
    local token   = Token.authentication (user)
    local methods = loader.load "cosy.methods"
    methods.user.update ({
      user     = token,
      password = request.password,
      try_only = try_only,
    }, store)
    return {
      authentication = token,
    }
  end

  function Methods.reset (request, store, try_only)
    Parameters.check (store, request, {
      required = {
        email = Parameters.email,
      },
    })
    local email = store / "email" / request.email
    if email then
      return
    end
    local user = store / "data" / email.identifier
    if not user or user.type ~= "user" then
      return
    end
    user.password = ""
    if try_only then
      return
    end
    Email.send {
      locale  = user.locale,
      from    = {
        _     = i18n ["user:reset:from"],
        name  = Configuration.http.hostname,
        email = Configuration.server.email,
      },
      to      = {
        _     = i18n ["user:reset:to"],
        name  = user.identifier,
        email = user.email,
      },
      subject = {
        _          = i18n ["user:reset:subject"],
        servername = Configuration.http.hostname,
        identifier = user.identifier,
      },
      body    = {
        _          = i18n ["user:reset:body"],
        identifier = user.identifier,
        validation = Token.validation (user),
      },
    }
  end

  function Methods.suspend (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
        user           = Parameters.user.active,
      },
    })
    local origin = request.authentication.user
    local user   = request.user
    if origin.identifier == user.identifier then
      error {
        _ = i18n ["user:suspend:self"],
      }
    end
    local reputation = Configuration.reputation.suspend
    if origin.reputation < reputation then
      error {
        _        = i18n ["user:suspend:not-enough"],
        owned    = origin.reputation,
        required = reputation
      }
    end
    origin.reputation = origin.reputation - reputation
    user.status       = "suspended"
  end

  function Methods.release (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
        user           = Parameters.user.suspended,
      },
    })
    local origin = request.authentication.user
    local user   = request.user
    if origin.identifier == user.identifier then
      error {
        _ = i18n ["user:release:self"],
      }
    end
    local reputation = Configuration.reputation.release
    if origin.reputation < reputation then
      error {
        _        = i18n ["user:suspend:not-enough"],
        owned    = origin.reputation,
        required = reputation
      }
    end
    origin.reputation = origin.reputation - reputation
    user.status       = "active"
  end

  function Methods.delete (request, store)
    Parameters.check (store, request, {
      required = {
        authentication = Parameters.token.authentication,
      },
    })
    local user = request.authentication.user
    local _ = store / "email" - user.email
    local _ = store / "data"  - user.identifier
    local info = store / "info"
    info ["#user"] = info ["#user"] - 1
  end

  return Methods

end
