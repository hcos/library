local loader     = require "cosy.loader"

package.searchers [#package.searchers+1] = function (name)
  local result, err = io.open (name, "r")
  if not result then
    return nil, err
  end
  result, err = loadfile (name)
  if not result then
    return nil, err
  end
  return result, name
end

local Logger     = loader.logger
local Repository = loader.repository
local repository = Repository.new ()

Repository.options (repository).create = function () return {} end
Repository.options (repository).import = function () return {} end

repository.internal = {
  locale = "en",
}

repository.whole = {
  [Repository.depends] = {
    repository.internal,
    repository.default,
    repository.etc,
    repository.home,
    repository.pwd,
  },
}

local files = {
  default = "cosy.configuration.default",
  etc     = "/etc/cosy.conf",
  home    = os.getenv "HOME" .. "/.cosy/cosy.conf",
  pwd     = os.getenv "PWD" .. "/cosy.conf",
}

do -- fill the `default` path:
  repository.default = require "cosy.configuration.default"
end

if not _G.js then
  for key, filename in pairs (files) do
    local result, err = loader.hotswap (filename, true)
    if result then
      Logger.debug {
        _      = "configuration:using",
        path   = filename,
        locale = repository.whole.locale._,
      }
      repository [key] = result
    else
      Logger.warning {
        _      = "configuration:skipping",
        path   = filename,
        locale = repository.whole.locale._,
      }
    end
  end
end

return repository.whole
