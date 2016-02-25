return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.editor = {
    directory = loader.home .. "/editor",
    data      = loader.home .. "/editor/{{{pid}}}.data",
    logfile   = loader.home .. "/editor/{{{pid}}}.log",
    interface = "localhost",
    port      = 0,
    resource  = nil,
  }

end
