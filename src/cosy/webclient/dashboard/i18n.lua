return function (--[[ loader ]])

  return {
    ["dashboard:count-user"] = {
      en = "{{#count~none}}no user{{/count~none}}{{#count~one}}{{count}} user{{/count~one}}{{#count~other}}{{count}} users{{/count~other}}",
    },
    ["dashboard:count-project"] = {
      en = "{{#count~none}}no project{{/count~none}}{{#count~one}}{{count}} project{{/count~one}}{{#count~other}}{{count}} projects{{/count~other}}",
    },
    ["dashboard:count-formalism"] = {
      en = "{{#count~none}}no formalism{{/count~none}}{{#count~one}}{{count}} formalism{{/count~one}}{{#count~other}}{{count}} formalisms{{/count~other}}",
    },
    ["dashboard:count-model"] = {
      en = "{{#count~none}}no model{{/count~none}}{{#count~one}}{{count}} model{{/count~one}}{{#count~other}}{{count}} models{{/count~other}}",
    },
    ["dashboard:count-service"] = {
      en = "{{#count~none}}no service{{/count~none}}{{#count~one}}{{count}} service{{/count~one}}{{#count~other}}{{count}} services{{/count~other}}",
    },
    ["dashboard:count-execution"] = {
      en = "{{#count~none}}no execution{{/count~none}}{{#count~one}}{{count}} execution{{/count~one}}{{#count~other}}{{count}} executions{{/count~other}}",
    },
    ["dashboard:count-scenario"] = {
      en = "{{#count~none}}no scenario{{/count~none}}{{#count~one}}{{count}} scenario{{/count~one}}{{#count~other}}{{count}} scenarios{{/count~other}}",
    },
  }

end
