return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.editor = {
    interface = "127.0.0.1",
    port      = 0, -- random port
    -- Warning: we cannot simply create a "editor.data" file,
    -- as we will have several editors running in parallel.
    data      = os.getenv "HOME" .. "/.cosy/editor{{{pid}}}.data",
    logfile   = os.getenv "HOME" .. "/.cosy/editor{{{pid}}}.log",
    resource  = nil,
    locale    = "en",
  }

end
