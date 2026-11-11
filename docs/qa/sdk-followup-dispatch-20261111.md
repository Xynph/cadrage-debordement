# Recette SDK du suivi de d83a817

La branche de suivi conserve la production et la géométrie reçues dans la PR 566. Elle réunit les corrections de recettes supplémentaires, dont les trois familles 567, 568 et 569. Aucun push n'est effectué sur la branche commune d83a817 déjà verte.

Le workflow SDK enregistré offre un dispatch `scope=followup` : il installe le même SDK officiel épinglé, effectue le même staging/import strict puis exécute, en trois groupes sur trois runners publics isolés, le manifeste explicite `ci/godot-sdk-followup.json`. Le contrôleur existant, ses refus SKIP/ERROR/ANSI et sa borne de 180 secondes par suite/cas sont conservés. Les 16 tests du contrôleur sont des unités VM ; ils ne constituent pas un reçu Godot.

Les événements PR/push normaux et le dispatch `scope=full` conservent le job sdk antérieur, matrices P1 incluses, et exécutent également les trois groupes de nouveaux cas. Les groupes sont une partition validée du manifeste : aucune omission ni duplication de suite. Chaque runner reste séquentiel avec son propre SDK/profil ; le contrôleur des suites n’est pas redéveloppé. Seul le dispatch explicite followup omet P1 : ses sources de production et harnais géométriques n'ont pas changé depuis le reçu vert d83a817. Cela évite une répétition graphique sans affaiblir la politique de couverture des PR vers main.

La possibilité de dispatch hors main sera éprouvée par un unique POST sur la branche figée : s'il est accepté, il lance directement la recette utile. Si GitHub refuse parce que le workflow est absent de la branche par défaut, le repli est une PR brouillon vers main avec ses contrôles habituels, sans changement des paramètres GitHub ni de la politique de sélection. Runner Ubuntu standard public, aucun service payant, aucun cache/artifact upload ni nouvelle Release.

La liste finale ne reçoit que des suites/cas qualifiés et leurs sources exactes. Un résultat rouge ou un cas encore incomplet n'est pas renommé PASS ; les réparations sont poursuivies dans les mêmes familles.
