return function (--[[loader]])

  return {
    ["check:error"] = {
      en = "some parameters are invalid or missing",
    },
    ["check:no-check"] = {
      en = "in request {{{request}}}, argument {{{key}}} has not been checked",
    },
    ["check:not-found"] = {
      en = "parameter {{{key}}} is missing",
    },
    ["check:resource:format"] = {
      en = "resource part {{{name}}} is not a valid identifier",
    },
    ["check:resource:miss"] = {
      en = "resource {{{name}}} does not exist",
    },
    ["check:resource:not-user"] = {
      en = "resource {{{name}}} is not a user",
    },
    ["check:user:not-active"] = {
      en = "user {{{name}}} is not active",
    },
    ["check:user:not-suspended"] = {
      en = "user {{{name}}} is not suspended",
    },
    ["check:user:suspended"] = {
      en = "user {{{name}}} is suspended",
    },
    ["check:resource:not-type"] = {
      en = "resource {{{name}}} is not a {{{type}}}",
    },
    ["check:ip:pattern"] = {
      en = "IP address is not valid",
    },
    ["check:is-avatar"] = {
      en = "a {{{key}}} must be a table with contents and source",
    },
    ["check:is-boolean"] = {
      en = "a {{{key}}} must be a boolean",
    },
    ["check:is-position"] = {
      en = "{{{key}}} must contain a latitude and a longitude",
    },
    ["check:is-string"] = {
      en = "a {{{key}}} must be a string",
    },
    ["check:is-table"] = {
      en = "{{{key}}} must be a table",
    },
    ["check:min-size"] = {
      en = "a {{{key}}} must contain at least {{{count}}} characters",
    },
    ["check:max-size"] = {
      en = "a {{{key}}} must contain at most {{{count}}} characters",
    },
    ["check:alphanumeric"] = {
      en = "a {{{key}}} must contain only alphanumeric characters",
    },
    ["check:email:pattern"] = {
      en = "email address is not valid",
    },
    ["check:email:exist"] = {
      en = "email {{{email}}} is already bound to an account",
    },
    ["check:locale:pattern"] = {
      en = "locale is not valid",
    },
    ["check:tos_digest:pattern"] = {
      en = "a digest must be a sequence of hexadecimal numbers",
    },
    ["check:tos_digest:incorrect"] = {
      en = "terms of service digest does not correspond to the terms of service",
    },
    ["check:token:invalid"] = {
      en = "token is invalid",
    },
    ["check:user"] = {
      en = "a {{{key}}} must be like username",
    },
    ["check:user:exist"] = {
      en = "user {{{identifier}}} already exists",
    },
    ["check:iterator:bytecode"] = {
      en = "an iterator cannot be bytecode",
    },
    ["check:iterator:function"] = {
      en = "invalid Lua function: {{{reason}}}",
    },
    ["translation:failure"] = {
      en = "translation failed: {{{reason}}}",
    },
    ["avatar"] = {
      en = "avatar file or URL",
    },
    ["captcha"] = {
      en = "captcha",
    },
    ["description"] = {
      en = "description",
    },
    ["email"] = {
      en = "email address",
    },
    ["homepage"] = {
      en = "homepage URL",
    },
    ["ip"] = {
      en = "IP address",
    },
    ["is-private"] = {
      en = "set as private",
    },
    ["iterator"] = {
      en = "iterator function",
    },
    ["locale"] = {
      en = "locale for messages",
    },
    ["name"] = {
      en = "full name",
    },
    ["organization"] = {
      en = "organization",
    },
    ["password"] = {
      en = "password",
    },
    ["password:checked"] = {
      en = "password",
    },
    ["position"] = {
      en = "position",
    },
    ["project"] = {
      en = "project",
    },
    ["resource:identifier"] = {
      en = "identifier",
    },
    ["string"] = {
      en = "string",
    },
    ["string:trimmed"] = {
      en = "string",
    },
    ["token:administration"] = {
      en = "administration token",
    },
    ["token:authentication"] = {
      en = "authentication token",
    },
    ["token:validation"] = {
      en = "validation token",
    },
    ["tos"] = {
      en = "terms of service",
    },
    ["tos:digest"] = {
      en = "terms of service digest",
    },
    ["user"] = {
      en = "user",
    },
    ["user:active"] = {
      en = "active user",
    },
    ["user:suspended"] = {
      en = "suspended user",
    },
    ["user:name"] = {
      en = "username",
    },
  }

end
