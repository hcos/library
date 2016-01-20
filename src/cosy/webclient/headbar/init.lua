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
          title = loader.client.server.information {}.name,
        },
        i18n     = i18n,
      }
      loader.window:eval [[
        $(".main-content").css({"margin-top": (($(".navbar-fixed-top").height()) + 1 )+"px"});
      ]]
      loader.load "cosy.webclient.authentication" {
        where = "headbar:user",
      }
    end)
  end

end
