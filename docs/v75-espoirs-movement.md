# V75 — mouvements interdivisions Reichel

Les deux finalistes Accession V74 passent en Élite V73 à la saison suivante. Les deux relégués sont les deux moins bien classés parmi les derniers de chaque poule initiale Élite. Ce choix est une **règle de simulation du jeu**, pas une homologation du règlement FFR.

44 identités uniques persistantes, 24 emplacements Élite et 20 Accession. Les joueurs suivent leurs clubs, et les rencontres sont régénérées dans leur nouvelle division. Aucun transfert ne touche la compétition senior.

Le nouvel état facultatif v75Movement garde les identités, effectifs et un historique de quatre saisons. Les anciennes sauvegardes sans cet état restent compatibles. Les notes, identifiants et potentiels sont préservés; condition et âge sont adaptés à l'intersaison.

Chemins : dist/espoirs-movement-v75.js, adaptations bornées de dist/espoirs-league-v73.js et dist/espoirs-accession-v74.js, inclusion dans dist/index.html, tests/v75-espoirs-movement.cjs.

Tester : node tests/v75-espoirs-movement.cjs ; node tests/v73-espoirs-league.cjs ; node tests/v74-espoirs-accession.cjs ; CI complète sur HEAD exact, tests d'import/export, quatre saisons et 44 identités. Aucun merge en rôle PRODUCTEUR.