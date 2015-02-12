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
      c = { [a, b] }, -- héritage
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

  Dans /c3/, on peut tout à fait modifier `petri_net` ou `philosophers`
  sans que ces changements ne soient répercutés dans /c1/ ou /c2/.

* on ne peut modifier les données que dans le calque de plus haut niveau,
  ce qui évite de modifier ce dont le modèle dépend;

* tous les calques sont au contraire utilisés pour la lecture des données;
  le calque de plus haut niveau est alors prioritaire par rapport à ceux
  situés en dessous de lui;

Héritage
--------

* les données supportent l'héritage multiple

  Exemple:
  
    /c1/ = {
      a = { x = 1 },
      b = { y = 2 },
      c = [a, b],
    }

* les parents spécifiés dans l'héritage sont des données du calque courant,
  ou bien des données résolues à partir du calque courant; il n'est pas
  possible de spécifier explicitement une donnée d'un calque précis comme
  parent;

* l'héritage n'est pas forcément spécifié lors de la première appartition
  d'une donnée, mais peut l'être dans un calque supérieur;
  
  Exemple:
  
    /c1/ = {            /c2/ = {
      a = { x = 1 },      b = [a],
      b = { y = 2 },    }
    }

* lorsqu'il est spécifié à différents endroits, l'héritage se cumule,
  de la même manière que les parents d'un parent sont aussi des parents;

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

* la résolution d'une donnée se fait tout d'abord dans le calque courant;
  si elle n'est pas trouvée, on cherche dans l'héritage spécifié dans le calque
  courant; avant de chercher dans les calques inférieurs;

  Exemple:

    /c1/ = {          /c2/ = {        aplani en /c1 < c2/ = {
      a = {             b = [a],        a = {
        b = true,     }                   b = true,
      },                                },
      b = {                             b = {
        b = 2,                            b = true,
      },                                },
    }                                 }


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

* ...

Attention
---------

Normalement, on ne devrait pas pouvoir modifier des valeurs, une fois
celles-ci définies. Existe-t-il un moyen simple pour interdire ce genre de
choses ? Quel impact sur les règles définies ci-dessus ? Est-ce une si bonne
idée de l'interdire ?







Attention, il y a des cas étranges :
calque_1 = {
  a = {
    a = 1,
    b = 2,
  },
  b = {
    _ = @a,
    b = true,
    c = 3,
  },
}
Ici, nous ajoutons des clés à `b` alors que celui-ci est un lien vers `a`.
Il n'est pas possible d'ajouter ces clés directement à `a`, car nous devons
conserver la structure sous-jacente, et ne jouer que sur l'interprétation.

interprétation à plat :
{
  a = {
    a = 1,
  },
  b = {
    a = 1,
    b = ???,
    c = 3,
  },
}
En fait j'ai l'impression que tout dépend de l'interprétation qu'on souhaite :
suivre le lien ou alors observer les attributs du lien.

Exemple #4
----------
Cet exemple mélange calques, héritage et liens.

calque_1 = {
  a = {
    a = 1,
    b = 2,
  },
  b = {
    _ = @a,
    b = true,
    c = 3,
  },
}
calque_2 = {
  b = {
    <inherits a>
    b = "abc",
  },
}
Que signifie d'hériter de quelque chose quand on est un lien ?
Même remarque qu'au-dessus, j'ai l'impression que tout dépend de ce qu'on
obseve : le lien ou l'objet référencé.

interprétation à plat ?
{
  a = {
    a = 1,
  },
  b = {
    a = 1,
    b = ???,
    c = 3,
  },
}

Cas tordu
---------

calque_1 = {
  a = {
    b = {
      <inherits d>
    },
    c = 1,
  },
  b = {
    b = {
      <inherits c>
    },
    c = 2,
  },
  c = {
    c = 3,
  },
  d = {
    c = 4,
  }
}
calque_2 = {
  b = {
    <inherits a>
    b = {
      <inherits a>
    },
  },
}

Conclusion
==========
Cette structure de données est un outil très amusant pour CosyVerif, mais avec
quelques merdes. Il faut essayer de définir les algorithmes de résolution
pour qu'ils soient le plus intuitifs possible.

1. Chercher par calque sans tenir compte de l'héritage
   Selon le cas, suivre ou non le lien
2. Reprendre la recherche en utilisant l'héritage
   