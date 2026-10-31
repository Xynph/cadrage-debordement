# UI-03A — Fondations du centre de recrutement et scouting

**État :** projet UI autonome préparatoire, **pas encore intégré à la version jouable**. Développement sur `main` `e706d6ade5406b7f7c8e9e9c4cdaeaa9033c4807`, tandis que UI-02C PR #84 demeure en revue. Direction graphique originale bleu nuit / violet inspirée des principes de lisibilité du design FM27 validé ; aucun code ou asset propriétaire de Football Manager n'est copié.

## Fichiers et responsabilités

- `dist/ui03-scout-data.js` : modèle UMD sans dépendances DOM, alimenté exclusivement par les mécanismes existants `managerPool`, `recruitmentNeeds`, `recruitmentEvidence`, `S.manager.missions`, `S.manager.reports`, `S.manager.watch`, la saison et la semaine natives. Fonctions `buildCenter` et `candidateTable`. Il n'appelle pas le moteur pour recruter ni pour lancer une mission.
- `dist/ui03-scout-components.js` : vues UMD du cockpit de recrutement (Vue d'ensemble, Candidats, Rapports, Missions, Suivis), tableaux, cartes et formulaire de mission. Les handlers sont des **callbacks futurs**, ils n'exécutent jamais `watchPlayer`, `createScoutMission`, `openContract` ou `save` directement.
- `dist/ui03-scout-components.css` : feuille isolée sous `.cd03`, responsive, thèmes sombre/clair via `data-cd-theme`, focus visible et réduction des animations. Aucun style du jeu actuel n'est écrasé.
- `tests/ui03-scout-data.cjs` : véritable harness avec carrière et mission native ; contrôle strict de non-divulgation des caractéristiques cachées, des bornes de recrutement du moteur et de la non-mutation.
- `tests/ui03-scout-components.cjs` : rendus HTML, formulaire, délégation des événements, injection HTML, champs connus/inconnus, états vides, styles.
- `docs/ui03-scout-center.md` : ce document.

## Contrat de données / informations connues

Pour le futur contrôleur :

```js
const model=CDUI03ScoutData.buildCenter({
  pool:managerPool(),
  reports:S.manager.reports,
  missions:S.manager.missions,
  watch:S.manager.watch,
  needs:recruitmentNeeds(),
  season:S.season,
  week:S.economy.week
},{evidence:recruitmentEvidence});
const table=CDUI03ScoutData.candidateTable(model,{search:'',family:'all',sortBy:'name',direction:'asc'});
const html=CDUI03ScoutComponents.renderCenter(model,{view:'candidates',table});
```

**Règle non négociable :** les agents libres **non observés** sont représentés uniquement par leurs attributs publics `id/name/pos/fam/age/price/salary` et les bornes `noteMin/noteMax` données par **`recruitmentEvidence(p)`**, dont la logique indicative est déjà présente dans `dist/manager.js`. Leur potentiel demeure `null`, leur grade demeure `null` ; le modèle n'expose jamais `rating`, `skills`, `dev.potential`, `skillBase`, ou une estimation construite à partir de ces informations. Il transmet à la fonction native d'évaluation **une enveloppe publique uniquement**, pas un joueur complet.

Lorsqu'un rapport natif existe, sa fourchette `noteMin/noteMax`, sa fourchette de potentiel et son indicateur `stale` proviennent toujours de `recruitmentEvidence` ; on n'ajoute aucun nouveau coefficient et aucune appréciation fictive. Le panneau Rapports affiche les notes exactes **historiques enregistrées dans le rapport**, datées (saison/semaine) ; ces valeurs ne sont jamais présentées comme des évaluations actuelles garanties. Un rapport subsiste si le candidat n'est plus au marché, marqué « Indisponible », sans prétendre connaître sa situation future. Les résultats de `recruitmentNeeds` exposent les scores/raisons déjà calculés pour le club (dont l'éligibilité technique de la première ligne), sans recalculer les besoins.

Les listes et filtres sont stables et vérifiables : recherche accent-insensible, famille 0–8, rapports uniquement, suivis uniquement, plafonds salariaux/frais, tri sur champs publics ou estimation native `noteMin`. Aucun score secret de recrutement ne détermine l'ordre.

## Missions et limites des actions

Le formulaire reflète **exactement les contraintes de `createScoutMission`** du jeu actuel : famille 0–8, âge 18–40, prime 0–10 M€, salaire 1 000–100 000 € / semaine, coût de mission 5 000 €, délai de deux journées. L'interface ne suppose pas qu'une mission est financièrement possible ni qu'un joueur sera trouvé. La capacité (max quatre missions non terminées), la trésorerie disponible et le verrou en cours de match seront réévalués par **l'unique commande native** au futur raccordement, pas par ces modules.

Les boutons d'observation, de suivi et d'accès au candidat ne font que soumettre des callbacks `onMission`, `onWatch`, `onCandidate` au futur contrôleur. Le module n'a **aucun accès aux sauvegardes** et n'est pas chargé par `dist/index.html` dans cette PR. Les actions de recrutement et négociation conservent la validation existante.

## Raccordement ultérieur et gouvernance

Attendre la revue/fusion et CI post-fusion de la PR #84 UI-02C, puis vérifier les réservations de l'issue #73 et construire un **lot UI-03B distinct** sur le nouveau `main`. Celui-ci raccordera `recruitmentView` de la navigation existante, sans priver le joueur des missions/rapports/suivis actuels, des contrats, des équipes de compétition, des commandes de session ou du cockpit de match. Les données de recruteurs adverses non observés devront rester secrètes. Vérifier le comportement du formulaire au clavier, les erreurs et le retour du focus, les sauvegardes et le navigateur sur un vrai `dist/index.html`.

Le compte producteur prépare uniquement cette PR et la passation ; l'intégrateur unique reste responsable de toutes les fusions et de la vérification CI post-fusion. Les limites du lot présent sont **tests natifs et tests de rendu statique**, pas de clics end-to-end Chromium de ce nouveau composant tant qu'il n'est pas raccordé, pas de Windows natif ni d'appareil physique.
