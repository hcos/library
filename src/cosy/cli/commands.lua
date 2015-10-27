return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local I18n          = loader.load "cosy.i18n"
  local Value         = loader.load "cosy.value"
  local Colors        = loader.require "ansicolors"
  local Websocket     = loader.require "websocket"
  local Copas         = loader.require "copas.ev"
  Copas.make_default ()
  local Http          = loader.require "socket.http"
  local Ltn12         = loader.require "ltn12"

  Configuration.load {
    "cosy.cli",
  }

  local i18n   = I18n.load {
    "cosy.cli",
  }
  i18n._locale = Configuration.cli.locale

  -- http://lua.2524044.n2.nabble.com/Reading-passwords-in-a-console-application-td6641037.html
  local function getpassword ()
    local stty_ret = os.execute ("stty -echo 2>/dev/null")
    if stty_ret ~= 0 then
      io.write("\027[08m") -- ANSI 'hidden' text attribute
    end
    local ok, pass = pcall (io.read, "*l")
    if stty_ret == 0 then
      os.execute("stty sane")
    else
      io.write("\027[00m")
    end
    io.write("\n")
    os.execute("stty sane")
    if ok then
      return pass
    end
  end

  local function show_status (result)
    assert (type (result) == "table")
    if result.success then
      if type (result.response) ~= "table" then
        result.response = { message = result.response }
      end
      print (Colors ("%{black greenbg}" .. i18n ["success"] % {}),
             Colors ("%{green blackbg}" .. (result.response.message ~= nil and tostring (result.response.message) or "")))
    elseif result.error then
      print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
             Colors ("%{red blackbg}" .. (result.error.message ~= nil and tostring (result.error.message) or "")))
      if result.error._ == "check:error" then
        local max = 0
        for i = 1, #result.error.reasons do
          local reason = result.error.reasons [i]
          max = math.max (max, #reason.key)
        end
        for i = 1, #result.error.reasons do
          local reason    = result.error.reasons [i]
          local parameter = reason.key
          local message   = reason.message
          local space = ""
          for _ = #parameter, max+3 do
            space = space .. " "
          end
          space = space .. " => "
          print (Colors ("%{black redbg}" .. tostring (parameter)) ..
                 Colors ("%{reset}" .. space) ..
                 Colors ("%{red blackbg}" .. tostring (message)))
        end
      end
    end
    return result
  end

  local Commands = {}
  local Prepares = {}
  local Options  = {}
  local Results  = {}

  function Options.set (parser, part, name, oftype, description)
    if name == "locale" then
      if not oftype then
        parser:option "-l" "--locale" {
          description = i18n ["option:locale"] % {},
          default     = Configuration.cli.locale,
        }
      end
    elseif part == "optional" and name == "debug" then
      parser:flag "-d" "--debug" {
        description = i18n ["flag:debug"] % {},
      }
    elseif part == "optional" and name == "force" then
      parser:flag "-f" "--force" {
        description = i18n ["flag:force"] % {},
      }
    elseif oftype == "password:checked" then
      parser:flag ("--{{{name}}}" % { name = name }) {
        description = i18n ["flag:password"] % {},
        default     = tostring (part == "required"),
        convert     = function (x) return x:tolower () == "true" end,
      }
    elseif oftype == "password" then
      parser:flag ("--{{{name}}}" % { name = name }) {
        description = i18n ["flag:password"] % {},
        default     = tostring (part == "required"),
        convert     = function (x) return x:tolower () == "true" end,
      }
    elseif oftype == "token:administration" then
      parser:option ("--{{{name}}}" % { name = name }) {
        description = description,
      }
    elseif oftype == "token:authentication" then
      parser:option ("--{{{name}}}" % { name = name }) {
        description = description,
      }
    elseif oftype == "tos:digest" then
      local _ = false
    elseif oftype == "position" then
      parser:option ("--{{{name}}}" % { name = name }) {
        description = description,
      }
    elseif oftype == "ip" then
      local _ = false
    elseif oftype == "captcha" then
      parser:flag ("--{{{name}}}" % { name = name }) {
        description = i18n ["flag:captcha"] % {},
        default     = tostring (part == "required"),
        convert     = function (x) return x:tolower () == "true" end,
      }
    elseif oftype == "boolean" then
      parser:flag ("--{{{name}}}" % { name = name }) {
        description = description,
      }
    elseif part == "required" then
      parser:argument ("{{{name}}}" % { name = name }) {
        description = description,
      }
    elseif part == "optional" then
      parser:option ("--{{{name}}}=..." % { name = name }) {
        description = description,
      }
    else
      print (part, name, oftype)
      assert (false)
    end
  end

  function Commands.new (t)
    local commands   = setmetatable (t, Commands)
    commands.methods = commands.client.server.list_methods {
      locale = Configuration.locale.default,
    }
    for name, description in pairs (commands.methods) do
      local command = commands.parser:command (name) {
        description = description,
      }
      local info = commands.client [name .. "?"] {}
      for part, subt in pairs (info) do
        for parameter, x in pairs (subt) do
          Options.set (command, part, parameter, x.type, x.description)
        end
      end
    end
    commands.parser:parse ()
    return commands
  end

  function Commands.parse (commands)
    local args = commands.parser:parse ()
    local key
    for method in pairs (commands.methods) do
      if args [method] then
        key = method
      end
    end
    assert (key)
    if Prepares [key] then
      Prepares [key] (commands, args)
    end
    local parameters = {}
    local info = commands.client [key .. "?"] {}
    for _, x in pairs (info) do
      for name, t in pairs (x) do
        if t.type == "password" and args [name] then
          io.write (i18n ["argument:password1"] % {} .. " ")
          parameters [name] = getpassword ()
        elseif t.type == "password:checked" and args [name] then
          local passwords = {}
          repeat
            io.write (i18n ["argument:password1"] % {} .. " ")
            passwords [1] = getpassword ()
            io.write (i18n ["argument:password2"] % {} .. " ")
            passwords [2] = getpassword ()
            if passwords [1] ~= passwords [2] then
              print (i18n ["argument:password:nomatch"] % {})
            end
          until passwords [1] == passwords [2]
          parameters [name] = passwords [1]
        elseif t.type == "position" and args [name] then
          if args [name] == "auto" then
            parameters [name] = true
          else
            parameters [name] = args [name] / "{{{Country}}}/{{{City}}}"
          end
        elseif t.type == "captcha" and args [name] then
          Commands.captcha (args, parameters)
        elseif args [name] then
          if t.type == "token:authentication" then
            local _ = false
          elseif t.type == "avatar" then
            local avatar = args [name]
            local filename = avatar
            local errresult
            if avatar:match "^https?://" then
              filename   = os.tmpname ()
              local file = io.open (filename, "w")
              local _, status = Http.request {
                method = "GET",
                url    = avatar,
                sink   = Ltn12.sink.file (file),
              }
              if status ~= 200 then
                errresult = {
                  success = false,
                  error   = i18n {
                    _      = i18n ["url:not-found"],
                    url    = avatar,
                    reason = status,
                  },
                }
              end
              file:close ()
            elseif avatar:match "^~" then
              filename = os.getenv "HOME" .. avatar:sub (2)
            end
            local file, err = io.open (filename, "r")
            if not file then
              errresult = {
                success = false,
                error   = i18n {
                  _        = i18n ["file:not-found"],
                  filename = filename,
                  reason   = err,
                },
              }
            end
            local body = file:read "*all"
            file:close ()
            local _, status, headers = Http.request (args.server .. "/upload", body)
            if status == 200 then
              parameters [name] = headers ["cosy-avatar"]
            else
              errresult = {
                success = false,
                error   = i18n {
                  _      = i18n ["upload:failure"],
                  status = status,
                },
              }
            end
            if errresult then
              show_status (errresult)
              os.exit (1)
            end
          else
            parameters [name] = args [name]
          end
        end
      end
    end
    local result = commands.client [key] (parameters)
    print (Value.expression (result))
    show_status (result)
    if result.success
    and type (result.response) == "table"
    and Results [key] then
      Results [key] (result.response, commands.ws)
    end
    return result
  end

  function Commands.captcha (args, parameters)
    local info      = {}
    local addserver = Copas.addserver
    Copas.addserver = function (s, f)
      info.socket = s
      local ok, port = s:getsockname ()
      if ok then
        info.port = port
      end
      addserver (s, f)
    end
    Websocket.server.copas.listen {
      port      = 0,
      protocols = {
        cosycli = function (ws)
          while true do
            local message = ws:receive ()
            if message then
              message = Value.decode (message)
              parameters.captcha = message.response
              Copas.removeserver (info.socket)
            else
              ws:close()
              return
            end
          end
        end
      },
    }
    Copas.addserver = addserver
    os.execute ([[
      xdg-open {{{url}}} || open {{{url}}} &
    ]] % {
      url = "{{{server}}}/html/captchacli.html?port={{{port}}}" % {
        server = args.server,
        port   = info.port,
      },
    })
    Copas.loop()
  end

  Results ["server:information"] = function (response)
    local max  = 0
    local keys = {}
    for key in pairs (response) do
      keys [#keys+1] = key
      max = math.max (max, #key)
    end
    for i = 1, #keys do
      local key   = keys [i]
      local value = response [key]
      local space = ""
      for _ = #key, max+3 do
        space = space .. " "
      end
      space = space .. " => "
      print (Colors ("%{black yellowbg}" .. tostring (key)) ..
             Colors ("%{reset}" .. space) ..
             Colors ("%{yellow blackbg}" .. tostring (value)))
    end
  end

  Results ["server:tos"] = function (response)
    print (response.tos)
    print (Colors ("%{black yellowbg}" .. "digest") ..
           Colors ("%{reset}" .. " => ") ..
           Colors ("%{yellow blackbg}" .. response.tos_digest))
  end

  Results ["server:filter"] = function (_, ws)
    for i = 1, math.huge do
      local response = ws:receive ()
      if response == nil then
        break
      end
      local key      = tostring (i)
      local value    = Value.decode (response)
      if value.error then
        print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
               Colors ("%{red blackbg}" .. (value.error.message ~= nil and tostring (value.error.message) or "")))
      end
      if value.finished then
        break
      end
      value = value.response
      if type (value) ~= "table" then
        print (Colors ("%{black yellowbg} " .. tostring (key)) ..
               Colors ("%{reset}" .. " => ") ..
               Colors ("%{yellow blackbg}" .. tostring (value)))
      else
        print (Colors ("%{black cyanbg} " .. tostring (key) .. " ") ..
               Colors ("%{reset}" .. " => "))
        local max  = 0
        local keys = {}
        for k in pairs (value) do
          keys [#keys+1] = k
          max = math.max (max, #tostring (k))
        end
        for j = 1, #keys do
          local jkey   = keys [j]
          local jvalue = value [jkey]
          local jspace = ""
          for _ = #tostring (jkey), max+3 do
            jspace = jspace .. " "
          end
          jspace = jspace .. " => "
          print (Colors ("%{black yellowbg}  " .. tostring (jkey)) ..
                 Colors ("%{reset}" .. jspace) ..
                 Colors ("%{yellow blackbg}" .. tostring (jvalue)))
        end
      end
    end
  end

  Prepares ["user:create"] = function (commands, args)
    if not args.tos_digest then
      commands.ws:send (Value.expression {
        server     = args.server,
        operation  = "server:tos",
        parameters = {
          locale = args.locale,
        },
      })
      local tosresult = Value.decode (commands.ws:receive ())
      assert (tosresult.success)
      args.tos_digest = tosresult.response.tos_digest
    end
  end

  Results ["user:update"] = function (response)
    Results ["user:information"] (response)
  end

  Results ["user:is_authentified"] = function (response)
    print (Colors ("%{black yellowbg}" .. "username") ..
           Colors ("%{reset}" .. " => ") ..
           Colors ("%{yellow blackbg}" .. response.username))
  end

  Results ["user:information"] = function (response)
    if response.avatar then
      local avatar     = response.avatar
      local inputname  = os.tmpname ()
      local file = io.open (inputname, "w")
      assert (file)
      file:write (avatar)
      file:close ()
      os.execute ([[
        img2txt -W 40 -H 20 {{{input}}} 2> /dev/null
      ]] % {
        input  = inputname,
      })
      os.remove (inputname)
      response.avatar  = nil
    end
    if response.position then
      response.position = "{{{country}}}/{{{city}}}" % response.position
    end
    if response.lastseen then
      response.lastseen = os.date ("%x, %X", response.lastseen)
    end
    if response.authentication then
      response.authentication = nil
    end
    local max  = 0
    local keys = {}
    for key in pairs (response) do
      keys [#keys+1] = key
      max = math.max (max, #key)
    end
    max = max + 3
    table.sort (keys)
    for i = 1, #keys do
      local key   = keys [i]
      local value = response [key]
      local space = ""
      for _ = #key, max do
        space = space .. " "
      end
      space = space .. " => "
      print (Colors ("%{black yellowbg}" .. tostring (key)) ..
             Colors ("%{reset}" .. space) ..
             Colors ("%{yellow blackbg}" .. tostring (value)))
    end
  end

  Results ["user:list"] = function (response)
    for i = 1, #response do
      print (Colors ("%{yellow blackbg}" .. tostring (response [i])))
    end
  end

  return Commands

end
