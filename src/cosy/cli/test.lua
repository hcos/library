-- These lines are required to correctly run tests:
require "cosy.loader.busted"
require "busted.runner" ()
local File          = require "cosy.file"
local Cli           = require "cosy.cli"
local Configuration = require "cosy.configuration"

describe ("Module cosy.cli", function ()

  before_each (function ()
    Configuration.cli.data   = os.tmpname()
    Configuration.cli.server = "dummy_default"  -- override to a known default value
  end)

  after_each (function ()
    os.remove (Configuration.cli.data)
  end)

  describe ("parsing options by method configure", function ()

    for _, key in ipairs {
      "server",
      -- "color",
    } do

      it ("should detect the --" .. key, function ()
        local cli = Cli.new ()
        cli:configure {
          "--debug=true",
          "--".. key .. "=any_value",
        }
        assert.are.equal (cli [key], "any_value")
      end)

      it ("should detect --" .. key .. " is missing", function ()
        local cli = Cli.new ()
        cli:configure {
          "--debug=true",
          "-".. key .. "=any_value",
        }
        assert.are.equal (cli [key] , "dummy_default")
      end)

      it ("should fail by detecting several --" .. key, function ()
        local cli = Cli.new ()
        assert.has.errors (function ()
          cli:configure {
            "--debug=true",
            "--".. key .. "=any_value",
            "--".. key .. "=any_value",
          }
        end)
      end)

    end

  end)

  describe ("saving options by method configure", function ()

    it ("should detect the --server", function ()
      local cli = Cli.new ()
      cli:configure {
        "--debug=true",
        "--server=server_uri_from_cmd_line",
      }
      -- assert server was found and set
      assert.are.equal (cli.server, "server_uri_from_cmd_line")
      -- assert config was saved to config file
      local saved_config = File.decode (Configuration.cli.data)
      assert.are.equal (saved_config.server, cli.server)
    end)

  end)

end)
