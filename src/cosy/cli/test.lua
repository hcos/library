-- These lines are required to correctly run tests:
require "cosy.loader.busted"
require "busted.runner" ()
local File = require "cosy.file"

describe ("Module cosy.cli", function ()

  local Cli
  local Configuration

  before_each (function ()
    package.loaded ["cosy.cli"] = nil  -- reload to reset
    Cli = require "cosy.cli"
    Configuration = require "cosy.configuration"
    Configuration.cli.data = os.tmpname()
    Configuration.cli.server = "dummy_default"  -- override to a known default value
  end)

  after_each (function ()
    os.remove( Configuration.cli.data )
  end)

  describe ("parsing options by method configure", function ()

    for _, key in ipairs {
      "server",
      -- "color",
    } do

      it ("should detect the --" .. key, function ()
        Cli.configure {
          "--debug=true",
          "--".. key .. "=any_value",
        }
        assert.are.equal (Cli [key], "any_value")
      end)

      it ("should detect --" .. key .. " is missing", function()
        Cli.configure {
          "--debug=true",
          "-".. key .. "=any_value",
        }
        assert.are.equal (Cli [key] , "dummy_default")
      end)

      it ("should fail by detecting several --" .. key, function()
        assert.has.errors (function ()
          Cli.configure {
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
      Cli.configure {
        "--debug=true",
        "--server=server_uri_from_cmd_line",
      }
      -- assert server was found was set
      assert.are.equal (Cli.server, "server_uri_from_cmd_line")
      -- assert config was saved to config file
      local saved_config = File.decode (Configuration.cli.data)
      assert.are.equal (saved_config.server, Cli.server)
    end)

    -- case server defined by file
    -- case server defined by default
    -- case no server defined


  end)

end)
