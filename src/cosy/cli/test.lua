local Runner = require "busted.runner"
require "cosy.loader"
Runner ()

local Cli = require "cosy.cli"

describe ("Module cosy.cli", function ()

  describe("method configure", function()

    for _, key in ipairs {
      "server",
      "color",
    } do

      it("should detect the --" .. key, function()
        Cli.configure {
          "--debug=true",
          "--".. key .. "=any_value",
        }
        assert.are.equal(Cli.server, "any_value")
      end)

      it("should detect --" .. key .. " is missing", function()
        Cli.configure {
          "--debug=true",
          "-".. key .. "=any_value",
        }
        assert.is_nil( Cli.server)
      end)

      it("should fail by detecting several --" .. key, function()
        assert.has.errors( function ()
          Cli.configure {
            "--debug=true",
            "--".. key .. "=any_value",
            "--".. key .. "=any_value",
          }
        end)
      end)
    end

  end)

end)
