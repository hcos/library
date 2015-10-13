if not package.searchpath
or #setmetatable ({}, { __len = function () return 1 end }) ~= 1
then
  error "Cosy requires Lua >= 5.2 or Luajit with 5.2 compatibility to run."
end

local Loader = {}

local loader = setmetatable ({}, Loader)

if _G.logfile then
  loader.logfile = _G.logfile
end

function loader.configure ()
  require "cosy.string"

  local Coromake = require "coroutine.make"
  _G.coroutine   = Coromake ()
end

return loader
