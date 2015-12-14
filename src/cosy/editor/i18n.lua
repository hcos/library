return function (--[[loader]])

  return {
    ["editor:request"] = {
      en = "> editor: {{{request}}}",
      fr = "> editeur: {{{request}}}",
    },
    ["editor:response"] = {
      en = "< editor: {{{request}}} {{{response}}}",
    },
    ["editor:broadcast"] = {
      en = "<< editor: {{{request}}} {{{broadcast}}}",
    },
    ["operation:failure"] = {
      en = "operation {{{operation}}} failed: {{{reason}}}",
    },
  }

end
