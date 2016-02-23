return function (loader)

  local Methods  = {}

  local Configuration = loader.load "cosy.configuration"
  local Digest        = loader.load "cosy.digest"
  local I18n          = loader.load "cosy.i18n"
  local Logger        = loader.load "cosy.logger"
  local Parameters    = loader.load "cosy.parameters"
  local Scheduler     = loader.load "cosy.scheduler"
  local Token         = loader.load "cosy.token"
  local Value         = loader.load "cosy.value"
  local Posix         = loader.require "posix"
  local Websocket     = loader.require "websocket"

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

  function Methods.list_methods (request, store)
    Parameters.check (store, request, {
      optional = {
        locale = Parameters.locale,
      },
    })
    local locale = Configuration.locale
    if request.locale then
      locale = request.locale or locale
    end
    local result = {}
    local function f (current, prefix)
      for k, v in pairs (current) do
        if type (v) == "function" then
          local name = (prefix or "") .. k:gsub ("_", "-")
          local ok, description = pcall (function ()
            return i18n [name] % { locale = locale }
          end)
          if not ok then
            Logger.warning {
              _      = i18n ["translation:failure"],
              reason = description,
            }
            description = name
          end
          local _, parameters = pcall (v, {
            __DESCRIBE = true,
          })
          result [name] = {
            description = description,
            parameters  = parameters,
          }
        elseif type (v) == "table" then
          f (v, (prefix or "") .. k:gsub ("_", "-") .. ":")
        end
      end
    end
    local methods = loader.load "cosy.methods"
    f (methods, nil)
    return result
  end

  function Methods.stop (request, store)
    Parameters.check (store, request, {
      required = {
        administration = Parameters.token.administration,
      },
    })
    return true
  end

  function Methods.information (request, store)
    Parameters.check (store, request, {})
    local result = {
      name    = Configuration.http.hostname,
      captcha = Configuration.recaptcha.public_key,
    }
    local info = store / "info"
    result ["#user"   ] = info ["#user"   ] or 0
    result ["#project"] = info ["#project"] or 0
    for id in pairs (Configuration.resource.project ["/"]) do
      result ["#" .. id] = info ["#" .. id] or 0
    end
    return result
  end

  function Methods.tos (request, store)
    Parameters.check (store, request, {
      optional = {
        authentication = Parameters.token.authentication,
        locale         = Parameters.locale,
      },
    })
    local locale = Configuration.locale
    if request.locale then
      locale = request.locale or locale
    end
    if request.authentication then
      locale = request.authentication.user.locale or locale
    end
    local tos = i18n ["terms-of-service"] % {
      locale = locale,
    }
    return {
      text   = tos,
      digest = Digest (tos),
    }
  end

  local filters = setmetatable ({}, { __mode = "v" })

  function Methods.filter (request, store)
    local back_request = {}
    for k, v in pairs (request) do
      back_request [k] = v
    end
    Parameters.check (store, request, {
      required = {
        iterator = Parameters.iterator,
      },
      optional = {
        authentication = Parameters.token.authentication,
      }
    })
    local server_socket
    local running       = Scheduler.running ()
    local results       = {}
    local addserver     = Scheduler.addserver
    Scheduler.addserver = function (s, f)
      server_socket = s
      addserver (s, f)
    end
    Websocket.server.copas.listen {
      interface = Configuration.server.interface,
      port      = 0,
      protocols = {
        ["cosy:filter"] = function (ws)
          ws:send (Value.expression (back_request))
          while ws.state == "OPEN" do
            local message = ws:receive ()
            if message then
              local value = Value.decode (message)
              results [#results+1] = value
              Scheduler.wakeup (running)
            end
          end
          Scheduler.removeserver (server_socket)
        end
      }
    }
    Scheduler.addserver = addserver
    local pid = Posix.fork ()
    if pid == 0 then
      local ev = require "ev"
      ev.Loop.default:fork ()
      local Filter  = loader.load "cosy.methods.filter"
      local _, port = server_socket:getsockname ()
      Filter.start {
        url = "ws://{{{interface}}}:{{{port}}}" % {
          interface = Configuration.server.interface,
          port      = port,
        },
      }
      os.exit (0)
    end
    local token = Token.identification {
      pid = pid,
    }
    local iterator
    iterator = function ()
      if not filters [token] then
        filters [token] = iterator
        return token
      end
      local result = results [1]
      if not result then
        Scheduler.sleep (Configuration.filter.timeout)
        result = results [1]
      end
      if result then
        table.remove (results, 1)
      end
      if result and result.success then
        if result.finished then
          filters [token] = nil
        end
        return result.response
      else
        filters [token] = nil
        Posix.kill (pid, 9)
        return nil, {
          _      = i18n ["server:filter:error"],
          reason = result and result.error or i18n ["server:timeout"] % {},
        }
      end
    end
    return iterator
  end

  function Methods.cancel (request, store)
    local raw = request.filter
    Parameters.check (store, request, {
      required = {
        filter = Parameters.token.identification,
      },
    })
    if filters [raw] then
      Posix.kill (request.filter.pid, 9)
    end
  end

  return Methods

end
