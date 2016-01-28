return function (loader)

  local Configuration = loader.load "cosy.configuration"
  local Layer         = loader.require "layeredata"

  Configuration.load "cosy.methods"

  local result = {
    ["captcha:failure"] = {
      en = "captcha verification failed",
    },
    ["method:administration-only"] = {
      en = "method is reserved to server administrator",
    },
    ["server:information"] = {
      en = "show information about the server",
    },
    ["server:list-methods"] = {
      en = "list all methods available on the server",
    },
    ["server:tos"] = {
      en = "show the terms of service of the server",
    },
    ["server:filter"] = {
      en = "run an iterator on the server",
    },
    ["server:filter:not-enough"] = {
      en = "filtering requires {{{required}}} reputation, but only {{{owned}}} is owned",
    },
    ["server:filter:error"] = {
      en = "filtering has failed, because {{{reason}}}",
    },
    ["server:cancel"] = {
      en = "cancel an iterator on the server",
    },
    ["user:create"] = {
      en = "create a user account on the server",
    },
    ["user:authenticate"] = {
      en = "authenticate a user",
    },
    ["user:delete"] = {
      en = "delete your account",
    },
    ["user:information"] = {
      en = "show user information",
    },
    ["user:authentified-as"] = {
      en = "shows identified user",
    },
    ["user:list"] = {
      en = "list all users",
    },
    ["user:recover"] = {
      en = "recover your account",
    },
    ["user:reset"] = {
      en = "reset your account",
    },
    ["user:release"] = {
      en = "release a suspended user account",
    },
    ["user:suspend"] = {
      en = "suspend a user account",
    },
    ["user:send-validation"] = {
      en = "send (again) email validation",
    },
    ["user:update"] = {
      en = "update user information",
    },
    ["user:validate"] = {
      en = "validate email address",
    },
    ["project:list"] = {
      en = "list projects",
    },
    ["project:create"] = {
      en = "create a project",
    },
    ["project:delete"] = {
      en = "delete a project",
    },
    ["project:update"] = {
      en = "update project information",
    },
    ["terms-of-service"] = {
      en = [[I agree to give my soul to CosyVerif.]],
    },
    ["identifier:miss"] = {
      en = "identifier {{{identifier}}} does not exist",
    },
    ["identifier:exist"] = {
      en = "identifier {{{identifier}}} exists already",
    },
    ["email:exist"] = {
      en = "email {{{email}}} is already bound to an account",
    },
    ["user:authenticate:failure"] = {
      en = "authentication failed",
    },
    ["user:create:from"] = {
      en = [["{{{name}}}" <{{{email}}}>]],
    },
    ["user:create:to"] = {
      en = [["{{{name}}}" <{{{email}}}>]],
    },
    ["user:create:subject"] = {
      en = [=[[{{{servername}}}] Welcome, {{{identifier}}}!]=],
    },
    ["user:create:body"] = {
      en = "{{{identifier}}}, we are happy to see you! Please click here to validate your email address <a href='http://{{{host}}}/?token={{{token}}}.",
    },
    ["user:update:from"] = {
      en = [["{{{name}}}" <{{{email}}}>]],
    },
    ["user:update:to"] = {
      en = [["{{{name}}}" <{{{email}}}>]],
    },
    ["user:update:subject"] = {
      en = [=[[{{{servername}}}] Update, {{{identifier}}}!]=],
    },
    ["user:update:body"] = {
      en = "{{{identifier}}}, please validate your email address using token {{{token}}}.",
    },
    ["user:reset:from"] = {
      en = [["{{{name}}}" <{{{email}}}>]],
    },
    ["user:reset:to"] = {
      en = [["{{{name}}}" <{{{email}}}>]],
    },
    ["user:reset:subject"] = {
      en = [=[[{{{servername}}}] Welcome back, {{{identifier}}}!]=],
    },
    ["user:reset:body"] = {
      en = "{{{identifier}}}, your validation token is <{{{validation}}}>.",
    },
    ["user:reset:retry"] = {
      en = "reset failed, please try again later",
    },
    ["user:suspend:not-user"] = {
      en = "account {{{identifier}}} is not a user",
    },
    ["user:suspend:self"] = {
      en = "are you mad?",
    },
    ["user:release:not-user"] = {
      en = "account {{{identifier}}} is not a user",
    },
    ["user:suspend:not-suspended"] = {
      en = "account {{{identifier}}} is not suspended",
    },
    ["user:release:self"] = {
      en = "nice try ;-)"
    },
    ["user:suspend:not-enough"] = {
      en = "suspending a user requires {{{required}}} reputation, but only {{{owned}}} is owned",
    },
    ["resource:exist"] = {
      en = "resource {{{name}}} exists already",
    },
    ["resource:miss"] = {
      en = "resource {{{name}}} does not exist",
    },
    ["resource:forbidden"] = {
      en = "restricted to resource owner",
    },
  }

  for id in Layer.pairs (Configuration.resource.project ["/"]) do
    local a = "a"
    if id:match "^[aeiou]" then
      a = "an"
    end
    a = a .. " "
    result [id .. ":create"] = {
      en = "create " .. a .. id,
    }
    result [id .. ":copy"] = {
      en = "copy " .. a .. id,
    }
    result [id .. ":delete"] = {
      en = "delete " .. a .. id,
    }
  end

  return result

end
