# Approfondissement du suivi individuel des jeunes

## Périmètre et interfaces

L’état existant version 1 conserve une référence, la dernière mesure et six observations datées avec leurs écarts. Le lot conserve ce schéma : aucune migration, aucune observation reconstruite avant activation, aucun budget XP ou effet de mentorat modifié.

Le bilan historique reste disponible. Une projection `review.recent` décrit une fenêtre visant quatre semaines, bornée par des observations réellement conservées et datées ; ses bornes et sa durée réelle sont affichées. Les écarts sont reconstitués par soustraction des deltas existants depuis la dernière mesure, sans interpolation entre matchs. Les changements de saison, de club, de stade ou les compteurs régressifs ne deviennent pas des déficits fictifs.

`review.shortTermObjective` conserve la date de décision du plan et une échéance de réexamen. Un objectif de minutes à quatre semaines utilise le repère consultatif de 80 minutes réellement nouvelles. Les objectifs de niveau/qualité restent des repères de +1 ; une progression annuelle renvoie explicitement au bilan annuel. Si l’ancre de décision a quitté les six observations conservées, aucun progrès depuis cette décision n’est inventé.

Les réorientations ouvrent un détail centré sur le joueur avec les boutons et commandes existants de premier contrat ou de prêt, leur contexte, leurs contrôles et leurs confirmations. Préparer une réorientation reste local ; consulter ne signe rien. Les budgets et priorités de croissance existants restent inchangés.

## Validation exécutée

Avant implémentation, les huit nouveaux scénarios échouaient parce que le bilan récent et l’objectif daté étaient absents. Après implémentation, 36 tests Node passent : neuf nouveaux cas et les 27 cas existants de plans, bilans et observations. Ils couvrent plusieurs mois, six observations conservées, niveau et qualités réellement mesurés, renouvellement du même plan, saison/club/stade, régression de compteur, progression annuelle, projection pure et reprise exacte de l’état v1. Les tests de plans existants vérifient toujours la conservation du budget XP, les plafonds, les blessures et l’absence de gain immédiat.

Un test du worker de production passe après quatre véritables semaines et rencontres. Il reçoit un conseil de prêt fondé sur ces observations, refuse un club d’accueil invalide sans toucher au profil, réalise le prêt réel et conserve identité unique, historique du suivi, import strict et reprise disque exacte. Son export prépare aussi la recette Godot ; aucun état de carrière ou modèle projeté n’est injecté artificiellement.

La recette Godot 4.7.2 / Node 22.23.4 Linux passe **147 contrôles, zéro échec** : vraies routes Formation et Centre, ouverture du suivi, aperçu et annulation sans mutation en 1080p/720p, objectif daté du worker, premier contrat ciblé avec confirmation du salaire, promotion réelle, refus visible et atomique d’un doublon, conseil récent de prêt, choix réel du club d’accueil, annulation puis prêt effectif et reprise disque exacte. Les deux dialogues ciblés sont contenus avec leur titre dans la fenêtre 720p. La régression Godot historique des bilans passe **55 contrôles, zéro échec**.

Commandes exécutées :

```sh
node --test tests/deepen-youth-window.cjs tests/youth-development-plan.cjs tests/youth-development-review.cjs tests/youth-development-observation.cjs
node --test tests/deepen-youth-worker.cjs
CD_GODOT_EXECUTABLE=/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64 node --test tests/deepen-youth-ui.cjs
CD_GODOT_EXECUTABLE=/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64 node --test tests/godot-youth-development-review.cjs
```

Node était explicitement celui de `/workspace/.cloud-setup/tools/node22/bin/node`. Les profils et répertoires XDG des recettes étaient sous `/tmp`, hors application. Preuves finales : `/tmp/cd-deepen-youth-X6fN6b/godot.log`, `/tmp/cd-youth-review-TEZ7Sy/godot.log` et `/tmp/deepen-youth-backend.log`.

Le premier essai de régression historique, lancé sans XDG temporaire, avait ses 55 contrôles fonctionnels réussis mais son runner refusait les erreurs de création du journal sous le domicile non inscriptible. Le nouvel essai avec XDG temporaire est entièrement vert. Une course du nouveau runner à la reprise (deux requêtes snapshot initiales) a été corrigée en attendant l’unique réponse de démarrage ; elle n’a nécessité aucun changement du moteur.

## Limites explicites

La fenêtre vise quatre semaines et conserve les bornes des échantillons disponibles ; en cas d’observations espacées, sa durée réelle peut être supérieure et reste affichée. L’objectif daté ne reconstruit pas une décision sortie des six observations : sa mesure devient indisponible, et confirmer à nouveau le même plan lors d’une semaine ultérieure crée une nouvelle ancre sans dépenser d’XP. Une frontière de saison est désormais observée même si les valeurs restent égales. Les objectifs restent consultatifs, sans récompense ni attribution causale des progrès au plan. Le modèle annuel conserve son horizon annuel. L’ancien club n’est pas utilisé pour diagnostiquer les occasions du nouveau.

Les prêts nécessitent les parcours existants du centre : leur activation reste une décision séparée et explicite. Les parcours Espoirs du Monde ne sont pas disponibles ; leur motif existant reste affiché. Le premier contrat de base réutilise Formation. Aucune nouvelle règle d’éligibilité, aucun budget, aucune migration et aucun bonus ajouté. Aucun test Windows ni test graphique/audio revendiqué.
