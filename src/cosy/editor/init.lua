return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local Digest        = loader.load "cosy.digest"
  local I18n          = loader.load "cosy.i18n"
  local File          = loader.load "cosy.file"
  local Library       = loader.load "cosy.library"
  local Logger        = loader.load "cosy.logger"
  local Nginx         = loader.load "cosy.nginx"
  local Store         = loader.load "cosy.store"
  local Token         = loader.load "cosy.token"
  local Value         = loader.load "cosy.value"
  local App           = loader.load "cosy.configuration.layers".app
  local Layer         = loader.require "layeredata"
  local Lfs           = loader.require "lfs"
  local Posix         = loader.require "posix"
  local Url           = loader.require "socket.url"
  local Websocket     = loader.require "websocket"
  local Time          = loader.require "socket".gettime

  do
    local oldnew = Layer.new
    Layer.new = function (t)
      local layer = oldnew (t)
      return layer, Layer.reference (layer)
    end
    Layer.require = function (name)
      if Layer.loaded [package] then
        return Layer.loaded [package]
      else
        -- connect through library
        return layer, reference
      end
    end
  end

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

  Editor.requests = {}
  Editor.accesses = {}
  Editor.clients  = {}

  function Editor.start (options)
    Editor.stopped = false

    local pid = Posix.getpid "pid"
    Lfs.mkdir  (Configuration.editor.directory)
    os.remove (Configuration.editor.log  % { pid = pid })
    os.remove (Configuration.editor.data % { pid = pid })

    App.editor            = {}
    App.editor.passphrase = Digest (math.random ())
    App.editor.token      = Token.administration (Configuration.editor.passphrase)
    local addserver       = loader.scheduler.addserver

    do
      local url   = Url.parse (options.resource)
      local store = Store.new () % options.token
      local t     = url.path / "/{{{user}}}/{{{project}}}/{{{resource}}}"
      local data = store / "data" / t.user / t.project / t.resource
      assert (data)
      Editor.current = data / "current"
      Editor.history = data / "history"
      local layer, reference = Layer.new {
        name = options.resource,
      }
      local loaded = assert (loadstring (Editor.current)) ()
      Editor.layer = loaded (Layer, layer, reference)
    end

    local answer = loader.scheduler.addthread (Editor.answer)

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
        ["cosy-editor"] = function (ws)
          local message
          local function send (t)
            local response = Value.expression (t)
            Logger.debug {
              _        = i18n ["server:response"],
              request  = message,
              response = response,
            }
            ws:send (response)
          end
          while ws.state == "OPEN" do
            message = ws:receive ()
            Logger.debug {
              _       = i18n ["server:request"],
              request = message,
            }
            if message then
              local decoded, request = pcall (Value.decode, message)
              if not decoded or type (request) ~= "table" then
                send (i18n {
                  success = false,
                  error   = {
                    _ = i18n ["message:invalid"],
                  },
                })
              end
              if not request.parameters then
                request.parameters = {}
              end
              if request.operation == "stop" then
                if request.parameters.token == Configuration.editor.token then
                  Editor.stop ()
                  send (i18n {
                    success = true,
                  })
                else
                  send (i18n {
                    success = false,
                    error   = {
                      _ = i18n ["message:invalid"],
                    },
                  })
                end
              elseif request.operation == "set-access" then
                if request.parameters.token == Configuration.editor.token then
                  Editor.accesses = request.parameters.accesses
                  send (i18n {
                    success = true,
                  })
                else
                  send (i18n {
                    success = false,
                    error   = {
                      _ = i18n ["message:invalid"],
                    },
                  })
                end
              else
                request.ws = ws
                Editor.requests [#Editor.requests+1] = request
                loader.scheduler.wakeup (answer)
              end
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
    Editor.stopped = true
  end

  function Editor.answer ()
    while not Editor.stopped do
      if #Editor.requests == 0 then
        loader.scheduler.sleep (-math.huge)
      else
        local request = Editor.requets [1]
        local function send (t)
          local response = Value.expression (t)
          Logger.debug {
            _        = i18n ["server:response"],
            request  = request,
            response = response,
          }
          request.ws:send (response)
        end
        table.remove (Editor.requests, 1)
        if     request.operation == "get-current" then
        elseif request.operation == "get-history" then
          send (i18n {
            identifier = identifier,
            success    = true,
            iterator   = true,
            token      = result (), -- first call returns the token
          })
          repeat
            local subresult, suberr = result ()
            if subresult then
              send (i18n {
                identifier = identifier,
                success    = true,
                response   = subresult,
              })
            elseif suberr then
              send (i18n {
                identifier = identifier,
                success    = false,
                finished   = true,
                error      = suberr,
              })
            else
              send (i18n {
                identifier = identifier,
                success    = true,
                finished   = true,
              })
            end
          until subresult == nil or suberr
        elseif request.operation == "path" then
        end
      end
    end
  end

  return Editor

end
