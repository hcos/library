return function (--[[loader]])

  return {
    ["bcrypt:rounds"] = {
      en = "using {{{rounds}}} rounds in bcrypt for at least {{{time}}} milliseconds of computation",
    },
  }

end
