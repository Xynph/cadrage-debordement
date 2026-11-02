# MATCH 3D — prototype technique (lots 00/01)

## Objectif et limites

Vue 3D optionnelle du match courant, alimentée par `matchScene(l)` issu de `dist/match2d.js`.
Elle ne recalcule ni le rugby, ni les décisions, ni les statistiques, ni les scores.
Le rendu utilise Three.js r149 figé et embarqué localement (MIT); aucun appel CDN.

Le terrain est schématique : 100 unités longitudinales et 70 transversales,
les maillots et joueurs sont des primitives 3D sans prétention photoréaliste.
Il ne faut PAS interpréter le choix des positions et les interpolations comme une trajectoire officielle du moteur.
Les événements anciens dont les scènes sont absentes restent couverts par le repli 2D.

## Contrat des scènes

`CDMatch3DAdapter.normalize(matchScene(l))` extrait uniquement des champs existants :
`key`, `kind`, `stage`, `period`, `players[{id,side,slot,x,y,featured}]`,
`ball`, `origin`, `possession`. 30 joueurs au maximum, exclusions respectées.
Aucun état 3D n'est conservé dans les sauvegardes et aucune mutation sur `S` ou `S.live`.

## Intégration

- `dist/index.html` charge le moteur local, l'adaptateur, puis la vue 3D après `game.js`.
- Le panneau 2D demeure le choix par défaut et reste accessible immédiatement.
- Le changement de vue est une préférence volatile. Les matchs déjà en cours demeurent dans le format original.
- En cas d'absence de WebGL, la vue 2D reste utilisable.
- Le programme Windows doit embarquer `dist/match3d/**` ; vérifier explicitement le packaging avant livraison.

## Réception

- `node tests/match3d-adapter.cjs` : projection sans mutation, coordonnées et 30 joueurs.
- Réception Chromium à mener sur la page réelle : démarrer un match, choisir 3D,
  constater un canvas, basculer TV/Tactique, reprendre le match, revenir en 2D,
  vérifier score et sauvegarde inchangés.
- Tester en particulier les chemins `offline/` et l'absence de requête réseau.
- La production d'animations réalistes, de plaquages et de rucks reste hors lot 01.

## Risques identifiés

La scène source `matchScene` fabrique des positions schématiques et n'enregistre
pas les trajectoires de tous les joueurs. Le rendu interpole les positions mais
ne doit jamais inventer des statistiques. L'affichage 3D ne doit pas provoquer de
boucle `render()` ou conserver des contextes WebGL abandonnés.
