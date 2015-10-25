return function (--[[loader]])

  return {
    ["use"] = {
      en = "using file {{{path}}} in configuration",
      fr = "la configuration utilise le fichier {{{path}}}",
    },
    ["skip"] = {
      en = "skipping file {{{path}}} in configuration",
      fr = "la configuration n'utilise pas le fichier {{{path}}}",
    },
  }

end
