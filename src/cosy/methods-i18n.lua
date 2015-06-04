return {
  ["terms-of-service"] = {
    en = [[
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
    en = "{{{username}}}, we are happy to see you!",
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
    en = "{{{username}}}, you have changed your email address!",
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
  ["user:suspend:not-enough"] = {
    en = "suspending a user requires {{{required}}} reputation, but only {{{owned}}} is owned",
  },
  ["redis:unreachable"] = {
    en = "redis server in unreachable",
  },
}
