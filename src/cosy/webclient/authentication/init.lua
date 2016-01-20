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
  i18n._locale = loader.window.navigator.language

  local Authentication = {
    template = {},
  }
  Authentication.template.headbar = Webclient.template "cosy.webclient.authentication.headbar"
  Authentication.template.sign_up = Webclient.template "cosy.webclient.authentication.sign-up"
  Authentication.template.log_in  = Webclient.template "cosy.webclient.authentication.log-in"

  function Authentication.sign_up ()
    local co   = Scheduler.running ()
    local info = loader.client.server.information ()
    local tos  = loader.client.server.tos {
      locale = loader.window.navigator.language,
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
      local result, err = loader.client.user.create ({
        identifier = loader.document:getElementById "identifier".value,
        password   = loader.document:getElementById "password-1".value,
        email      = loader.document:getElementById "email".value,
        captcha    = captcha and loader.window.grecaptcha:getResponse (captcha),
        tos_digest = loader.document:getElementById "tos".checked
                 and tos.digest,
        locale     = loader.window.navigator.language,
      }, true)
      for _, x in ipairs { "identifier", "email", "password", "captcha", "tos" } do
        loader.window:jQuery ("#" .. x .. "-group"):removeClass "has-error"
        loader.window:jQuery ("#" .. x .. "-group"):addClass    "has-success"
        loader.window:jQuery ("#" .. x .. "-error"):html ("")
      end
      local passwords = {
        loader.document:getElementById "password-1".value,
        loader.document:getElementById "password-2".value,
      }
      if passwords [1] ~= passwords [2] then
        loader.window:jQuery "#password-group":addClass "has-error"
        local text = i18n ["argument:password:nomatch"] % {}
        loader.window:jQuery "#password-error":html (text)
        result = false
      else
        loader.window:jQuery "#password-group":addClass "has-success"
        loader.window:jQuery "#password-error":html ("")
      end
      for i = 1, 2 do
        if #passwords [i] < Configuration.webclient.authentication.password_size then
          loader.window:jQuery "#password-group":addClass "has-error"
          local text = i18n ["sign-up:password-size"] % {
            size = Configuration.webclient.authentication.password_size,
          }
          loader.window:jQuery "#password-error":html (text)
          result = false
        end
      end
      if not captcha or loader.window.grecaptcha:getResponse (captcha) == "" then
        loader.window:jQuery "#captcha-group":addClass "has-error"
        local text = i18n ["sign-up:no-captcha"] % {}
        loader.window:jQuery "#captcha-error":html (text)
        result = false
      end
      if result then
        loader.window:jQuery "#accept":removeClass "disabled"
        loader.window:jQuery "#accept":addClass    "active"
        return true
      elseif err then
        for _, reason in ipairs (err.reasons or {}) do
          if reason.key == "tos_digest" then
            loader.window:jQuery "#tos-group":addClass "has-error"
            local text = i18n ["sign-up:no-tos"] % {}
            loader.window:jQuery "#tos-error":html (text)
          else
            loader.window:jQuery ("#" .. reason.key .. "-group"):addClass "has-error"
            loader.window:jQuery ("#" .. reason.key .. "-error"):html (reason.message)
          end
        end
        loader.window:jQuery "#accept":removeClass "active"
        loader.window:jQuery "#accept":addClass    "disabled"
        return false
      end
    end
    for _, x in ipairs { "identifier", "password-1", "password-2", "email", "captcha" } do
      loader.document:getElementById (x).onblur = function ()
        Webclient.run (check)
      end
    end
    for _, x in ipairs { "captcha", "tos" } do
      loader.document:getElementById (x).onchange = function ()
        Webclient.run (check)
      end
    end

    local button
    loader.document:getElementById "cancel".onclick = function ()
      button = "cancel"
      Scheduler.wakeup (co)
      return false
    end
    loader.document:getElementById "accept".onclick = function ()
      button = "accept"
      Scheduler.wakeup (co)
      return false
    end

    do
      loader.window.on_captcha_load = function ()
        local params    = loader.js.new (loader.window.Object)
        params.sitekey  = info.captcha
        params.callback = function ()
          Webclient.run (check)
        end
        params ["expired-callback"] = function ()
          Webclient.run (check)
        end
        captcha = loader.window.grecaptcha:render ("captcha", params)
        return false
      end
      local head   = loader.document:getElementsByTagName "head" [0]
      local script = loader.document:createElement "script"
      script.type = "text/javascript"
      script.src  = "js/recaptcha.js?onload=on_captcha_load&render=explicit"
      head:appendChild (script)
    end

    while true do
      Scheduler.sleep (-math.huge)
      if button == "cancel" then
        Webclient.hide (component)
        return
      end
      assert (button == "accept")
      if check () then
        assert (loader.client.user.create {
          identifier = loader.document:getElementById "identifier".value,
          password   = loader.document:getElementById "password-1".value,
          email      = loader.document:getElementById "email".value,
          captcha    = captcha
                   and loader.window.grecaptcha:getResponse (captcha),
          tos_digest = loader.document:getElementById "tos".checked
                   and tos.digest,
          locale     = loader.window.navigator.language,
        })
        Webclient.hide (component)
        return
      end
    end
  end

  --[==[

  function Authentication.log_in ()
    local running = loader.scheduler.running ()
    loader.document:getElementById "content-wrapper".innerHTML = loader.request "/html/login.html"
    loader.document:getElementById "signin".onclick = function ()
      loader.window:jQuery "#userdiv"  :removeClass "has-error"
      loader.window:jQuery "#error"    :hide ()
      loader.window:jQuery "#usererror":hide ()
      loader.scheduler.wakeup (running)
      return false
    end
    loader.document:getElementById "register".onclick = function ()
      loader.scheduler.addthread (Auth.register)
      return false
    end
    while true do
      local identifier = loader.document:getElementById "identifier".value
      local password = loader.document:getElementById "password".value
      local result, err = loader.client.user.authenticate {
        user     = identifier,
        password = password,
      }
      if result then
        loader.window:jQuery "#success #message":html "User authentified"
        loader.window:jQuery "#success":show ()
        loader.storage:setItem ("cosy:client", Value.encode (loader.data))
        loader.window.location.href = "/"
      else
        loader.window:jQuery "#error #message":html (err.message)
        loader.window:jQuery "#error":show ()
        if err.reasons then
          for i = 1, #err.reasons do
            local reason = err.reasons [i]
            if reason.parameter == "identifier" then
              loader.window:jQuery "#usererror":html (reason.message)
              loader.window:jQuery "#usererror":show()
              loader.window:jQuery "#userdiv"  :addClass "has-error"
            end
          end
        end
      end
      loader.scheduler.sleep ()
    end
  end

  function Authentication.log_out ()
    local running = loader.scheduler.running ()
    loader.document:getElementById "content-wrapper".innerHTML = loader.request "/html/login.html"
    loader.document:getElementById "signin".onclick = function ()
      loader.window:jQuery "#userdiv"  :removeClass "has-error"
      loader.window:jQuery "#error"    :hide ()
      loader.window:jQuery "#usererror":hide ()
      loader.scheduler.wakeup (running)
      return false
    end
    loader.document:getElementById "register".onclick = function ()
      loader.scheduler.addthread (Auth.register)
      return false
    end
    while true do
      local identifier = loader.document:getElementById "identifier".value
      local password = loader.document:getElementById "password".value
      local result, err = loader.client.user.authenticate {
        user     = identifier,
        password = password,
      }
      if result then
        loader.window:jQuery "#success #message":html "User authentified"
        loader.window:jQuery "#success":show ()
        loader.storage:setItem ("cosy:client", Value.encode (loader.data))
        loader.window.location.href = "/"
      else
        loader.window:jQuery "#error #message":html (err.message)
        loader.window:jQuery "#error":show ()
        if err.reasons then
          for i = 1, #err.reasons do
            local reason = err.reasons [i]
            if reason.parameter == "identifier" then
              loader.window:jQuery "#usererror":html (reason.message)
              loader.window:jQuery "#usererror":show()
              loader.window:jQuery "#userdiv"  :addClass "has-error"
            end
          end
        end
      end
      loader.scheduler.sleep ()
    end
  end

  --]==]

  return function (options)
    Webclient.run (function ()
      local co = Scheduler.running ()
      local component = {
        where    = options.where,
        template = Authentication.template.headbar,
        data     = {
          user = nil,
        },
        i18n     = i18n,
      }
      while true do
        local user = loader.client.user.authentified_as {}
        component.data.user = user and user.identifier or nil
        Webclient.update (component)
        loader.document:getElementById "sign-up".onclick = function ()
          Webclient.run (function ()
            Authentication.sign_up ()
            Scheduler.wakeup (co)
          end)
          return false
        end
        loader.document:getElementById "log-in" .onclick = function ()
          Webclient.run (function ()
            Authentication.log_in ()
            Scheduler.wakeup (co)
          end)
          return false
        end
        loader.document:getElementById "log-out".onclick = function ()
          Webclient.run (function ()
            Authentication.log_out ()
            Scheduler.wakeup (co)
          end)
          return false
        end
        Scheduler.sleep (-math.huge)
      end
    end)
  end

end
