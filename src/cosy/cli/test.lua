_G._TEST = true

-- These lines are required to correctly run tests:
require "busted.runner" ()
local loader = require "cosy.loader.lua" {
  logto = false,
}
local Configuration = loader.load "cosy.configuration"
local Cli           = loader.require "cosy.cli"

Cli.default_server = "http://127.0.0.1:8080"
Cli.default_locale = "en"

Configuration.load {
  "cosy.cli",
}
Configuration.library = {
  timeout = 1,
}

describe ("Module cosy.cli", function ()

  before_each (function ()
    Configuration.cli.data = os.tmpname()
  end)

  after_each (function ()
    os.remove (Configuration.cli.data)
  end)

  describe ("parsing options by method configure", function ()

    it ("should set the server if the --server option is set", function ()
      local cli = Cli.new ()
      cli:configure {
        "--server=http://127.0.0.1:8080",
      }
      assert.are.equal (cli.server, "http://127.0.0.1:8080")
    end)

    it ("should use a default server if the --server option is missing", function ()
      local cli = Cli.new ()
      cli:configure {}
      assert.are.equal (cli.server, Cli.default_server)
    end)

    it ("should pick the last one if several --server options are set", function ()
      local cli = Cli.new ()
      cli:configure {
        "--server=http://127.0.0.1:8090",
        "--server=http://127.0.0.1:8080",
      }
      assert.are.equal (cli.server, "http://127.0.0.1:8080")
    end)

    it ("should fail if the --server option is not a HTTP(s) URL", function ()
      local cli = Cli.new ()
      assert.has.errors (function ()
        cli:configure {
          "--server=some.server.org",
        }
      end)
    end)

  end)

  describe ("saving options by method configure", function ()

    it ("should detect the --server", function ()
      do
        local cli = Cli.new ()
        cli:configure {
          "--server=http://127.0.0.1:8080",
        }
        -- assert server was found and set
        assert.are.equal (cli.server, "http://127.0.0.1:8080")
      end
      do
        local cli = Cli.new ()
        cli:configure {}
        -- assert config was saved to config file
        assert.are.equal (cli.server, "http://127.0.0.1:8080")
      end
    end)

  end)

end)
