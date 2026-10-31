# UI-04A — Centre de formation et suivi des jeunes

**Préparation indépendante, pas encore raccordée au jeu jouable.** Ce chantier est fondé sur le `main` `e706d6ade5406b7f7c8e9e9c4cdaeaa9033c4807` validé et respecte la séparation de l'intégrateur unique. UI-02C PR #84 et UI-03A PR #86 ne sont pas fusionnées ; la reprise des fichiers d'interface partagés attend leur revue.

## Ce qui existe déjà réellement dans le moteur

- `S.development.academy` reçoit 4 espoirs par saison, avec limite de rétention 12 et jeunes conservés jusqu'à 21 ans inclus. Ce ne sont **pas des équipes de jeunes jouant des matchs**, seulement une progression d'entraînement.
- Le joueur peut promouvoir un espoir via `promoteYouth(id)`. Le moteur bloque les actions interdites (match, fin de session...), vérifie la limite de **42 professionnels**, affecte le contrat natif, enregistre une opération et sauvegarde.
- `developmentFocusOptions(p)` et `developmentFocusValue(p)` décrivent les objectifs d'entraînement individuels compatibles avec le poste. `setDevelopmentFocus` est la seule action native pour les changer ; elle réinitialise les XP de spécialisation concernés.
- Les notes au poste et les plafonds sont calculés par `roleNote(p)` et `potentialAtRole(p)`. Le potentiel représente un plafond fictif, **jamais une promesse de progression**.
- Les minutes, le gain général de saison et l'historique `p.dev.history` existent déjà. `S.development.retired` conserve des départs historiques, sans générer de faits nouveaux.
- Les éléments de formation sont ceux du club géré. Les évaluations secrètes d'autres clubs et les mécanismes du marché ne sont jamais consultés.

## Livrables, tous nouveaux et indépendants

- `dist/ui04-academy-data.js` : modèle UMD purement calculé, `buildCenter(source,deps)`, `playerView`, `table`. `source` reçoit une **copie** du centre, de l'effectif pro, des retraites, de la saison, du nom du club et du verrou natif `economyLocked()`. `deps` contient les six fonctions officielles : `roleNote`, `potentialAtRole`, `developmentBadge`, `developmentFocusOptions`, `developmentFocusValue`, `retirementSeason`. Les joueurs sont toujours copiés avant l'exécution des helpers natifs susceptibles d'initialiser `skills` ou `dev`.
- `dist/ui04-academy-components.js` : présentation HTML originale (Bleu nuit / violet / Tribune clair), quatre vues **Vue d'ensemble / Centre de formation / Jeunes professionnels / Archives**, onglet de détail d'un jeune avec notes, objectifs individuels, historique réellement connu et accès futur aux commandes natives. Les actions sont seulement des callbacks `onPromote`, `onFocus`, `onNativeProfile`, `onTab`, `onSort`, `onFamily`, `onSearch` ; **aucune action métier n'est exécutée par ce module**.
- `dist/ui04-academy-components.css` : styles bornés à `.cd04`, adaptations 920/600 px, tableaux défilant horizontalement sur petits écrans, focus visible, mouvement réduit, apparences Analyste/Tribune/Système via les variables.
- `tests/ui04-academy-data.cjs` : test natif sur le vrai harness de carrière, quatre jeunes du premier recrutement, notes officielles, changement d'objectif natif, compatibilité anciens documents, non-mutation de `S`, promotion réelle, limite 42, archives du seul club, sauvegarde. Les seules mutations du test sont ses **actions métier explicites de promotion** sur une deuxième carrière isolée.
- `tests/ui04-academy-components.cjs` : tests de rendu des quatre écrans et du détail, champs et identifiants malveillants échappés, actions non exécutées mais correctement déléguées, tables vides, clavier via contrôles natifs, absence de mutation, responsive et UMD navigateur.
- `docs/ui04-academy.md` : ce document.

## Exemple de raccordement UI-04B, non inclus

```js
const source=JSON.parse(JSON.stringify({
  academy:S.development.academy,
  professionals:club().players,
  retired:S.development.retired,
  season:S.season,clubName:club().name,locked:economyLocked()
}));
const model=CDUI04AcademyData.buildCenter(source,{
  roleNote,potentialAtRole,developmentBadge,
  developmentFocusOptions,developmentFocusValue,retirementSeason
});
const table=CDUI04AcademyData.table(model,{kind:'academy',sortBy:'name'});
const html=CDUI04AcademyComponents.renderCenter(model,{view:'academy',table});
```

Lors du futur raccordement, contrôler les ID par appartenance à `S.development.academy` ou à `club().players` avant tout appel `promoteYouth`, `setDevelopmentFocus` ou `inspectCareerPlayer`. Appliquer les préconditions natives, gérer les erreurs d'action, préserver les confirmations et le focus, la navigation et les sauvegardes. Le moteur reste seule source des contrats et promotions ; aucune formule de croissance fictive n'est ajoutée dans la vue.

## Limites et coordination

**Cette PR ne change ni `dist/index.html` ni `dist/development.js`, ne charge aucun module dans le jeu, ne crée aucune session jeune supplémentaire et ne reproduit aucun asset ou code propriétaire FM.** Le jeu continue d'afficher son écran de formation historique jusqu'à intégration. Pas de validation Chromium visuelle du nouvel écran ni de Windows natif revendiquée à ce stade ; les tests UI du lot vérifient le HTML statique, l'échappement et les interactions préparatoires.

Une future **UI-04B** sera distincte, sur le nouveau `main` après intégration de UI-02C et coordination explicite de l'issue #73. La seule personne autorisée à fusionner les PR reste l'intégrateur. Aucune modification du moteur, des coefficients, des sauvegardes, ni de l'audit économique indépendant #85 n'est demandée.
