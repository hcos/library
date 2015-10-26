return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.daemon = {
    interface = "127.0.0.1",
    port      = 0,
    data      = os.getenv "HOME" .. "/.cosy/daemon.data",
    pid       = os.getenv "HOME" .. "/.cosy/daemon.pid",
  }

end
