return function (--[[loader]])

  return {
    ["client:command"] = {
      en = "cosy command-line interface",
    },
    ["server:unreachable"] = {
      en = "cosy server is unreachable",
      fr = "le serveur cosy est injoignable",
    },
    ["error:unexpected"] = {
      en = "an unepected error happened, please retry",
    },
    ["file:not-found"] = {
      en = "file not found: {{{filename}}} ({{{reason}}})",
    },
    ["url:not-found"] = {
      en = "URL not found: {{{url}}} (status {{{status}}})",
    },
    ["success"] = {
      en = "success",
    },
    ["failure"] = {
      en = "failure",
    },
    ["upload:failure"] = {
      en = "failed to upload content (error {{{status}}})",
    },
    ["server:unreachable"] = {
      en = "cosy server is not reachable",
    },
    ["server:already-running"] = {
      en = "server is already running",
    },
    ["option:locale"] = {
      en = "locale for messages",
    },
    ["option:server"]= {
      en = "server url"
    },
    ["flag:captcha"] = {
      en = "answer to captcha in web browser",
    },
    ["flag:debug"] = {
      en = "show debug information",
    },
    ["flag:force"] = {
      en = "force action",
    },
    ["flag:password"] = {
      en = "update password",
    },
    ["argument:password1"] = {
      en = "please type your password",
    },
    ["argument:password2"] = {
      en = "please type the same password again",
    },
    ["argument:password:nomatch"] = {
      en = "passwords are not the same",
    },
  }

end
