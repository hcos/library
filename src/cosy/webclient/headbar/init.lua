return function (loader)

  local Webclient = loader.load "cosy.webclient"
  local I18n      = loader.load "cosy.i18n"
  local i18n      = I18n.load {
    "cosy.webclient.headbar",
  }

  local HeadBar    = {}
  HeadBar.__index  = HeadBar
  HeadBar.template = Webclient.template "cosy.webclient.headbar"

  local function setmargin ()
    local height = Webclient.jQuery ".navbar-fixed-top":height ()
    Webclient.jQuery ".main-content":css (Webclient.tojs {
      ["margin-top"] = tostring (height + 1) .. "px",
    })
  end

  function HeadBar.__call ()
    Webclient (function ()
      Webclient.show {
        where    = "headbar",
        template = HeadBar.template,
        data     = {
          title = Webclient.client.server.information {}.name,
        },
        i18n     = i18n,
      }
      setmargin ()
      Webclient.jQuery (Webclient.window):resize (setmargin)
      Webclient.jQuery "#home":click (function ()
        loader.load "cosy.webclient.dashboard" ()
        return false
      end)
      loader.load "cosy.webclient.authentication" ()
    end)
  end

  return setmetatable ({}, HeadBar)

end
