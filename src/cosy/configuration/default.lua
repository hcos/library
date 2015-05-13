return {
  redis = {
    host      = "127.0.0.1",
    port      = 6379,
    retry     = 5,
    database  = 0,
    pool_size = 5,
  },
  http = {
    host    = "*",
    port    = 8080,
    salt    = "cosyverif",
    timeout = 5,
  },
  websocket = {
    host = "127.0.0.1",
  },
  www = {
    root = (os.getenv "PWD") .. "/www",
  },
  smtp = {
    timeout = 2,
  },
  client = {
    timeout = 5,
  },
  data = {
    username = {
      min_size = 1,
      max_size = 32,
    },
    password = {
      min_size = 1,
      max_size = 128,
      time     = 0.020,
    },
    name = {
      min_size = 1,
      max_size = 128,
    },
    email = {
      max_size = 128,
    },
  },
  token = {
    algorithm = "HS512",
  },
  locale = "en",
  expiration = {
    account        = 24 * 3600, -- 1 day
    validation     =  1 * 3600, -- 1 hour
    authentication =  1 * 3600, -- 1 hour
    administration =  99 * 365 * 24 * 3600, -- 99 years
  },
  reputation = {
    at_creation = 10,
    suspend     = 50,
  },
  dependencies = {
    expiration = 24 * 3600, -- 1 day
    ["js/lua.vm.js"] = "https://raw.githubusercontent.com/kripken/lua.vm.js/master/dist/lua.vm.js",
    ["js/sjcl.js"  ] = "http://bitwiseshiftleft.github.io/sjcl/sjcl.js",
  },
  statistics = "http://stats.cosyverif.org",
}
