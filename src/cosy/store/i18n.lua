return function (--[[loader]])

  return {
    ["redis:retry"] = {
      en = "redis multi/exec failed because of a watch",
    },
  }

end
