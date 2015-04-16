local Configuration = require "cosy.configuration"
local Platform      = require "cosy.platform"
local Library       = require "cosy.interface.library"

do
  os.execute "redis-cli flushall"
end

local ok, err = pcall (function ()
  local function show (x)
    print (Platform.value.expression (x))
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
    tos_digest = tos.tos_digest,
    locale     = "en",
  }
  show (token)
  
  local start = require "socket".gettime ()
  local n     = 0
  for _ = 1, n do
    assert (lib.information ().name == Configuration.server.name._)
  end
  local finish = require "socket".gettime ()
  print (math.floor (n / (finish - start)))
end)
if not ok then
  print ("error", Platform.i18n (err))
end