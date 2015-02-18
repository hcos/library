return {
  redis = {
    host      = "127.0.0.1",
    port      = 6379,
    database  = 0,
    pool_size = 5,
  },
  server = {
    host    = "127.0.0.1",
    port    = 8080,
    threads = 2,
  },
  data = {
    username = {
      min_size = 1,
      max_size = 32,
    },
    password = {
      min_size = 10,
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
    locale = {
      min_size = 2,
      max_size = 5,
    },
  },
  smtp = {
  },
  network = {
    compression = "snappy",
  },
  locale = {
    default = "en",
  },
}
