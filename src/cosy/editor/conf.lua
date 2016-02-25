return function (loader)

  local Default = loader.load "cosy.configuration.layers".default

  Default.editor = {
    data      = loader.home .. "/editor-{{{pid}}}.data",
    logfile   = loader.home .. "/editor-{{{pid}}}.log",
    resource  = nil,
  }

end
