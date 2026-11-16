# Rappels de suivi au Bureau

Accord de Léo : « Ok go », après la proposition de remonter les décisions
individuelles à réexaminer. Branche indépendante de #588, créée depuis main
`664867a110deebcd028b090b5a259838e6c3911a` ; réservation dans #591.

## Résultat attendu

Une carte du Bureau propose de réexaminer le suivi d'un jeune dont l'objectif
daté arrive à échéance. Elle reprend les mesures publiées et ouvre directement
son dossier. Aucun effet de progression, aucun nouveau champ de sauvegarde.
Les urgences match/presse/composition, finances et santé restent prioritaires.
Un rappel ne prouve pas l'effet causal du plan et ne promet aucun gain.

Réutiliser `shortTermObjective` est préférable à un nouvel agenda persistant :
les dates et les observations existent déjà. Un écran de suivi supplémentaire
ferait doublon. Au plus un rappel dans les trois priorités existantes ; ordre
stable par échéance puis identifiant. Une mesure indisponible ou une rupture de
contexte ne justifie pas un bilan chiffré. L'ouverture du dossier est consultative.

## Tâche unique : projection et navigation

1. Ajouter une recette dédiée `tests/office-youth-review-reminders.{cjs,gd}`,
   sans toucher aux tests/helpers Godot réservés à Claude. Vérifier l'absence
   actuelle du rappel (RED), les échéances, les urgences, le contexte et la pureté.
2. Modifier `office_priorities.gd` : prendre seulement un suivi actif, daté,
   échu et observable ; aucune relance en direct ou à la clôture sportive.
3. Ajouter l'action dans `office.gd` et l'ouverture ciblée dans
   `youth_development_view.gd`. Retrouver le joueur malgré les filtres précédents,
   conserver l'accès à la liste et ne transmettre aucune commande moteur.
4. Exécuter la recette et les régressions Bureau/suivi pertinentes (GREEN),
   vérifier le diff et publier une PR brouillon avec preuves et limites.
   CI complète avant PRÊT ; respecter le créneau Claude avant toute intégration.
5. Consigner dans AGENTS la règle permanente modèle/effort/quota communiquée
   par Léo et enregistrer le lien de référence comme fourni, sans prétendre
   avoir consulté l'article.

## Vérification et revue

SDK Godot réel déjà disponible dans le Cloud, profils jetables uniquement.
Tester le clic du Bureau jusqu'à la carte du bon joueur, y compris homonymes,
les filtres résiduels et l'absence de commande/écriture de profil. Pas de recette
Windows revendiquée. Auto-revue séparée du diff ; aucun sous-agent autorisé.

## Exécution

Modèle principal de la session ; identifiant et effort effectif non exposés.
Recommandation GPT-6.1 Sol : moyen. Aucune session supplémentaire.

## Journal d'exécution

- Projection RED puis GREEN ; recette dédiée 38/0 en headless, 40/0 X11.
- Bureau existant 107/0 ; deux suites JS de suivi : 20 tests verts.
- Échec de démarrage du test Godot voisin reproduit sur sources main et
  signalé à Claude ; aucun helper réservé modifié. Compte rendu dans
  `docs/office-review-reminders-20261112.md`.
- Auto-revue du diff : ciblage par identifiant, retour aux filtres, ordre des
  urgences, disponibilité des mesures et absence d'écriture moteur examinés.
  Aucun autre modèle/sous-agent utilisé, conformément au quota de Léo.
