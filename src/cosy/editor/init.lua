return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local Digest        = loader.load "cosy.digest"
  local I18n          = loader.load "cosy.i18n"
  local File          = loader.load "cosy.file"
  local Logger        = loader.load "cosy.logger"
  local Nginx         = loader.load "cosy.nginx"
  local Store         = loader.load "cosy.store"
  local Token         = loader.load "cosy.token"
  local Value         = loader.load "cosy.value"
  local App           = loader.load "cosy.configuration.layers".app
  local Lfs           = loader.require "lfs"
  local Posix         = loader.require "posix"
  local Websocket     = loader.require "websocket"
  local Time          = loader.require "socket".gettime

  math.randomseed (Time ())

  Configuration.load {
    "cosy.editor",
  }

  local i18n   = I18n.load {
    "cosy.editor",
    "cosy.server",
  }
  i18n._locale = Configuration.locale

  local Editor = {}

  function Editor.start ()
    local pid = Posix.getpid "pid"
    Lfs.mkdir  (Configuration.editor.directory)
    os.remove (Configuration.editor.log  % { pid = pid })
    os.remove (Configuration.editor.data % { pid = pid })

    App.editor            = {}
    App.editor.passphrase = Digest (math.random ())
    App.editor.token      = Token.administration (Configuration.editor.passphrase)
    local addserver       = loader.scheduler.addserver

    loader.scheduler.addserver = function (s, f)
      local ok, port = s:getsockname ()
      if ok then
        App.editor.socket = s
        App.editor.port   = tonumber (port)
      end
      addserver (s, f)
    end
    Editor.ws = Websocket.server.copas.listen {
      interface = Configuration.editor.interface,
      port      = Configuration.editor.port,
      protocols = {
        cosy = function (ws)
          while ws.state == "OPEN" do
            message = ws:receive ()
            Logger.debug {
              _       = i18n ["server:request"],
              request = message,
            }
            if message then
            end
          end
        end
      }
    }
    loader.scheduler.addserver = addserver

    Logger.debug {
      _    = i18n ["websocket:listen"],
      host = Configuration.editor.interface,
      port = Configuration.editor.port,
    }

    do
      File.encode (Configuration.editor.data, {
        alias     = loader.alias,
        token     = Configuration.editor.token,
        interface = Configuration.editor.interface,
        port      = Configuration.editor.port,
        pid       = Posix.getpid "pid",
      })
      Posix.chmod (Configuration.editor.data, "0600")
    end

    loader.scheduler.loop ()
  end

  function Editor.stop ()
    os.remove (Configuration.editor.data)
    loader.scheduler.removeserver (App.server.socket)
  end

  return Editor

end
