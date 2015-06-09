local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Value         = require "cosy.value"
local Colors        = require "ansicolors"

Configuration.load {
  "cosy",
  "cosy.daemon",
  "cosy.server",
}

local i18n   = I18n.load {
  "cosy",
  "cosy.commands",
  "cosy.daemon",
}
i18n._locale = Configuration.cli.default_locale._

local Commands = {}

local function read (filename)
  local file = io.open (filename, "r")
  if not file then
    return nil
  end
  local data = file:read "*all"
  file:close ()
  return Value.decode (data)
end

local function show_status (result)
  assert (type (result) == "table")
  if result.success then
    if type (result.response) ~= "table" then
      result.response = { message = result.response }
    end
    print (Colors ("%{black greenbg}" .. i18n ["success"] % {}),
           Colors ("%{green blackbg}" .. (result.response.message ~= nil and tostring (result.response.message) or "")))
    if Commands.args.debug then
      print (Colors ("%{dim green whitebg}" .. Value.expression (result)))
    end
  elseif result.error then
    print (Colors ("%{black redbg}" .. i18n ["failure"] % {}),
           Colors ("%{red blackbg}" .. (result.error.message ~= nil and tostring (result.error.message) or "")))
    if Commands.args.debug then
      print (Colors ("%{dim red whitebg}" .. Value.expression (result)))
    end
  end
  return result
end

local function user_information (response)
  if response.avatar then
    local avatar          = response.avatar
    local input_filename  = os.tmpname ()
    local file = io.open (input_filename, "w")
    file:write (avatar.content)
    file:close ()
    os.execute ([[
      img2txt -W 40 -H 20 {{{input}}} 2> /dev/null
    ]] % {
      input  = input_filename,
    })
    os.remove (input_filename)
    response.avatar  = nil
  end
  if response.position then
    response.position = "{{{country}}}/{{{city}}}" % response.position
  end
  if response.lastseen then
    response.lastseen = os.date ("%x, %X", response.lastseen)
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

local options = {}

function options.global (cli)
  cli:add_flag (
    "-d, --debug",
    i18n ["flag:debug"] % {}
  )
  cli:add_option (
    "-l, --locale=LOCALE",
    i18n ["option:locale"] % {},
    Configuration.cli.default_locale._
  )
end

function options.server (cli)
  cli:add_option (
    "-s, --server=SERVER",
    i18n ["option:server"] % {},
    Configuration.cli.default_server._
  )
end

function options.authentication (cli)
  cli:add_option (
    "-t, --token=TOKEN",
    i18n ["option:token"] % {}
  )
end

function options.force (cli)
  cli:add_flag (
    "-f, --force",
    i18n ["flag:force"] % {}
  )
end

Commands ["daemon:stop"] = {
  _   = i18n ["daemon:stop"],
  run = function (cli, ws)
    options.global (cli)
    options.force  (cli)
    Commands.args = cli:parse_args ()
    if not Commands.args then
      os.exit (1)
    end
    ws:send (Value.expression "daemon-stop")
    local result = ws:receive ()
    if not result then
      result = {
        success = false,
        error   = {
          _ = i18n ["daemon:unreachable"] % {},
        },
      }
    else
      result = Value.decode (result)
    end
    if not result.success and Commands.args.force then
      os.execute ([==[
        if [ -f "{{{pid}}}" ]
        then
          kill -9 $(cat {{{pid}}}) 2> /dev/null
        fi
      ]==] % {
        pid = Configuration.daemon.pid_file._,
      })
      os.remove (Configuration.daemon.data_file._)
      os.remove (Configuration.daemon.pid_file ._)
      result = {
        success  = true,
        response = {
          _ = i18n ["daemon:force-stop"] % {},
        },
      }
    end
    return show_status (result)
  end,
}

Commands ["server:start"] = {
  _   = i18n ["server:start"],
  run = function (cli)
    options.global (cli)
    options.force  (cli)
    cli:add_flag (
      "-c, --clean",
      i18n ["flag:clean"] % {}
    )
    Commands.args = cli:parse_args ()
    if not Commands.args then
      os.exit (1)
    end
    if Commands.args.clean then
      Configuration.load "cosy.redis"
      local Redis     = require "redis"
      local host      = Configuration.redis.interface._
      local port      = Configuration.redis.port._
      local database  = Configuration.redis.database._
      local client    = Redis.connect (host, port)
      client:select (database)
      client:flushdb ()
      package.loaded ["redis"] = nil
    end
    if io.open (Configuration.server.pid_file._, "r") then
      return {
        success = false,
        error   = {
          _ = i18n ["server:already-running"] % {},
        },
      }
    end
    os.execute ([==[
      if [ -f "{{{pid}}}" ]
      then
        kill -9 $(cat {{{pid}}}) 2> /dev/null
      fi
      rm -f {{{pid}}} {{{log}}}
      luajit -e '_G.logfile = "{{{log}}}"; require "cosy.server" .start ()' &
    ]==] % {
      pid = Configuration.server.pid_file._,
      log = Configuration.server.log_file._,
    })
    local tries = 0
    local serverdata
    repeat
      os.execute ([[sleep {{{time}}}]] % { time = 0.5 })
      serverdata = read (Configuration.server.data_file._)
      tries      = tries + 1
    until serverdata or tries == 10
    if not serverdata then
      return {
        success = false,
        error   = {
          _ = i18n ["server:unreachable"] % {},
        },
      }
    end
    return show_status {
      success = true,
    }
  end,
}
Commands ["server:stop"] = {
  _   = i18n ["server:stop"],
  run = function (cli, ws)
    local serverdata = read (Configuration.server.data_file._)
    options.global (cli)
    options.server (cli)
    options.force  (cli)
    cli:add_option (
      "-t, --token=TOKEN",
      i18n ["option:token"] % {},
      serverdata and serverdata.token or ""
    )
    Commands.args = cli:parse_args ()
    if not Commands.args then
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "stop",
      parameters = {
        server = Commands.args.server,
        token  = Commands.args.token,
        locale = Commands.args.locale,
      },
    })
    local result = ws:receive ()
    if not result then
      result = {
        success = false,
        error   = {
          _ = i18n ["daemon:unreachable"] % {},
        },
      }
    else
      result = Value.decode (result)
    end
    if not result.success and Commands.args.force then
      os.execute ([==[
        if [ -f "{{{pid}}}" ]
        then
          kill -9 $(cat {{{pid}}}) 2> /dev/null
        fi
      ]==] % {
        pid = Configuration.server.pid_file._,
      })
      os.remove (Configuration.server.data_file._)
      os.remove (Configuration.server.pid_file ._)
      result = {
        success  = true,
        response = {
          _ = i18n ["server:force-stop"] % {},
        },
      }
    end
    return show_status (result)
  end,
}

Commands ["show:information"] = {
  _   = i18n ["show:information"],
  run = function (cli, ws)
    options.global (cli)
    options.server (cli)
    Commands.args = cli:parse_args ()
    if not Commands.args then
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "information",
      parameters = {
        locale = Commands.args.locale,
      },
    })
    local result = ws:receive ()
    result = Value.decode (result)
    show_status (result)
    if result.success then
      local max  = 0
      local keys = {}
      for key in pairs (result.response) do
        keys [#keys+1] = key
        max = math.max (max, #key)
      end
      for i = 1, #keys do
        local key   = keys [i]
        local value = result.response [key]
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
    return result
  end,
}

Commands ["show:tos"] = {
  _   = i18n ["show:tos"],
  run = function (cli, ws)
    options.global (cli)
    options.server (cli)
    Commands.args = cli:parse_args ()
    if not Commands.args then
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "tos",
      parameters = {
        locale = Commands.args.locale,
      },
    })
    local result = ws:receive ()
    result = Value.decode (result)
    show_status (result)
    if result.success then
      print (result.response.tos)
      print (Colors ("%{black yellowbg}" .. "digest") ..
             Colors ("%{reset}" .. " => ") ..
             Colors ("%{yellow blackbg}" .. result.response.tos_digest))
    end
    return result
  end,
}

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

Commands ["user:create"] = {
  _   = i18n ["user:create"],
  run = function (cli, ws)
    options.global (cli)
    options.server (cli)
    cli:add_argument (
      "username",
      i18n ["argument:username"] % {}
    )
    cli:add_argument (
      "email",
      i18n ["argument:email"] % {}
    )
    Commands.args = cli:parse_args ()
    if not Commands.args then
      cli:print_help ()
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "tos",
      parameters = {
        locale = Commands.args.locale,
      },
    })
    local tosresult = ws:receive ()
    tosresult = Value.decode (tosresult)
    if not tosresult.success then
      return tosresult
    end
    local digest = tosresult.response.tos_digest
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
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "user:create",
      parameters = {
        username   = Commands.args.username,
        password   = passwords [1],
        email      = Commands.args.email,
        tos_digest = digest,
        locale     = Commands.args.locale,
      },
    })
    local result = ws:receive ()
    result = Value.decode (result)
    return show_status (result)
  end,
}

Commands ["user:authenticate"] = {
  _   = i18n ["user:authenticate"],
  run = function (cli, ws)
    options.global (cli)
    options.server (cli)
    cli:add_argument (
      "username",
      i18n ["argument:username"] % {}
    )
    Commands.args = cli:parse_args ()
    if not Commands.args then
      cli:print_help ()
      os.exit (1)
    end
    io.write (i18n ["argument:password" .. tostring (1)] % {} .. " ")
    local password = getpassword ()
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "user:authenticate",
      parameters = {
        username   = Commands.args.username,
        password   = password,
      },
    })
    local result = ws:receive ()
    result = Value.decode (result)
    return show_status (result)
  end,
}

Commands ["user:delete"] = {
  _   = i18n ["user:delete"],
  run = function (cli, ws)
    options.global         (cli)
    options.server         (cli)
    options.authentication (cli)
    Commands.args = cli:parse_args ()
    if not Commands.args then
      cli:print_help ()
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "user:delete",
      parameters = {},
    })
    local result = ws:receive ()
    result = Value.decode (result)
    return show_status (result)
  end,
}

Commands ["user:reset"] = {
  _   = i18n ["user:reset"],
  run = function (cli, ws)
    options.global (cli)
    options.server (cli)
    cli:add_argument (
      "email",
      i18n ["argument:email"] % {}
    )
    Commands.args = cli:parse_args ()
    if not Commands.args then
      cli:print_help ()
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "user:reset",
      parameters = {
        email = Commands.args.email,
      },
    })
    local result = ws:receive ()
    result = Value.decode (result)
    return show_status (result)
  end,
}

Commands ["user:recover"] = {
  _   = i18n ["user:recover"],
  run = function (cli, ws)
    options.global (cli)
    options.server (cli)
    cli:add_argument (
      "token",
      i18n ["argument:token:validation"] % {}
    )
    Commands.args = cli:parse_args ()
    if not Commands.args then
      cli:print_help ()
      os.exit (1)
    end
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
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "user:recover",
      parameters = {
        token    = Commands.args.token,
        password = passwords [1],
      },
    })
    local result = ws:receive ()
    result = Value.decode (result)
    return show_status (result)
  end,
}

Commands ["user:suspend"] = {
  _   = i18n ["user:suspend"],
  run = function (cli, ws)
    options.global         (cli)
    options.server         (cli)
    options.authentication (cli)
    cli:add_argument (
      "username",
      i18n ["argument:username"] % {}
    )
    Commands.args = cli:parse_args ()
    if not Commands.args then
      cli:print_help ()
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "user:suspend",
      parameters = {
        username = Commands.args.username,
      },
    })
    local result = ws:receive ()
    result = Value.decode (result)
    return show_status (result)
  end,
}

Commands ["user:release"] = {
  _   = i18n ["user:release"],
  run = function (cli, ws)
    options.global         (cli)
    options.server         (cli)
    options.authentication (cli)
    cli:add_argument (
      "username",
      i18n ["argument:username"] % {}
    )
    Commands.args = cli:parse_args ()
    if not Commands.args then
      cli:print_help ()
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "user:release",
      parameters = {
        username = Commands.args.username,
      },
    })
    local result = ws:receive ()
    result = Value.decode (result)
    return show_status (result)
  end,
}

Commands ["user:update"] = {
  _   = i18n ["user:update"],
  run = function (cli, ws)
    options.server         (cli)
    options.authentication (cli)
    cli:add_flag (
      "-d, --debug",
      i18n ["flag:debug"] % {}
    )
    cli:add_option (
      "-a, --avatar=PATH or URL",
      i18n ["option:avatar"] % {}
    )
    cli:add_option (
      "-e, --email=EMAIL",
      i18n ["option:email"] % {}
    )
    cli:add_option (
      "-l, --locale=LOCALE",
      i18n ["option:locale"] % {}
    )
    cli:add_option (
      "-n, --name=FULL-NAME",
      i18n ["option:name"] % {}
    )
    cli:add_option (
      "-o, --organization=ORGANIZATION",
      i18n ["option:organization"] % {}
    )
    cli:add_flag (
      "-p, --password",
      i18n ["flag:password"] % {}
    )
    cli:add_option (
      "-u, --username=USERNAME",
      i18n ["option:username"] % {}
    )
    Commands.args = cli:parse_args ()
    if not Commands.args then
      os.exit (1)
    end
    local password
    if Commands.args.password then
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
      password = passwords [1]
    end
    if Commands.args.avatar then
      if Commands.args.avatar:match "^https?://" then
        local request = require "socket.http" .request
        local body, status = request (Commands.args.avatar)
        if status ~= 200 then
          return {
            success = false,
            error   = {
              _ = i18n ["url:not-found"] % {
                url    = Commands.args.avatar,
                status = status,
              },
            },
          }
        end
        Commands.args.avatar = {
          source  = Commands.args.avatar,
          content = body,
        }
      else
        if Commands.args.avatar:match "^~" then
          Commands.args.avatar = os.getenv "HOME" .. Commands.args.avatar:sub (2)
        end
        local file, err = io.open (Commands.args.avatar, "r")
        if file then
          Commands.args.avatar = {
            source  = Commands.args.avatar,
            content = file:read "*all",
          }
          file:close ()
        else
          return {
            success = false,
            error   = {
              _ = i18n ["file:not-found"] % {
                filename = Commands.args.avatar,
                reason   = err,
              },
            },
          }
        end
      end
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "user:update",
      parameters = {
        avatar       = Commands.args.avatar,
        username     = Commands.args.username,
        email        = Commands.args.email,
        name         = Commands.args.name,
        organization = Commands.args.organization,
        locale       = Commands.args.locale,
        password     = password,
      },
    })
    local result = ws:receive ()
    result = Value.decode (result)
    show_status (result)
    if result.success then
      user_information (result.response)
    end
    return result
  end,
}

Commands ["user:information"] = {
  _   = i18n ["user:information"],
  run = function (cli, ws)
    options.global (cli)
    options.server (cli)
    cli:add_argument (
      "username",
      i18n ["argument:username"] % {}
    )
    Commands.args = cli:parse_args ()
    if not Commands.args then
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "user:information",
      parameters = {
        username = Commands.args.username,
      },
    })
    local result = ws:receive ()
    result = Value.decode (result)
    show_status (result)
    if result.success then
      user_information (result.response)
    end
    return result
  end,
}

Commands ["user:send-validation"] = {
  _   = i18n ["user:send-validation"],
  run = function (cli, ws)
    options.global (cli)
    options.server (cli)
    options.authentication (cli)
    Commands.args = cli:parse_args ()
    if not Commands.args then
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "user:send-validation",
      parameters = {},
    })
    local result = ws:receive ()
    result = Value.decode (result)
    return show_status (result)
  end,
}

Commands ["user:validate"] = {
  _   = i18n ["user:validate"],
  run = function (cli, ws)
    options.global (cli)
    options.server (cli)
    cli:add_argument (
      "token",
      i18n ["argument:token:validation"] % {}
    )
    Commands.args = cli:parse_args ()
    if not Commands.args then
      os.exit (1)
    end
    ws:send (Value.expression {
      server     = Commands.args.server,
      operation  = "user:validate",
      parameters = {
        token = Commands.args.token,
      },
    })
    local result = ws:receive ()
    result = Value.decode (result)
    return show_status (result)
  end,
}

return Commands
