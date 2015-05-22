local Loader        = require "cosy.loader"
local Configuration = require "cosy.configuration"
local I18n          = require "cosy.i18n"
local Library       = require "cosy.library"
local Value         = require "cosy.value"

do
  os.execute "redis-cli flushall"
end

local token = arg [1]

local ok, err = pcall (function ()
  local function show (name, x)
    print (name, Value.expression (x))
  end
  local lib   = Library.connect "http://127.0.0.1:8080/"
--  local lib   = Library.connect "http://cosy.linard.fr/"
  local info  = lib.information ()
--  show ("information", info)
--  print (lib.statistics ())
  local tos   = lib.tos ()
  show ("terms of service", tos)
  local token = lib.create_user {
    username   = "alinard",
    password   = "password",
    email      = "alban.linard@gmail.com",
    tos_digest = tos.tos_digest:upper (),
    locale     = "en",
  }
  show ("create user", token)
  local token = lib.authenticate {
    username = "alinard",
    password = "password",
  }
  show ("authenticate", token)
--  local result = lib.suspend_user {
--    token    = token,
--    username = "alinard",
--  }
--  show ("suspend user", result)
--  local result = lib.delete_user {
--    token = token,
--  }
--  show ("delete user", result)
--  local token = lib.authenticate {
--    username = "alinard",
--    password = "password",
--  }
--  show ("authenticate", token)
  --[==[
  lib.suspend_user {
    token    = token,
    username = "alinard",
  }
  lib.reset_user {
    email = "alban.linard@gmail.com",
  }
  --]==]
  --[==[
  local start = require "socket".gettime ()
  local n     = 1000
  for _ = 1, n do
    assert (lib.information ().name)
  end
  local finish = require "socket".gettime ()
  print (math.floor (n / (finish - start)), "requests/second")
  --]==]
  lib.stop {
    token = token,
  }
end)
if not ok then
  if type (err) == "table" then
    local message = I18n (err)
    print ("error:", message, Value.expression (err))
  else
    print (err)
  end
end