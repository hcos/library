Données dans CosyVerif
======================

Structure
---------

* une donnée est composée :
    * d'une valeur (nil, booléen, chaîne de caractères, nombre);
    * d'un mapping de clés vers des données;
    * d'une liste de parents (par héritage);
    * d'une redirection (la donnée est un lien vers une autre);
  
  Exemple:

    { a = 1, -- valeur
      b = { c = 2 }, -- mapping
      c = [a, b], -- héritage
      d = @a, -- redirection
    }
  
* en ne tenant pas compte des parents, ni des redirections,
  la structure doit former un arbre, et non un graphe;

Calques
-------

* les données appartiennent à des calques; ceux-ci fonctionnent réellement
  comme du papier calque, en permettant de modifier les données en profondeur;
  on peut alors définir un équivalent "aplati" des calques;
  
  Exemple:

    /c1/ = {      /c2/ = {      aplani en /c1 < c2/ = {
      a = 1,        a = 2,        a = 2,
      b = {         b = {         b = {
        a = 1,        b = 2,        a = 1,
      },            }               b = 2,
    }               c = 3,        },
                  }               c = 3,
                                }

* chaque calque correspond en gros à une "session d'édition", il peut contenir
  des données du modèle édité, ainsi que des données à ajouter aux modèles
  et formalismes dont il dépend, sans réellement modifier ceux-ci;
  
  Exemple:

    /c1/ = {            /c2/ = {                /c3/ = {
      petri_net = ...     petri_net    = ...      petri_net    = ...
    }                     philosophers = ...      philosophers = ...
                        }                         state_space  = ...
                                                }

  Dans `/c3/`, on peut tout à fait modifier `petri_net` ou `philosophers`
  sans que ces changements ne soient répercutés dans `/c1/` ou `/c2/`.

* on ne peut modifier les données que dans le calque de plus haut niveau,
  ce qui évite de modifier ce dont le modèle dépend;

* tous les calques sont au contraire utilisés pour la lecture des données;
  le calque de plus haut niveau est alors prioritaire par rapport à ceux
  situés en dessous de lui;

Héritage
--------

* les données supportent l'héritage multiple; les parents sont classés
  du plus prioritaire au moins prioritaire dans la liste;

  Exemple:
  
    /c1/ = {              /c1/.c.x = 1
      a = { x = 1 },
      b = { x = 2 },
      c = [a, b],
    }

* les parents spécifiés dans l'héritage sont des données du calque courant,
  ou bien des données résolues à partir du calque courant; il n'est pas
  possible de spécifier explicitement une donnée d'un calque précis comme
  parent;

* l'héritage n'est pas forcément spécifié lors de la première apparition
  d'une donnée, mais peut l'être dans un calque supérieur;
  
  Exemple:
  
    /c1/ = {            /c2/ = {
      a = { x = 1 },      b = [a],
      b = { y = 2 },    }
    }

* lorsqu'il est spécifié à différents endroits, l'héritage se cumule,
  de la même manière que les parents d'un parent sont aussi des parents
  dans le modèle objet classique; les parents des parents sont alors moins
  prioritaires;

  Exemple:
  
    /c1/ = {            /c2/ = {        aplani en /c1 < c2/ = {
      a = { x = 1 },      b = [a],        a = { x = 1 },
      b = [c],          }                 c = { z = 3 },
      c = { z = 3 },                      b = {
    }                                       x = 1,
                                            z = 3,
                                          }
                                        }

* l'héritage peut éventuellement former des cycles, ceux-ci sont cassés
  lorsque l'héritage est linéarisé; je ne vois aucune raison d'interdire
  ce genre de construction, même si elle est très étrange;

  Exemple:
  
    /c1/ = {
      a = { [b], x = 1 },
      b = { [a], y = 2 },
    }

* la résolution de l'héritage d'une donnée se fait tout d'abord dans le calque
  courant; si elle n'est pas trouvée, on cherche dans les calques inférieurs;

  Exemple:

    /c1/ = {          /c2/ = {        aplani en /c1 < c2/ = {
      a = {             b = {},         a = {
        b = true,     }                   b = true,
      },                                },
      b = [a]                           b = {
    }                                      b = true,
                                        },
                                      }


* la résolution de l'héritage se fait tout d'abord au niveau le plus profond,
  avant de remonter vers la racine;

  Exemple:
  
    /c1/ = {        aplani en /c1/ = {
      a = {           a = {
        b = 1,          b = 1,
      },              },
      b = {           b = {
        [a],            b = {
        b = [a],          b = 1,
      },                },
    }                 },
                    }

* l'héritage est toujours moins prioritaire que des données spécifiées
  explicitement; on considère, quel que soit le calque où l'héritage
  est spécifié, que les données parentes sont plus lointaines qu'une donnée
  explicite, même située sur un calque inférieur;

  Exemple:

    /c1/ = {        /c2/ = {      aplani en /c1 < c2/ = {
      a = {           b = {         a = {
        x = 1,          [a],          x = 1,
      },              },            },
      b = {         }               b = {
        x = 2,                        x = 2,
      },                            },
    }                             }

Redirection
-----------

* une donnée ne peut rediriger que vers une seule autre donnée;
  une redirection est donc considérée comme une valeur qu'on peut remplacer,
  et non comme l'héritage qui s'ajoute aux parents existants;

  Exemple:
  
    /c1/ = {      /c2/ = {      aplani en /c1 < c2/ = {
      a = 1,        c = 3,        a = 1,
      b = @a,       b = @c,       c = 3,
    }             }               b = 3,
                                }

* on distingue deux types de parcours des données : un parcours où l'on suit
  les redirection, et un parcours où on les considère comme des données;
  
  Exemple:
  
    /c1/ = {                /c1/.b.c = 1, si l'on suit la redirection
      a = { c = 1 },        /c1/.b.c = 2, si on la considère comme une donnée
      b = { @a, c = 2 },
    }

* une redirection peut contenir un sous-arbre; celui-ci est alors considéré
  comme étiquetant la redirection, et non sa cible;
  
* il est possible pour une redirection d'utiliser aussi de l'héritage;
  dans ce cas, on considère que l'héritage porte sur les données étiquetant
  la redirection, et non sur sa cible;
  
  Exemple:
  
    /c1/ = {              /c1/.c.x = 1, si l'on suit la redirection
      a = { x = 1 },      /c1/.c.x = 2, si on la considère comme une donnée
      b = { x = 2 },
      c = { @a, [b] },
    }

Attention
---------

Normalement, on ne devrait pas pouvoir modifier des valeurs, une fois
celles-ci définies. Existe-t-il un moyen simple pour interdire ce genre de
choses ? Quel impact sur les règles définies ci-dessus ? Est-ce une si bonne
idée de l'interdire ?

Conclusion
==========
Cette structure de données est un outil très amusant pour CosyVerif, mais avec
quelques merdes. Il faut essayer de définir les algorithmes de résolution
pour qu'ils soient le plus intuitifs possible, et qu'ils soient suffisamment
efficaces.
