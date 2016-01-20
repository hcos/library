return function (loader)

  local I18n          = loader.load "cosy.i18n"
  local Scheduler     = loader.load "cosy.scheduler"
  local Webclient     = loader.load "cosy.webclient"

  local i18n = I18n.load {
    "cosy.webclient.dashboard",
  }
  i18n._locale = Webclient.window.navigator.language

  local Dashboard = {
    template = {},
  }
  Dashboard.template.anonymous = Webclient.template "cosy.webclient.dashboard.anonymous"
  Dashboard.template.user      = Webclient.template "cosy.webclient.dashboard.user"

  return function (options)
    Webclient.run (function ()
      local component = {
        where    = options.where,
        template = Dashboard.template.anonymous,
        data     = {},
        i18n     = i18n,
      }
      while true do
        local _ = Webclient.client.user.authentified_as {}
        Webclient.show (component)
        Scheduler.sleep (-math.huge)
      end
    end)
  end

end
