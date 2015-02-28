return {
  ["license"] =
[[
Cas n°1: Utilisation du logiciel Cosyverif par téléchargement

If you download the Cosyverif software, you acknowledge that this software is distributed under the MIT license and that you accept its terms.
If you decline the terms of this license you must not download this software.

Cas n°2: Utilisation du logiciel Cosyverif directement sur le site

If you use the Cosyverif software, you acknowledge that this software is distributed under the MIT license and you accept its terms.
If you decline the terms of this license you must not use this software.

CAS 3:
- Pour le cas que quelqu'un souhaite contribuer avec des modules, c'est moins facile. 
 est-ce que celui qui propose le module vous donne une licence ?  et si oui, avec quels droits ?

Cas 3a: A l'intention du contributeur qui veut ajouter une contribution au logiciel Cosyverif

If you want that your contribution be integrated into the Cosyverif software be sure to read and accept the following provisions:

By integrating your contribution into the Cosyverif software, you warrant that you are the author of the contribution and that the latter does not infringe the intellectual property rights of a third party.

You assign your patrimonial rights to X for the duration of the patrimonial rights, for all territories throughout the world in order to distribute your contribution as a module of the Cosyverif software.
It is specified that the rights assigned to X are as follows:
- the right to reproduce the contribution in a whole,........
- the right to represent your contribution in a whole,.....
- the right to distribute your contribution under the MIT License
- the right to integrate your contribution into the Cosyverif software

This assignment of rights is granted for free.

Cas 3b: A l'intention des utilisateurs quand la contribution est intégrée au logiciel Cosyverif sans avoir été préalablement accepté par les administrateurs réseaux

Be aware the Cosyverif software contains several modules provided "as is", we do not warrant that the modules do not infringe the intellectual property rigths of a third party.
]],
  ["license:reject"] =
    "license %{digest} is rejected by user %{username}",
  ["license:outdated"] =
    "license %{digest} is not up to date, or in wrong locale",
  ["license:accept"] =
    "license %{digest} is accepted by user %{username}",
  ["license:accept?"] =
    "accepting the license is required",
    
  ["ok"] =
    "success",

  ["platform:available-dependency"] =
    "%{component} is available",
  ["platform:missing-dependency"] =
    "%{component} is not available, because %{reason}",
  ["platform:available-locale"] =
    "i18n locale '%{loaded}' has been loaded",
  ["platform:available-compression"] =
    "compression '%{compression}' has been loaded",
  ["platform:bcrypt-rounds"] = {
    one   = "using one round in bcrypt for at least %{time} milliseconds of computation",
    other = "using %{count} rounds in bcrypt for at least %{time} milliseconds of computation",
  },
  
  ["compression:missing-format"] =
    "format %{format} is not available for decompression",
  
  ["platform:no-token-secret"] =
    "token secret is not defined in configuration",

  ["platform:no-smtp"] =
    "no SMTP server discovered, sending of emails will not work",
  ["platform:smtp"] =
    "SMTP on ${host}:${port} uses ${method} (encrypted with ${protocol})",

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

  ["check:missing"] =
    "parameter %{key} is missing",
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
  ["check:license_digest:pattern"] =
    "a license digest must be a MD5 digest, and thus a sequence of alphanumeric characters",

  ["create-user:email-exists"] =
    "email address %{email} is already bound to an account",
  ["create-user:username-exists"] =
    "username %{username} is already a user account",

  ["authenticate:non-existing"] =
    "authentication failed, because the given user does not exist",
  ["authenticate:non-user"] =
    "authentication failed, because the given username is not a user",
  ["authenticate:non-validated"] =
    "authentication failed, because the account has not been validated",
  ["authenticate:erroneous"] =
    "authentication failed, because of an erroneous username/password couple",
  ["authenticate:cheap-password"] =
    "password for %{username} is hashed using too few rounds and thus rehashed",

  ["method:success"] =
    "success",
  ["method:failure"] =
    "failure",

  ["validate-user:failure"] =
    "validation failed",
  ["validate-user:success"] =
    "validation successfull, authentication token is %{token}",
  
  ["email:new_account:from"] =
    '"%{name}" <%{address}>',
  ["email:new_account:from"] =
    '"%{name}" <%{address}>',
  ["email:new_account:subject"] =
    "[%{servername}] Welcome, %{username}!",
  ["email:new_account:body"] =
    "%{username}, your validation token is <%{validation}>.",
}