return {
  available_dependency  = "%{component} is available using '%{dependency}'",
  missing_dependency    = "%{component} is not available",
  available_locale      = "i18n locale '%{locale}' has been loaded",
  available_compression = "compression '%{compression}' has been loaded",
  bcrypt_rounds         = {
    one   = "using one round in bcrypt for at least %{time} milliseconds of computation",
    other = "using %{count} rounds in bcrypt for at least %{time} milliseconds of computation",
  },
  configuration_conflict = "directory %{dir} contains several configuration files, instead of just one",
}