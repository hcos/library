return {
  ["server:information"] = {
    en = "show information about the server",
  },
  ["server:list-methods"] = {
    en = "list all methods available on the server",
  },
  ["server:tos"] = {
    en = "show the terms of service of the server",
  },
  ["server:stop"] = {
    en = "stop the server",
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
  ["user:is-authentified"] = {
    en = "checks if a user is authentified",
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
  ["terms-of-service"] = {
    en = [[I agree to give my soul to CosyVerif.]],
  },
  ["username:miss"] = {
    en = "username {{{username}}} does not exist",
  },
  ["username:exist"] = {
    en = "username {{{username}}} exists already",
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
    en = [=[[{{{servername}}}] Welcome, {{{username}}}!]=],
  },
  ["user:create:body"] = {
    en = "{{{username}}}, we are happy to see you! Please validate your email address using token {{{token}}}.",
  },
  ["user:update:from"] = {
    en = [["{{{name}}}" <{{{email}}}>]],
  },
  ["user:update:to"] = {
    en = [["{{{name}}}" <{{{email}}}>]],
  },
  ["user:update:subject"] = {
    en = [=[[{{{servername}}}] Update, {{{username}}}!]=],
  },
  ["user:update:body"] = {
    en = "{{{username}}}, please validate your email address using token {{{token}}}.",
  },
  ["user:reset:from"] = {
    en = [["{{{name}}}" <{{{email}}}>]],
  },
  ["user:reset:to"] = {
    en = [["{{{name}}}" <{{{email}}}>]],
  },
  ["user:reset:subject"] = {
    en = [=[[{{{servername}}}] Welcome back, {{{username}}}!]=],
  },
  ["user:reset:body"] = {
    en = "{{{username}}}, your validation token is <{{{validation}}}>.",
  },
  ["user:reset:retry"] = {
    en = "reset failed, please try again later",
  },
  ["user:suspend:not-user"] = {
    en = "account {{{username}}} is not a user",
  },
  ["user:suspend:self"] = {
    en = "are you mad?",
  },
  ["user:release:not-user"] = {
    en = "account {{{username}}} is not a user",
  },
  ["user:suspend:not-suspended"] = {
    en = "account {{{username}}} is not suspended",
  },
  ["user:release:self"] = {
    en = "nice try ;-)"
  },
  ["user:suspend:not-enough"] = {
    en = "suspending a user requires {{{required}}} reputation, but only {{{owned}}} is owned",
  },
}
