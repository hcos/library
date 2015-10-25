-- These lines are required to correctly run tests:
require "busted.runner" ()
local loader = require "cosy.loader.lua" {
  logto = false,
}
local Configuration = loader.load "cosy.configuration"
local Cli           = loader.require "cosy.cli"

Configuration.load {
  "cosy.cli",
}

describe ("Module cosy.cli", function ()

  before_each (function ()
    Configuration.cli.data   = os.tmpname()
    Configuration.cli.server = "dummy_default"  -- override to a known default value
  end)

  after_each (function ()
    os.remove (Configuration.cli.data)
  end)

  describe ("parsing options by method configure", function ()

    it ("should set the server if the --server option is set", function ()
      local cli = Cli.new ()
      cli:configure {
        "--server=http://public.cosyverif.org",
      }
      assert.are.equal (cli.server, "http://public.cosyverif.org")
    end)

    it ("should use a default server if the --server option is missing", function ()
      local cli = Cli.new ()
      cli:configure {}
      assert.is.not_nil (cli.server)
    end)

    it ("should fail if several --server options are set", function ()
      local cli = Cli.new ()
      assert.has.errors (function ()
        cli:configure {
          "--server=http://public.cosyverif.org",
          "--server=http://private.cosyverif.org",
        }
      end)
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
          "--server=http://my.server.org",
        }
        -- assert server was found and set
        assert.are.equal (cli.server, "http://my.server.org")
      end
      do
        local cli = Cli.new ()
        cli:configure {}
        -- assert config was saved to config file
        assert.are.equal (cli.server, "http://my.server.org")
      end
    end)

  end)

end)
