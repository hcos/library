return function (--[[loader]])

  return {
    ["tool:description"] = {
      en = "run a tool in standalone mode",
    },
    ["tool:tool:description"] = {
      en = "tool identifier",
    },
    ["tool:parameters:description"] = {
      en = "tool parameters",
    },
    ["tool:model-output"] = {
      en = "Model has been output to {{{filename}}} (a temporary file).",
    },
  }

end
