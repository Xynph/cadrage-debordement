# Qualification des neuf fixtures Godot isolées — 11 novembre 2026

Base de production testée : `96f537040bf9f2e37bf10b0a9b09518b732244a2`.
Correctifs : `120bb1e` installe les helpers dans neuf wrappers CJS et lie `art/`
dans les trois copies qui l'omettaient ; `bfc4a99` actualise les contrats GD
art07/compétition et configure le guide sans voix. Aucun code de production ni
helper partagé n'est modifié dans ces commits.

## Périmètre et reproduction

Le classement SSH sur cette base contient exactement neuf entrées
`AIDE_NON_INSTALLEE`, les neuf lignes ci-dessous. Le harness copié précharge
`helpers/contextual_flow.gd` relativement à son nouvel emplacement, sans
installation initiale de ce fichier. L'erreur a été reproduite avec le vrai SDK
sur art07 avant correction :

```text
SCRIPT ERROR: Parse Error: Preload file "res://helpers/contextual_flow.gd" does not exist.
```

L'inspection des neuf wrappers confirme la même omission. Pour guide-layout,
le harness est hors `res://` : son helper est donc copié dans le répertoire
`helpers` voisin du harness, et non dans le sous-projet. Les copies du helper
validées portent toutes le SHA256 original :
`d9c2c5792f93e2c5f7d19980b046286f9b9208869ddc1fd15a5af4bdd86c625d`.

## État figé pour la sélection CI

Les durées excluent l'attente du verrou. TAP mesure le test ; les nouveaux
reçus JSON mesurent Node complet. Le temps d'art07 est approximatif, déduit de
la naissance de la fixture jusqu'à la capture complète du log ; aucun
chronomètre du seul Node n'avait été enregistré pour ce premier replay.

| Suite `tests/<nom>.cjs` | Qualification | Contrôles / échecs | Durée | Rendu et preuve locale |
| --- | --- | --- | --- | --- |
| godot-art-direction07 | PASS complet | 1516 / 0 ; 43 PNG | environ 127,28 s | X11 ; `contracts/godot-art-direction07.log` |
| godot-competition-editor | PASS complet | 61 / 0 | 95,203 s TAP | headless ; `contracts/godot-competition-editor.log` |
| godot-epcr-preparation | PASS complet | 132 / 0 | 59,091 s TAP | headless ; `repaired/godot-epcr-preparation.log` |
| godot-guide-layout | PARTIEL : layout/native uniquement | 260 / 0 | 71,805 s Node | X11 ; `final/godot-guide-layout__layout-native.log` |
| godot-immersive-reception | PASS complet | 35 / 0 | 83,724 s TAP | headless ; `repaired/godot-immersive-reception.log` |
| godot-interface-layout | NON QUALIFIÉ : environnement | aucune assertion UI exécutée | 3,426 s Node | X11 : DISPLAY=:101 disparu ; `final/godot-interface-layout.log` |
| godot-lineup-layout | NON QUALIFIÉ : pas encore rejoué | — | — | En attente après priorités P1 et baselines SDK |
| godot-native06-integration | PASS complet | 260 / 0 | 65,758 s Node | headless ; `final/godot-native06-integration.log` |
| godot-readability06 | NON QUALIFIÉ : pas encore rejoué | — | — | En attente après priorités P1 et baselines SDK |

Les chemins de preuve sont relatifs à `/workspace/qa/sdk-preloads-96` sur la
machine Cloud ; ils ne sont pas des artefacts GitHub archivés par ce rapport.
`qualified-so-far.json` contient les cinq suites complètes, leurs SHA CJS/GD,
rapports et environnements. `qualified-guide-cases.json` décrit le seul cas
guide retenu. `provenance.json` et `results.tsv` donnent l'inventaire complet.
Les reçus ultérieurs constituent une qualification complémentaire ; aucune
ligne non qualifiée n'est implicitement verte dans ce gel.

## Contrats UI actualisés

Art07 vérifie le chrome immersif courant : bandeau lisible, navigation contenue
et accessible au clavier, contraste, pictogrammes et sélection. Les quatre
formats, dix routes, deux clubs et invariants export/RNG/disque sont conservés.
L'ancien accès obligatoire à `app.heading` échouait sur les canevas dédiés,
où le shell met volontairement ce champ à null.

La compétition vérifie le texte réellement affiché dans le Label de
confirmation, puis la Réception ouverte après création. Les 61 contrôles
conservent notamment l'annulation, les refus réels, le club choisi, l'export,
l'import et la préservation de la carrière.

Le premier guide X11 est invalidé : l'ancien harness activait sa voix et
rencontrait `Parameter "synth" is null` sur Linux. Aucun compteur vert de ce
replay n'est retenu. Le harness courant appelle `setup(app,false)` ; il exige
les commandes vocales absentes/cachées et, à la fin, zéro signal `requested`,
muted et aucun lecteur audio. Géométries, clics et focus restent testés.
Aucun ERROR n'est filtré et aucun backend vocal n'a été installé. Le moteur
peut encore signaler au démarrage l'absence de `libspeechd.so.2`, mais le
harness silencieux n'interroge plus les voix et ne crée aucun lecteur.

## Environnement et reprise

Godot officiel Linux 4.7.2 :
`/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64`.
Node 22.23.4 :
`/workspace/.cloud-setup/tools/node-v22.23.4-linux-x64/bin/node`.
Staging avec `build-godot-prototype.py --stage-only`, puis import réel.
Profils jetables et audio Dummy ; une acquisition de
`/tmp/rg27-godot-sdk.lock` par invocation. Aucune preuve Windows revendiquée.

Les replays graphiques retenus utilisent Xvfb `DISPLAY=:101`,
2560×1440×24, OpenGL Compatibility Mesa/llvmpipe. Art07 active
`CD_ART07_GRAPHICS=1`. Le cas guide active `CD_GUIDE_GRAPHICS=1`,
`CD_GUIDE_LAYOUT_CASE=layout`, `CD_GUIDE_LAYOUT_MODE=native`.
Le serveur 101 a ensuite disparu : l'échec d'interface est environnemental,
sans résultat sur le produit. Le prochain replay utilisera le serveur 102
relancé par l'intégrateur.

Il reste interface, lineup, readability et les cas guide layout/stretch,
dock/stretch et dock/native. Chaque future invocation est limitée à 180 s
pour Node, avec arrêt sur erreur de script terminale et mesure hors verrou.
Le wrapper guide sans filtres cumule quatre cas : des passes séparées ne
qualifient pas automatiquement sa durée cumulée sous 180 s.
