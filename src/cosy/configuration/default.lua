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
    salt    = "cosyverif",
    rounds  = 6,
    timeout = 5,
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
  },
  reputation = {
    at_creation = 10,
    suspend     = 50,
  }
}
