local Runner = require "busted.runner"
require "cosy.loader"
Runner ()


describe ("Module cosy.cli", function ()

  describe("method configure", function()

    local Cli
    before_each(function()
      package.loaded["cosy.cli"] = nil
      Cli = require "cosy.cli"
    end)

    for _, key in ipairs {
      "server",
      "color",
    } do

      it("should detect the --" .. key, function()
        Cli.configure {
          "--debug=true",
          "--".. key .. "=any_value",
        }
        assert.are.equal(Cli[key], "any_value")
      end)

      it("should detect --" .. key .. " is missing", function()
        Cli.configure {
          "--debug=true",
          "-".. key .. "=any_value",
        }
        assert.is_nil( Cli[key])
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
