return {
  redis = {
    host      = "127.0.0.1",
    port      = 6379,
    retry     = 5,
    database  = 0,
    pool_size = 5,
  },
  http = {
    nginx   = "nginx",
    host    = "*",
    port    = 8080,
    salt    = "cosyverif",
    timeout = 5,
  },
  websocket = {
    host = "127.0.0.1",
  },
  library = {
    retry = 5,
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
    ["/js/lua.vm.js"] = "https://kripken.github.io/lua.vm.js/lua.vm.js",
    ["/js/sjcl.js"  ] = "http://bitwiseshiftleft.github.io/sjcl/sjcl.js",
    ["/js/jquery.js"] = "http://code.jquery.com/jquery-2.1.4.min.js",
  },
  statistics = "http://stats.cosyverif.org",
  config = {
    directory  = os.getenv "HOME" .. "/.cosy",
    nginx = {
      pid_file    = os.getenv "HOME" .. "/.cosy/nginx.pid",
    },
    server = {
      socket_file = os.getenv "HOME" .. "/.cosy/server.socket",
      token_file  = os.getenv "HOME" .. "/.cosy/server.token",
      log_file    = os.getenv "HOME" .. "/.cosy/server.log",
    },
    daemon = {
      socket_file = os.getenv "HOME" .. "/.cosy/daemon.socket",
      log_file    = os.getenv "HOME" .. "/.cosy/daemon.log",
    },
    cli = {
      data_file   = os.getenv "HOME" .. "/.cosy/cli.data",
    },
  },
}
