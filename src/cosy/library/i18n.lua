return function (--[[loader]])

  return {
    ["server:unreachable"] = {
      en = "cosy server is unreachable",
      fr = "le serveur cosy est injoignable",
    },
    ["server:timeout"] = {
      en = "timeout while waiting response from server",
    },
    ["password:too-weak"] = {
      en = "password is too weak, need at least {{{size}}} characters",
    },
  }

end
