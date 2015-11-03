return function (--[[loader]])

  return {
    ["nginx:no-resolver"] = {
      en = "no resolver found for host names",
    },
    ["nginx:hostname"] = {
      en = "hostname has been set to {{{hostname}}}",
    },
  }

end
