return {
  ["platform:available-dependency"] =
    "%{component} is available using '%{dependency}'",
  ["platform:missing-dependency"] =
    "%{component} is not available",
  ["platform:available-locale"] =
    "i18n locale '%{locale}' has been loaded",
  ["platform:available-compression"] =
    "compression '%{compression}' has been loaded",
  ["platform:bcrypt-rounds"] = {
    one   = "using one round in bcrypt for at least %{time} milliseconds of computation",
    other = "using %{count} rounds in bcrypt for at least %{time} milliseconds of computation",
  },
  ["configuration:conflict"] =
    "directory %{path} contains several configuration files, instead of just one",
  ["configuration:using"] =
    "using configuration in directory %{path}",
  ["turing:what-is-round"] =
    "What is represented as a circle in Petri nets: a *place* or a *transition*?",
  ["turing:what-is-rectangular"] =
    "What is represented as a rectangle in Petri nets: a *place* or a *transition*?",
  ["place"] =
    "place",
  ["transition"] =
    "transition",
  ["check:error"] =
    "some parameters are invalid or missing",

  ["check:is-string"] =
    "a %{key} must be a string",
  ["check:min-size"] = {
    one   = "a %{key} must contain at least one character",
    other = "a %{key} must be at least %{count} characters long",
  },
  ["check:max-size"] = {
    one   = "a %{key} must contain at most one character",
    other = "a %{key} must be at most %{count} characters long",
  },
  
  ["check:username:alphanumeric"] =
    "a username must contain only alphanumeric characters",
  ["check:email:pattern"] =
    "an email address must comply to the standard",
  ["check:locale:pattern"] =
    "a locale must comply to the standard",

  ["authenticate:non-existing"] =
    "authentication failed, because the given user does not exist",
  ["authenticate:non-user"] =
    "authentication failed, because the given username is not a user",
  ["authenticate:erroneous"] =
    "authentication failed, because of an erroneous username/password couple",
  ["authenticate:cheap-password"] =
    "password for %{username} is hashed using too few rounds and thus rehashed",
}