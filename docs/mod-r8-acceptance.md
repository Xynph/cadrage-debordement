# R8 — Pont concret R4 vers le gestionnaire canonique R5

## Résultat
Le module `modding/r4/installed-adapter.cjs` est un **adaptateur sans registre propre** : lit une archive ZIP contrôlée par R4, transforme `manifest.json` et les fichiers JSON en `{manifest,records}` attendu par R5, puis appelle explicitement `world.install(normalized)` sur l'instance R5 fournie par l'intégrateur. Aucune activation automatique. Prise en charge des collections R1/R2: competitions, clubs, players, staff, academy, fixtures. `loadInstalled` recontrôle les fichiers persistés et les empreintes avant de préparer leur activation.

## Dépendances et réception
R8 est une PR empilée sur R7 (#104), lui-même empilé sur R4 (#101). L'intégrateur doit examiner et intégrer dans cet ordre **après CI verte**. R5 (#102) puis R6 (#103) fournissent le gestionnaire cible, séparément. En cas de double validation des catalogues, désigner R1/R2 comme validation d'entrée et R5 comme unique sélection active. Ne jamais copier un deuxième état actif dans R3.

## Hors périmètre
Pas d'UI `dist`, de nouvelle carrière modée dans le moteur, ni de migration des anciennes parties. Ce pont ne rend pas les mods jouables tout seul. Aucune ressource réelle n'est incluse. Les ZIP complexes (ZIP64, entrées dossiers) restent à traiter avant exposition à des utilisateurs.

## Test
`node tests/mod-r8-package-adapter.cjs` : une véritable archive ZIP construite en mémoire, conversion R4 → R5, injection sans activation, erreurs d'identifiants/collections et corruption des données. Validation dans navigateur et application Windows ultérieurement obligatoire.
