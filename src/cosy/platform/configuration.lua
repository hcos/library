local hotswap    = require "hotswap"
local Value      = hotswap "cosy.platform.value"
local Logger     = hotswap "cosy.platform.logger"
local Repository = hotswap "cosy.repository"
local repository = Repository.new ()

Repository.options (repository).create = function () end
Repository.options (repository).import = function () end

repository.internal = {}
local default = hotswap "cosy.configuration.default"
if default then
  repository.default = default
end

local loaded = {
  repository.internal,
  repository.default,
}

if not _G.js then
  for _, path in ipairs {
    "/etc",
    os.getenv "HOME" .. "/.cosy",
    os.getenv "PWD",
  } do
    local filename = path .. "/cosy.conf"
    local ok, err  = pcall (function ()
      local handle  = io.open (filename, "r")
      if not handle then
        error "file does not exist"
      end
      local content = handle:read "*all"
      content       = Value.decode (content)
      repository [filename] = content
      loaded [#loaded+1] = repository [filename]
      io.close (handle)
    end)
    if ok then
      Logger.debug {
        _      = "configuration:using",
        path   = path,
        locale = default.locale._ or "en",
      }
    else
      Logger.warning {
        _      = "configuration:skipping",
        path   = path,
        reason = err,
        locale = default.locale._ or "en",
      }
    end
  end
end

repository.whole = {
  [Repository.depends] = loaded,
}

return repository.whole
