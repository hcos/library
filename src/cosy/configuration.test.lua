-- Tests for `cosy.configuration`
-- ==========================

                  require "busted"
local assert    = require "luassert"
local Platform  = require "cosy.platform"
local Data      = require "cosy.data"

Platform.logger.enabled = false

describe ("Configuration", function ()
  -- In all these tests, we create dummy configuration files,
  -- in all the formats supported by configuration.
  -- These files replace the default ones in the `Platform`,
  -- so the configuration reads them.
    
  local lfs = require "lfs"
  
  it ("should be able to read JSON", function ()
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
    assert.are.same (data, Data.raw (Configuration) [filename])
    os.remove (filename)
    assert (lfs.rmdir (directory))
  end)
  
  it ("should be able to read YAML", function ()
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
    assert.are.same (data, Data.raw (Configuration) [filename])
    os.remove (filename)
    assert (lfs.rmdir (directory))
  end)
  
  it ("must raise an error when reading both JSON and YAML", function ()
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
  end)

  it ("must have a 'internal' layer", function ()
    package.loaded ["cosy.configuration"] = nil
    local Configuration = require "cosy.configuration"
    Configuration.internal.x = 1
    assert.are.equal (Configuration.internal.x._, 1)
  end)

  it ("must have a 'default' layer", function ()
    package.loaded ["cosy.configuration"] = nil
    local Configuration = require "cosy.configuration"
    Configuration.default.x = 1
    assert.are.equal (Configuration.default.x._, 1)
  end)

  it ("must merge layers", function ()
    package.loaded ["cosy.configuration"] = nil
    local Configuration = require "cosy.configuration"
    Configuration.internal.x = 1
    Configuration.default .y = 1
    assert.are.equal (Configuration.whole.x._, 1)
    assert.are.equal (Configuration.whole.y._, 1)
  end)

end)