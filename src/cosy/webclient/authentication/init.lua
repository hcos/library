return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local I18n          = loader.load "cosy.i18n"
  local Scheduler     = loader.load "cosy.scheduler"
  local Webclient     = loader.load "cosy.webclient"

  Configuration.load {
    "cosy.webclient.authentication",
  }

  local i18n = I18n.load {
    "cosy.webclient.authentication",
    "cosy.client",
  }
  i18n._locale = Webclient.window.navigator.language

  local Authentication = {
    template = {},
  }
  Authentication.template.headbar = Webclient.template "cosy.webclient.authentication.headbar"
  Authentication.template.sign_up = Webclient.template "cosy.webclient.authentication.sign-up"
  Authentication.template.log_in  = Webclient.template "cosy.webclient.authentication.log-in"

  function Authentication.sign_up ()
    local co   = Scheduler.running ()
    local info = Webclient.client.server.information ()
    local tos  = Webclient.client.server.tos {
      locale = Webclient.window.navigator.language,
    }
    local component = {
      where    = "main",
      template = Authentication.template.sign_up,
      data     = {
        recaptcha_key = info.captcha,
        tos           = tos.text,
      },
      i18n     = i18n,
    }
    Webclient.show (component)
    local captcha

    local function check ()
      Webclient.window:jQuery "#accept":addClass    "disabled"
      Webclient.window:jQuery "#accept":removeClass "active"
      local result, err = Webclient.client.user.create ({
        identifier = Webclient.document:getElementById "identifier".value,
        password   = Webclient.document:getElementById "password-1".value,
        email      = Webclient.document:getElementById "email".value,
        captcha    = captcha and Webclient.window.grecaptcha:getResponse (captcha),
        tos_digest = Webclient.document:getElementById "tos".checked
                 and tos.digest,
        locale     = Webclient.window.navigator.language,
      }, true)
      for _, x in ipairs { "identifier", "email", "password", "captcha", "tos" } do
        Webclient.window:jQuery ("#" .. x .. "-group"):removeClass "has-error"
        Webclient.window:jQuery ("#" .. x .. "-group"):addClass    "has-success"
        Webclient.window:jQuery ("#" .. x .. "-error"):html ("")
      end
      local passwords = {
        Webclient.document:getElementById "password-1".value,
        Webclient.document:getElementById "password-2".value,
      }
      if passwords [1] ~= passwords [2] then
        Webclient.window:jQuery "#password-group":addClass "has-error"
        local text = i18n ["argument:password:nomatch"] % {}
        Webclient.window:jQuery "#password-error":html (text)
        result = false
      else
        Webclient.window:jQuery "#password-group":addClass "has-success"
        Webclient.window:jQuery "#password-error":html ("")
      end
      for i = 1, 2 do
        if #passwords [i] < Configuration.webclient.authentication.password_size then
          Webclient.window:jQuery "#password-group":addClass "has-error"
          local text = i18n ["sign-up:password-size"] % {
            size = Configuration.webclient.authentication.password_size,
          }
          Webclient.window:jQuery "#password-error":html (text)
          result = false
        end
      end
      if not captcha or Webclient.window.grecaptcha:getResponse (captcha) == "" then
        Webclient.window:jQuery "#captcha-group":addClass "has-error"
        local text = i18n ["sign-up:no-captcha"] % {}
        Webclient.window:jQuery "#captcha-error":html (text)
        result = false
      end
      if result then
        Webclient.window:jQuery "#accept":removeClass "disabled"
        Webclient.window:jQuery "#accept":addClass    "active"
        return true
      elseif err then
        for _, reason in ipairs (err.reasons or {}) do
          if reason.key == "tos_digest" then
            Webclient.window:jQuery "#tos-group":addClass "has-error"
            local text = i18n ["sign-up:no-tos"] % {}
            Webclient.window:jQuery "#tos-error":html (text)
          else
            Webclient.window:jQuery ("#" .. reason.key .. "-group"):addClass "has-error"
            Webclient.window:jQuery ("#" .. reason.key .. "-error"):html (reason.message)
          end
        end
        return false
      end
    end
    for _, x in ipairs { "identifier", "password-1", "password-2", "email", "captcha" } do
      Webclient.document:getElementById (x).onblur = function ()
        Webclient.run (check)
      end
    end
    for _, x in ipairs { "captcha", "tos" } do
      Webclient.document:getElementById (x).onchange = function ()
        Webclient.run (check)
      end
    end

    Webclient.document:getElementById "accept".onclick = function ()
      Scheduler.wakeup (co)
      return false
    end

    do
      Webclient.window.on_captcha_load = function ()
        local params    = loader.js.new (Webclient.window.Object)
        params.sitekey  = info.captcha
        params.callback = function ()
          Webclient.run (check)
        end
        params ["expired-callback"] = function ()
          Webclient.run (check)
        end
        captcha = Webclient.window.grecaptcha:render ("captcha", params)
        return false
      end
      local head   = Webclient.document:getElementsByTagName "head" [0]
      local script = Webclient.document:createElement "script"
      script.type = "text/javascript"
      script.src  = "js/recaptcha.js?onload=on_captcha_load&render=explicit"
      head:appendChild (script)
    end

    while true do
      Scheduler.sleep (-math.huge)
      if check () then
        assert (Webclient.client.user.create {
          identifier = Webclient.document:getElementById "identifier".value,
          password   = Webclient.document:getElementById "password-1".value,
          email      = Webclient.document:getElementById "email".value,
          captcha    = captcha
                   and Webclient.window.grecaptcha:getResponse (captcha),
          tos_digest = Webclient.document:getElementById "tos".checked
                   and tos.digest,
          locale     = Webclient.window.navigator.language,
        })
        loader.load "cosy.webclient.profile" {
          where = "main",
        }
        return
      end
    end
  end

  function Authentication.log_in ()
    local co        = Scheduler.running ()
    local component = {
      where    = "main",
      template = Authentication.template.log_in,
      data     = {},
      i18n     = i18n,
    }
    Webclient.show (component)

    Webclient.document:getElementById "accept".onclick = function ()
      Scheduler.wakeup (co)
      return false
    end

    while true do
      Scheduler.sleep (-math.huge)
      local result, err = Webclient.client.user.authenticate {
        user     = Webclient.document:getElementById "identifier".value,
        password = Webclient.document:getElementById "password"  .value,
        locale   = Webclient.window.navigator.language,
      }
      if result then
        Webclient.hide (component)
        return
      else
        Webclient.window:jQuery "#identifier-group":addClass "has-error"
        Webclient.window:jQuery "#password-group"  :addClass "has-error"
        Webclient.window:jQuery "#identifier-error":html (err.message)
      end
    end
  end

  function Authentication.log_out ()
    Webclient.storage:removeItem "cosy:client"
    Webclient.init ()
  end

  return function (options)
    Webclient.run (function ()
      local co        = Scheduler.running ()
      local component = {
        where    = options.where,
        template = Authentication.template.headbar,
        data     = {
          user = nil,
        },
        i18n     = i18n,
      }
      while true do
        local user = Webclient.client.user.authentified_as {}
        component.data.user = user and user.identifier or nil
        Webclient.show (component)
        Webclient.document:getElementById "sign-up".onclick = function ()
          Webclient.run (function ()
            Authentication.sign_up ()
            Scheduler.wakeup (co)
          end)
          return false
        end
        Webclient.document:getElementById "log-in" .onclick = function ()
          Webclient.run (function ()
            Authentication.log_in ()
            Scheduler.wakeup (co)
          end)
          return false
        end
        Webclient.document:getElementById "log-out".onclick = function ()
          Webclient.run (function ()
            Authentication.log_out ()
            Scheduler.wakeup (co)
          end)
          return false
        end
        Webclient.document:getElementById "profile" .onclick = function ()
          loader.load "cosy.webclient.profile" {
            where = "main",
          }
          return false
        end
        Scheduler.sleep (-math.huge)
      end
    end)
  end

end
