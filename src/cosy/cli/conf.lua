return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.cli = {
    directory = os.getenv "HOME" .. "/.cosy",
    locale    = (os.getenv "LANG" or "en"):match "[^%.]+":gsub ("_", "-"),
    log       = os.getenv "HOME" .. "/.cosy/cli.log",
    packages_directory = os.getenv "HOME" .. "/.cosy/lua",
    packages_data = os.getenv "HOME" .. "/.cosy/lua.data",
    server    = "http://cosyverif.org/",
  }

end
