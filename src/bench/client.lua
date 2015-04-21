local loader        = require "cosy.loader"
local Library       = loader.library
local Configuration = loader.configuration

do
  os.execute "redis-cli flushall"
end

local ok, err = pcall (function ()
  local function show (x)
    print (loader.value.expression (x))
  end
  local lib   = Library.connect "http://127.0.0.1:8080/"
  local info  = lib.information ()
  show (info)
  local tos   = lib.tos ()
  show (tos)
  local token = lib.create_user {
    username   = "alinard",
    password   = "password",
    email      = "alban.linard@gmail.com",
    tos_digest = tos.tos_digest:upper (),
    locale     = "en",
  }
  show (token)
  local token = lib.authenticate {
    username = "alinard",
    password = "password",
  }
  show (token)
--[==[
  lib.suspend_user {
    token    = token,
    username = "alinard",
  }
  lib.reset_user {
    email = "alban.linard@gmail.com",
  }
  --]==]
  
  local start = require "socket".gettime ()
  local n     = 1000
  for _ = 1, n do
    assert (lib.information ().name == Configuration.server.name._)
  end
  local finish = require "socket".gettime ()
  print (math.floor (n / (finish - start)), "requests/second")
end)
if not ok then
  if type (err) == "table" then
    local message = loader.i18n (err)
    print ("error:", message, loader.value.expression (err))
  else
    print (err)
  end
end