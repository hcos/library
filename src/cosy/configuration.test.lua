local assert = require "luassert"
local lfs    = require "lfs"

-- Tests for `cosy.configuration`
-- ==========================

local Platform  = require "cosy.platform"

-- JSON reading
-- ------------
do
  local directory = os.tmpname ()
  assert (os.remove (directory))
  assert (lfs.mkdir (directory))
  local filename  = directory .. "/cosy.json"
  local data = {
    key = "value",
  }
  local file = assert (io.open (filename, "w"))
  assert (file:write (Platform.json.encode (data)))
  assert (file:close ())
  Platform.configuration.paths = {
    directory,
  }
  package.loaded ["cosy.configuration"] = nil
  local Configuration = require "cosy.configuration"
  assert.are.same (data, Configuration)
  os.remove (filename)
  assert (lfs.rmdir (directory))
end

-- YAML reading
-- ------------
do
  local directory = os.tmpname ()
  assert (os.remove (directory))
  assert (lfs.mkdir (directory))
  local filename  = directory .. "/cosy.yaml"
  local data = {
    key = "value",
  }
  local file = assert (io.open (filename, "w"))
  assert (file:write (Platform.yaml.encode (data)))
  assert (file:close ())
  Platform.configuration.paths = {
    directory,
  }
  package.loaded ["cosy.configuration"] = nil
  local Configuration = require "cosy.configuration"
  assert.are.same (data, Configuration)
  os.remove (filename)
  assert (lfs.rmdir (directory))
end

-- YAML and JSON reading
-- ---------------------
do
  local directory = os.tmpname ()
  assert (os.remove (directory))
  assert (lfs.mkdir (directory))
  local json_filename  = directory .. "/cosy.json"
  local yaml_filename  = directory .. "/cosy.yaml"
  local data = {
    key = "value",
  }
  local json_file = assert (io.open (json_filename, "w"))
  assert (json_file:write (Platform.json.encode (data)))
  assert (json_file:close ())
  local yaml_file = assert (io.open (yaml_filename, "w"))
  assert (yaml_file:write (Platform.yaml.encode (data)))
  assert (yaml_file:close ())
  Platform.configuration.paths = {
    directory,
  }
  package.loaded ["cosy.configuration"] = nil
  assert.has.error (function () require "cosy.configuration" end)
  os.remove (json_filename)
  os.remove (yaml_filename)
  assert (lfs.rmdir (directory))
end

-- Merge configurations
-- --------------------
do
  local directories = {}
  do
    local directory = os.tmpname ()
    assert (os.remove (directory))
    assert (lfs.mkdir (directory))
    local filename  = directory .. "/cosy.json"
    local data = {
      a = {
        b = 1,
      },
    }
    local file = assert (io.open (filename, "w"))
    assert (file:write (Platform.json.encode (data)))
    assert (file:close ())
    directories [1] = directory
  end
  do
    local directory = os.tmpname ()
    assert (os.remove (directory))
    assert (lfs.mkdir (directory))
    local filename  = directory .. "/cosy.yaml"
    local data = {
      a = {
        c = 2,
      },
    }
    local file = assert (io.open (filename, "w"))
    assert (file:write (Platform.yaml.encode (data)))
    assert (file:close ())
    directories [2] = directory
  end
  Platform.configuration.paths = directories
  package.loaded ["cosy.configuration"] = nil
  local Configuration = require "cosy.configuration"
  assert.are.same (Configuration, {
    a = {
      b = 1,
      c = 2,
    },
  })
  assert (os.remove (directories [1] .. "/cosy.json"))
  assert (os.remove (directories [2] .. "/cosy.yaml"))
  assert (lfs.rmdir (directories [1]))
  assert (lfs.rmdir (directories [2]))
end

