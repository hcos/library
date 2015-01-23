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
  ["check:username:is-string"] =
    "a username must be a string",
  ["check:username:non-empty"] =
    "a username must be non empty",
  ["check:username:alphanumeric"] =
    "a username must contain only alphanumeric characters",
  ["check:password:is-string"] =
    "a password must be a string",
  ["check:password:min-size"] = {
    one   = "a (trimmed) password must contain at least one character",
    other = "a (trimmed) password must be at least %{count} characters long",
  },
  ["check:email:pattern"] =
    "an email address must comply to the standard",
  ["authenticate:non-existing"] =
    "authentication failed, because the given user does not exist",
  ["authenticate:non-user"] =
    "authentication failed, because the given username is not a user",
  ["authenticate:erroneous"] =
    "authentication failed, because of an erroneous username/password couple",
  ["authenticate:cheap-password"] =
    "password for %{username} is hashed using too few rounds and thus rehashed",
}