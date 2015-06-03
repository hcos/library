local Configuration = require "cosy.configuration"
Configuration.load "cosy"

local I18n          = require "cosy.i18n"
local Value         = require "cosy.value"

local i18n   = I18n.load "cosy.commands-i18n"
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

local function addoptions (cli)
  cli:add_option (
    "-s, --server=SERVER",
    i18n ["option:server"] % {},
    Configuration.cli.default_server._
  )
  cli:add_option (
    "-l, --locale=LOCALE",
    i18n ["option:locale"] % {},
    Configuration.cli.default_locale._
  )
end

Commands ["daemon:stop"] = {
  _   = i18n ["daemon:stop"],
  run = function (cli, ws)
    Commands.args = cli:parse_args ()
    if not Commands.args then
      os.exit (1)
    end
    ws:send (Value.expression "daemon-stop")
    local result = ws:receive ()
    if not result.success then
      os.remove (Configuration.daemon.data_file._)
      os.remove (Configuration.daemon.pid_file ._)
    end
    return true
  end,
}

Commands ["server:start"] = {
  _   = i18n ["server:start"],
  run = function (cli, ws)
    cli:add_option (
      "-c, --clean",
      i18n ["option:clean"] % {}
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
        kill -9 $(cat {{{pid}}})
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
      local m18n = I18n.load "cosy.daemon-i18n"
      return {
        success = false,
        error   = {
          _ = m18n ["server:unreachable"] % {},
        },
      }
    end
    return true
  end,
}
Commands ["server:stop"] = {
  _   = i18n ["server:stop"],
  run = function (cli, ws)
    local serverdata = read (Configuration.server.data_file._)
    addoptions (cli)
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
      local m18n = I18n.load "cosy-i18n"
      return {
        success = false,
        error   = {
          _ = m18n ["daemon:unreachable"] % {},
        },
      }
    end
    return Value.decode (result)
  end,
}

Commands ["show:information"] = {
  _   = i18n ["show:information"],
  run = function (cli, ws)
    addoptions (cli)
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
    return Value.decode (result)
  end,
}

Commands ["show:tos"] = {
  _   = i18n ["show:tos"],
  run = function (cli, ws)
    addoptions (cli)
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
    return Value.decode (result)
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
    addoptions (cli)
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
    return Value.decode (result)
  end,
}

Commands ["user:authenticate"] = {
  _   = i18n ["user:authenticate"],
  run = function (cli, ws)
    addoptions (cli)
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
    return Value.decode (result)
  end,
}

return Commands
