   local event = coroutine.yield ()
    if event == "register" then
      local user  = js.global.document:getElementById("username").value
      local pass  = js.global.document:getElementById("pass").value
      local email  = js.global.document:getElementById("email").value
      local captcha  = js.global.document:getElementById("g-recaptcha-response").value
      local tostext  = client.server.tos ()
      local ip = loader.loadhttp "/ip"
      local result, err = client.user.create {
      username   = user,
      password   = pass,
      email      = email ,
      captcha    = captcha,
      ip         = ip,
      tos_digest = tostext.tos_digest:upper (),
      locale     = "en",
      }
     window:jQuery('.overlay'):hide()
     if result then
        window:jQuery('#success #message'):html("User Created")
        window:jQuery('#success'):show()
        window:jQuery('#register'):hide()
