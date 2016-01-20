return function (loader)

  local Webclient = loader.load "cosy.webclient"
  local I18n      = loader.load "cosy.i18n"
  local i18n      = I18n.load {
    "cosy.webclient.headbar",
  }

  local HeadBar    = {}
  HeadBar.template = Webclient.template "cosy.webclient.headbar"

  return function (options)
    Webclient.run (function ()
      Webclient.show {
        where    = options.where,
        template = HeadBar.template,
        data     = {
          title = Webclient.client.server.information {}.name,
        },
        i18n     = i18n,
      }
      Webclient.window:eval [[
        var height = $(".navbar-fixed-top").height ();
        $(".main-content").css ({
          "margin-top": (height + 1 ) + "px"
        });
      ]]
      Webclient.document:getElementById "home".onclick = function ()
        loader.load "cosy.webclient.dashboard" {
          where = "main",
        }
        return false
      end
      loader.load "cosy.webclient.authentication" {
        where = "headbar:user",
      }
    end)
  end

end
