local loader = require "cosy.loader"

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

if not _G.js then
  local updater = loader.scheduler.addthread (function ()
    while true do
      local redis = loader.redis ()
      -- http://stackoverflow.com/questions/4006324
      local script = { [[
        local n    = 1000
        local keys = redis.call ("keys", ARGV[1])
        for i=1, #keys, n do
          redis.call ("del", unpack (keys, i, math.min (i+n-1, #keys)))
        end
      ]] }
      for name in pairs (loader.configuration.dependencies) do
        local source = loader.configuration.dependencies [name]
        local url    = tostring (source._)
        if url:match "^http" then
          script [#script+1] = ([[
            redis.call ("set", "foreign:%{name}", "%{source}")
          ]]) % {
            name   = name,
            source = url,
          }
        end
      end
      script [#script+1] = [[
        return true
      ]]
      script = table.concat (script)
      redis:eval (script, 0, "foreigns:*")
      os.execute ([[
        find %{root}/cache -type f -delete
      ]] % {
        root = loader.nginx.directory,
      })
      loader.logger.debug {
        _ = "configuration:updated",
      }
      loader.nginx.update ()
      loader.scheduler.sleep (-1)
    end
  end)

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

  for key, name in pairs (files) do
    local result = loader.hotswap.try_require (name)
    if result then
      loader.hotswap.on_change [name] = function ()
        loader.scheduler.wakeup (updater)
      end
      loader.logger.debug {
        _      = "configuration:using",
        path   = name,
        locale = repository.whole.locale._,
      }
      repository [key] = result
    else
      loader.logger.warning {
        _      = "configuration:skipping",
        path   = name,
        locale = repository.whole.locale._,
      }
    end
  end
end

return repository.whole
