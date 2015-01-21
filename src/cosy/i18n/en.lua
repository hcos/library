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
}