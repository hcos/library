local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Value         = require "cosy.value"
local Cli           = require "cliargs"
local Colors        = require "ansicolors"
local Websocket     = require "websocket"

Configuration.load {
  "cosy",
  "cosy.daemon",
  "cosy.server",
}

local i18n   = I18n.load {
  "cosy.commands",
  "cosy.daemon",
}
i18n._locale = Configuration.cli.locale [nil]

if _G.nocolor then
  Colors = function (s)
    return s:gsub ("(%%{(.-)})", "")
  end
end

local function read (filename)
  local file = io.open (filename, "r")
  if not file then
    return nil
  end
  local data = file:read "*all"
  file:close ()
  return Value.decode (data)
end

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
        max = math.max (max, #reason.parameter)
      end
      for i = 1, #result.error.reasons do
        local reason    = result.error.reasons [i]
        local parameter = reason.parameter
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

function Options.set (part, name, oftype, description)
  if name == "locale" then
    if not oftype then
      Cli:add_option (
        "-l, --locale=LOCALE",
        i18n ["option:locale"] % {},
        Configuration.cli.locale [nil]
      )
    end
  elseif part == "optional" and name == "server" then
    Cli:add_option (
      "-s, --server=SERVER",
      i18n ["option:server"] % {},
      Configuration.cli.server [nil]
    )
  elseif part == "optional" and name == "debug" then
    Cli:add_flag (
      "-d, --debug",
      i18n ["flag:debug"] % {}
    )
  elseif part == "optional" and name == "force" then
    Cli:add_flag (
      "-f, --force",
      i18n ["flag:force"] % {}
    )
  elseif oftype == "password.checked" and part == "required" then
    local _ = false
  elseif oftype == "password" and part == "required" then
    local _ = false
  elseif oftype == "password.checked" and part == "optional" then
    Cli:add_flag (
      "--{{{name}}}" % { name = name },
      i18n ["flag:password"] % {}
    )
  elseif oftype == "password" and part == "optional" then
    Cli:add_flag (
      "--{{{name}}}" % { name = name },
      i18n ["flag:password"] % {}
    )
  elseif oftype == "token.authentication" then
    Cli:add_option (
      "--{{{name}}}=TOKEN" % { name = name },
      description
    )
  elseif oftype == "tos_digest" then
    local _ = false
  elseif oftype == "position" then
    local _ = false
  elseif oftype == "boolean" then
    Cli:add_flag (
      "--{{{name}}}" % { name = name },
      description
    )
  elseif part == "required" then
    Cli:add_argument (
      "{{{name}}}" % { name = name },
      description
    )
  elseif part == "optional" then
    Cli:add_option (
      "--{{{name}}}=..." % { name = name },
      description
    )
  else
    print (part, name, oftype)
    assert (false)
  end
end

function Commands.new (ws)
  return setmetatable ({
    ws = ws,
  }, Commands)
end

function Commands.print_help (commands)
  commands.ws:send (Value.expression {
    server     = commands.server,
    operation  = "server:list-methods",
    parameters = {
      locale = Configuration.locale.default [nil],
    }
  })
  local result = Value.decode (commands.ws:receive ())
  local name_size = 0
  local names     = {}
  local list      = {}
  if not result.success then
    show_status (result)
    os.exit (1)
  end
  for name, description in pairs (result.response) do
    name_size = math.max (name_size, #name)
    names [#names+1] = name
    list [name] = description
  end
  print (Colors ("%{white redbg}" .. i18n ["command:erroneous"] % {
    cli = arg [0],
  }))
  print (i18n ["command:available"] % {})
  table.sort (names)
  for i = 1, #names do
    local line = "  %{green}" .. names [i]
    for _ = #line, name_size+12 do
      line = line .. " "
    end
    line = line .. "%{yellow}" .. list [names [i]]
    print (Colors (line))
  end
end

function Commands.__index (commands, key)
  if Commands [key] then
    return function ()
      return Commands [key] (commands)
    end
  end
  local server
  for i = 1, #_G.arg do
    server = _G.arg [i]:match "^-s=(.)"
          or _G.arg [i]:match "^--server=(.)"
  end
  if not server then
    server = Configuration.cli.server [nil]
  end
  commands.server = server
  if not key then
    Commands.print_help (commands)
    os.exit (1)
  end
  commands.ws:send (Value.expression {
    server    = server,
    operation = key .. "?",
  })
  local result = Value.decode (commands.ws:receive ())
  if not result.success and result.error._ == "server:no-operation" then
    Commands.print_help (commands)
    os.exit (1)
  end
  if not result.success then
    show_status (result)
    os.exit (1)
  end
  if not result.response.optional then
    result.response.optional = {}
  end
  local option_names = {}
  local option_parts = {}
  local option_types = {}
  local option_descs = {}
  for part, t in pairs (result.response) do
    for name, x in pairs (t) do
      option_names [#option_names+1] = name
      option_parts [name] = part
      option_types [name] = x.type
      option_descs [name] = x.description
    end
  end
  table.sort (option_names)
  for i = 1, #option_names do
    local name   = option_names [i]
    local part   = option_parts [name]
    local oftype = option_types [name]
    local desc   = option_descs [name]
    Options.set (part, name, oftype, desc)
  end
  Options.set ("optional", "debug" )
  Options.set ("optional", "locale")
  Options.set ("optional", "server")
  return function ()
    local args, s = Cli:parse_args ()
    if not args then
      if not s:match "^Usage" then
        Cli:print_help ()
      end
      os.exit (1)
    end
    if Prepares [key] then
      Prepares [key] (commands, args)
    end
    local parameters = {}
    for _, x in pairs (result.response) do
      for name, t in pairs (x) do
        if t.type == "password" then
          io.write (i18n ["argument:password" .. tostring (1)] % {} .. " ")
          parameters [name] = getpassword ()
        elseif t.type == "password.checked" then
          local passwords = {}
          repeat
            for i = 1, 2 do
              io.write (i18n ["argument:password" .. tostring (i)] % {} .. " ")
              passwords [i] = getpassword ()
            end
            if passwords [1] ~= passwords [2] then
              print (i18n ["argument:password:nomatch"] % {})
            end
          until passwords [1] == passwords [2]
          parameters [name] = passwords [1]
        elseif args [name] then
          if t.type == "token.authentication" then
            local _ = false
          elseif t.type == "avatar" then
            local avatar = args [name]
            if avatar:match "^https?://" then
              local request = require "socket.http" .request
              local body, status = request (avatar)
              if status ~= 200 then
                return {
                  success = false,
                  error   = {
                    _ = i18n ["url:not-found"] % {
                      url    = avatar,
                      status = status,
                    },
                  },
                }
              end
              parameters [name] = {
                source  = avatar,
                content = body,
              }
            else
              if avatar:match "^~" then
                avatar = os.getenv "HOME" .. avatar:sub (2)
              end
              local file, err = io.open (avatar, "r")
              if file then
                parameters [name] = {
                  source  = avatar,
                  content = file:read "*all",
                }
                file:close ()
              else
                return {
                  success = false,
                  error   = {
                    _ = i18n ["file:not-found"] % {
                      filename = avatar,
                      reason   = err,
                    },
                  },
                }
              end
            end
          else
            parameters [name] = args [name]
          end
        end
      end
    end
    parameters.server = nil
    parameters.debug  = nil
    commands.ws:send (Value.expression {
      server     = server,
      operation  = key,
      parameters = parameters,
    })
    result = commands.ws:receive ()
    result = Value.decode (result)
    show_status (result)
    if  result.success
    and type (result.response) == "table"
    and Results [key] then
      Results [key] (result.response)
    end
    if args.debug then
      print (Colors ("%{white yellowbg}" .. Value.expression (result)))
    end
    return result
  end
end

Commands ["daemon:stop"] = function (commands)
  Options.set ("optional", "debug" , "debug" )
  Options.set ("optional", "force" , "force" )
  Options.set ("optional", "server", "server")
  local args = Cli:parse_args ()
  if not args then
    os.exit (1)
  end
  commands.ws:send "daemon-stop"
  local result = commands.ws:receive ()
  if not result then
    result = i18n {
      success = false,
      error   = {
        _ = i18n ["daemon:unreachable"] % {},
      },
    }
  else
    result = Value.decode (result)
  end
  if not result.success and args.force then
    os.execute ([==[
      if [ -f "{{{pid}}}" ]
      then
        kill -9 $(cat {{{pid}}}) 2> /dev/null
      fi
    ]==] % {
      pid = Configuration.daemon.pid [nil],
    })
    os.remove (Configuration.daemon.data [nil])
    os.remove (Configuration.daemon.pid  [nil])
    result = i18n {
      success  = true,
      response = {
        _ = i18n ["daemon:force-stop"] % {},
      },
    }
  end
  show_status (result)
  if args.debug then
    print (Colors ("%{white yellowbg}" .. Value.expression (result)))
  end
  return result
end

Commands ["server:start"] = function ()
  Options.set ("optional", "debug" )
  Options.set ("optional", "force" )
  Options.set ("optional", "server")
  Cli:add_flag (
    "--clean",
    i18n ["flag:clean"] % {}
  )
  local args = Cli:parse_args ()
  if not args then
--    Cli:print_help ()
    os.exit (1)
  end
  do
    local ws = Websocket.client.sync {
      timeout = 5,
    }
    local url = args.server:gsub ("^http", "ws"):gsub ("/$", "") .. "/ws"
    if ws:connect (url) then
      local result = i18n {
        success = false,
        error   = {
          _ = i18n ["server:already-running"] % {},
        },
      }
      return show_status (result)
    end
  end
  if args.clean then
    Configuration.load "cosy.redis"
    local Redis     = require "redis"
    local host      = Configuration.redis.interface [nil]
    local port      = Configuration.redis.port [nil]
    local database  = Configuration.redis.database [nil]
    local client    = Redis.connect (host, port)
    client:select (database)
    client:flushdb ()
    package.loaded ["redis"] = nil
  end
  if io.open (Configuration.server.pid [nil], "r") then
    local result = {
      success = false,
      error   = i18n {
        _ = i18n ["server:dead"] % {},
      }
    }
    if args.force then
      print (Colors ("%{yellow blackbg}" .. result.error.message))
    else
      return show_status (result)
    end
  end
  os.execute ([==[
    if [ -f "{{{pid}}}" ]
    then
      kill -9 $(cat {{{pid}}}) 2> /dev/null
    fi
    rm -f {{{pid}}} {{{log}}}
    luajit -e '_G.logfile = "{{{log}}}"; require "cosy.server" .start ()' &
  ]==] % {
    pid = Configuration.server.pid [nil],
    log = Configuration.server.log [nil],
  })
  local tries = 0
  local serverdata
  repeat
    os.execute ([[sleep {{{time}}}]] % { time = 0.5 })
    serverdata = read (Configuration.server.data [nil])
    tries      = tries + 1
  until serverdata or tries == 10
  local result
  if serverdata then
    result = {
      success = true,
    }
  else
    result = i18n {
      success = false,
      error   = {
        _ = i18n ["server:unreachable"] % {},
      },
    }
  end
  show_status (result)
  if args.debug then
    print (Colors ("%{white yellowbg}" .. Value.expression (result)))
  end
  return result
end

Commands ["server:stop"] = function (commands)
  local serverdata = read (Configuration.server.data [nil])
  Options.set ("optional", "debug" )
  Options.set ("optional", "force" )
  Options.set ("optional", "server")
  Cli:add_option (
    "--token=TOKEN",
    "administration token",
    serverdata and serverdata.token or nil
  )
  local args = Cli:parse_args ()
  if not args then
    os.exit (1)
  end
  commands.ws:send (Value.expression {
    server     = args.server,
    operation  = "server:stop",
    parameters = {
      server         = args.server,
      authentication = args.token,
      locale         = args.locale,
    },
  })
  local result = commands.ws:receive ()
  if not result then
    result = i18n {
      success = false,
      error   = {
        _ = i18n ["daemon:unreachable"] % {},
      },
    }
  else
    result = Value.decode (result)
  end
  if not result.success and args.force then
    os.execute ([==[
      if [ -f "{{{pid}}}" ]
      then
        kill -9 $(cat {{{pid}}}) 2> /dev/null
      fi
    ]==] % {
      pid = Configuration.server.pid [nil],
    })
    os.remove (Configuration.server.data [nil])
    os.remove (Configuration.server.pid  [nil])
    result = i18n {
      success  = true,
      response = {
        _ = i18n ["server:force-stop"] % {},
      },
    }
  end
  show_status (result)
  if args.debug then
    print (Colors ("%{white yellowbg}" .. Value.expression (result)))
  end
  return result
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

Prepares ["user:create"] = function (commands, args)
  commands.ws:send (Value.expression {
    server     = args.server,
    operation  = "server:tos",
    parameters = {
      locale = args.locale,
    },
  })
  local tosresult = Value.decode (commands.ws:receive ())
  if tosresult.success then
    args.tos_digest = tosresult.response.tos_digest
  end
end

Results ["user:update"] = function (response)
  Results ["user:information"] (response)
end

Results ["user:information"] = function (response)
  if response.avatar then
    local avatar     = response.avatar
    local inputname  = os.tmpname ()
    local file = io.open (inputname, "w")
    file:write (avatar.content)
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
