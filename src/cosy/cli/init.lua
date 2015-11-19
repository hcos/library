os.remove (os.getenv "HOME" .. "/.cosy/client.log")

local Arguments = require "argparse"

local name = os.getenv "COSY_PREFIX" .. "/bin/cosy"
name = name:gsub (os.getenv "HOME", "~")

local Cli = {}

Cli.__index = Cli

function Cli.new ()
  return setmetatable ({}, Cli)
end

-----------------------------
--  While not found Cli tries to determine what server it will connect to
--    by scanning in that order :
--  1. --server=xxx   cmd line option
--  2. ~/.cosy/cli.data config file (ie last server used)
--  3. configuration

Cli.default_server = "http://public.cosyverif.lsv.fr"
Cli.default_locale = (os.getenv "LANG" or "en"):match "[^%.]+":gsub ("_", "-")

function Cli.configure (cli, arguments)
  assert (getmetatable (cli) == Cli)

  local Copas   = require "copas"  ---- WARNING WE CANNOT WAIT TO GET IT FROM THE SERVER
  local Lfs     = require "lfs"  -- C module : won't be reloaded from server
  local Json    = require "cjson"  -- lua tables are transcoded into json for server  (pkg comes with lua socket)
  local Ltn12   = require "ltn12"  -- to store the content of the requests ( pkgcomes with lua socket)
  local Mime    = require "mime"
  local Request = require "socket.http".request
  local Hotswap = require "hotswap.http"

  local default_server = Cli.default_server
  local default_locale = Cli.default_locale

  local cosy_dir = os.getenv "HOME" .. "/.cosy"
    -- reads the config
  local data_filename = cosy_dir .. "/cli.txt"
  pcall (function ()
    for line in io.lines (data_filename) do
      local value = line:match "^server:(.*)"
      if value then
        default_server = value
      end
    end
    for line in io.lines (data_filename) do
      local value = line:match "^locale:(.*)"
      if value then
        default_locale = value
      end
    end
  end)
  local parser = Arguments () {
    name        = name,
    description = "cosy command-line interface",
    add_help    = {
      action = function () end
    },
  }
  parser:require_command (false)
  parser:option "-s" "--server" {
    description = "server URL",
    default     = default_server,
  }
  parser:option "-l" "--locale" {
    description = "locale for messages",
    default     = default_locale,
  }
  parser:argument "command" {
    args = "*",
    description = "command to run and its options and arguments",
  }
  -- Warning: UGLY hack.
  -- `argparse` stops execution when `pparse` is used with a `--help` option.
  -- But we want to continue to get the full help message from `Cli.start`.
  -- Thus, we redefine temporarily `os.exit` to do nothing.
  local _exit    = _G.os.exit
  _G.os.exit     = function () end
  local ok, args = parser:pparse (arguments)
  _G.os.exit     = _exit
  -- End of UGLY hack.
  if ok then
    cli.server = args.server
    cli.locale = args.locale
  else
    cli.server = default_server
    cli.locale = default_locale
  end
  assert (cli.server)

  -- trim eventuel trailing /   http://server/
  cli.server = cli.server:gsub ("/+$","")
  if not cli.server:match "^https?://" then
    error {
      _      = "server:not-url",
      server = cli.server,
    }
  end

  -- Test is server is valid:
  local _, code = Request (cli.server .. "/lua/cosy.loader.lua")
  if code ~= 200 then
    error {
      _      = "server:not-cosy",
      server = cli.server,
    }
  end

  do -- save server name for next cli launch
    Lfs.mkdir (cosy_dir)
    local file, err = io.open (data_filename, "w")
    if file then
      file:write ("server:" .. cli.server .. "\n")
      file:write ("locale:" .. cli.locale .. "\n")
      file:close ()
    else
      print (err)
    end
  end -- save server name for next cli launch

  --  every dowloaded lua package will be saved in ~/.cosy/lua/base64(server_name)
  local package_dir = cosy_dir .. "/lua/"
  local server_dir  = package_dir .. Mime.b64 (cli.server)
  Lfs.mkdir (package_dir)
  Lfs.mkdir (server_dir)

  local hotswap = Hotswap {
    storage = server_dir, -- where to save the lua files
    encode = function (t)
      local data = Json.encode (t)
      return {
        url     = cli.server .. "/luaset",
        method  = "POST",
        headers = {
          ["Content-Length"] = #data,
        },
        source  = Ltn12.source.string (data),
      }
    end,
    decode = function (t)
      if t.code == 200 then
        return Json.decode (t.body)
      end
    end,
  }

-- In order to download lua modules (required by the client) from the server
-- we replace the Lua require function
--      by the hotswap.require which will also save lua packages into "server_dir"
  cli.loader = hotswap.require "cosy.loader.lua" {
    hotswap   = hotswap,
    scheduler = Copas,
    logto     = os.getenv "HOME" .. "/.cosy/client.log",
  }
end

function Cli.start (cli)
  assert (getmetatable (cli) == Cli)

  do
    local ok, err = pcall (cli.configure, cli, _G.arg)
    if not ok then
      local Loader = require "cosy.loader.lua"
      local loader = Loader ()
      local Colors = loader.require "ansicolors"
      local I18n   = loader.load "cosy.i18n"
      local i18n   = I18n.load {
        "cosy.cli",
      }
      if type (err) == "table" and err._ then
        print (Colors ("%{red blackbg}" .. i18n ["failure"] % {}))
        print (Colors ("%{white redbg}" .. i18n [err._] % err))
      else
        print ("An error happened. Maybe the client was unable to download sources from " .. (cli.server or "no server") .. ".")
        local errorfile = os.tmpname ()
        local file      = io.open (errorfile, "w")
        file:write (tostring (err) .. "\n")
        file:write (debug.traceback () .. "\n")
        file:close ()
        print ("See error file " .. Colors ("%{white redbg}" .. errorfile) .. " for more information.")
      end
      return false
    end
  end

  local loader = cli.loader

  local Configuration = loader.load "cosy.configuration"
  local File          = loader.load "cosy.file"
  local I18n          = loader.load "cosy.i18n"
  local Library       = loader.load "cosy.library"
  local Colors        = loader.require "ansicolors"

  Configuration.load {
    "cosy.cli",
  }
  local i18n = I18n.load {
    "cosy.cli",
  }
  i18n._locale = Configuration.cli.locale
  print (Colors ("%{green blackbg}" .. i18n ["client:server"] % {
    server = cli.server,
  }))

  local parser = Arguments () {
    name        = name,
    description = i18n ["client:command"] % {},
  }
  parser:option "-s" "--server" {
    description = i18n ["option:server"] % {},
    default     = cli.server,
  }
  parser:option "-l" "--locale" {
    description = i18n ["option:locale"] % {},
    default     = Configuration.cli.locale,
  }

  local client = Library.connect (cli.server)
  if not client then
    print (Colors ("%{white redbg}" .. i18n ["failure"] % {}),
           Colors ("%{white redbg}" .. i18n ["server:unreachable"] % {}))
    return false
  end

  local data = File.decode (Configuration.cli.data) or {}
  local who  = client.user.authentified_as {
    authentication = data.authentication,
  }
  if who.identifier then
    print (Colors ("%{green blackbg}" .. i18n ["client:identified"] % {
      user = who.identifier,
    }))
  end

  local Commands = loader.load "cosy.cli.commands"
  local commands = Commands.new {
    parser = parser,
    client = client,
  }
  local ok, result = xpcall (function ()
      Commands.parse (commands)
    end, function (err)
      print (Colors ("%{white redbg}" .. i18n ["error:unexpected"] % {}))
      print (err)
      print (debug.traceback ())
    end)
  if not ok and result then
    print (Colors ("%{red blackbg}" .. i18n ["failure"] % {}))
    print (Colors ("%{white redbg}" .. i18n (result.error).message))
  end
  return ok
end

function Cli.stop (cli)
  assert (getmetatable (cli) == Cli)
end

if not _G._TEST then
  local cli = Cli.new ()
  if cli:start () then
    os.exit (0)
  else
    os.exit (1)
  end
end

return Cli
