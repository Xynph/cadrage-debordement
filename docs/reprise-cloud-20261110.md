# Reprise des passations PC — 10 novembre 2026

## Sources et état

Les descriptions des [PR #506](https://github.com/Xynph/cadrage-debordement/pull/506)
et [#507](https://github.com/Xynph/cadrage-debordement/pull/507) portent la reprise.
La dernière passation de #507 remplace les instructions de construction initiale
de Gabi dans #506 : le GLB à six clips est déjà livré dans Git.

- `main` vérifié : `978803ba727e51c5af23f458868c6d56cc878966`.
- Calendrier reçu : `4576807f03d9b203e68ec940a2826243912726dd` (#506).
- Gabi reçu : `ace8e3a6dfd65812a12302d45e356dbc4931a9e7` (#507), qui contient #506.
- Reprise sur une branche distincte, sans changement des branches PC ni fusion.

## Résultats observés

Linux, Node 22.23.4, Godot 4.7.2, rendu X11 OpenGL Compatibility/Mesa llvmpipe.
Les ressources sont préparées avec `scripts/build-godot-prototype.py --stage-only`
et importées avant les recettes. Les profils jetables doivent rester hors du
dossier de l'application, indépendamment du dossier des captures.

| Périmètre | Version | Résultat |
| --- | --- | --- |
| Suites internationales Node, courrier natif et disponibilité en sélection | #506 exact puis #507 exact | 49 tests réussis sur chaque version, aucun ignoré |
| Calendrier, filtres annuels, pagination et courrier vers la fiche Accueil | #506 exact | 46 contrôles réussis à 1920×1080, 46 à 2560×1440 ; 12 captures aux dimensions vérifiées |
| Voix et silence | #507 exact | 199 contrôles Godot réussis |
| Gestes et priorités | #507 exact | 32 contrôles Godot réussis |
| Nouveau banc du GLB réel, avec une carrière créée par le moteur | #507 + banc ajouté | 33 contrôles sans fenêtre ; 39 avec rendu X11 aux deux tailles, six captures |
| Banc UI international rendu durable dans cette reprise | #507 + banc ajouté | 34 contrôles sans fenêtre |

Preuves conservées : [Gabi au Bureau en 1440p](reprise-cloud-20261110/gabi-1440.png),
[fiche d'accueil internationale en 1440p](reprise-cloud-20261110/accueil-international-1440.png),
[rapport Gabi](reprise-cloud-20261110/gabi-rendu.json),
[calendrier 1080p](reprise-cloud-20261110/calendrier-1080.json),
[calendrier 1440p](reprise-cloud-20261110/calendrier-1440.json) et
[journal de la suite générale rouge](reprise-cloud-20261110/guide-integration-rouge.log).
Les [empreintes](reprise-cloud-20261110/sha256.json) identifient ces fichiers.

Le banc réel charge le GLB de production, vérifie ses vingt os et la variation
des poses dans chacun des six clips. Il vérifie F1, l'absence de lecteur audio,
le repos animé, la pose fixe en mouvements réduits, la suspension quand le
portrait est masqué et l'empreinte inchangée du profil sportif.
Les essais d'alternance et de priorité restent couverts par
`godot-gabi-composition.gd`. Les captures sont des poses ponctuelles ; elles ne
mesurent ni la cadence ni le cadrage de chaque image d'un geste complet.

La recette graphique internationale reprend le banc distant de la passation
(`qa/oval-hotes-internationaux-6d6b616`, fichier `ci/cloud-visual-reception.gd`).
Elle utilise une vraie création de carrière et des interactions souris, puis
injecte des éditions et un courrier de recette dans la projection UI pour
tester les filtres et l'ouverture exacte de la fiche. Le calcul des annonces
après finale, les convocations et la conservation des anciennes données sont
testés séparément par les suites moteur. Ces captures ne constituent pas une
simulation graphique de plusieurs saisons réelles.

## Contrôle général rouge au premier relevé — désormais reçu

Ce relevé historique est clos par la [réception des six chantiers](oval-six-chantiers-cloud-20261110.md) : 501 contrôles verts sur le guide corrigé. Au premier passage, `tests/godot-guide-integration.cjs` échouait : **306 contrôles, 29 échecs** sur
#507. Les échecs concernent le focus de MarketReset, la présence de deux offres,
la reprise depuis l'accueil, le menu bas attendu par le banc, les commandes
de match et la réactivation du guide. La suite utilise notamment des libellés
historiques et lance les matchs sans recevoir le nouveau parcours presse.
Il faut distinguer les attentes devenues obsolètes des régressions produit ;
la reprise présente ne corrige ni ne masque ces assertions. La réception
ciblée verte ne rend pas cette suite verte.

## Rejouer les bancs ajoutés

Définir `CD_GODOT_EXECUTABLE` vers le SDK Godot 4.7.2, puis :

```sh
node --test --test-concurrency=1 tests/godot-gabi-real-model.cjs tests/godot-international-reception.cjs
```

Pour Gabi en rendu X11, définir `CD_GABI_REAL_GRAPHICS=1` et éventuellement
`CD_GABI_REAL_OUTPUT` pour conserver les captures. Le même processus reçoit
1080p et 1440p. Pour le calendrier, définir `CD_INTERNATIONAL_UI_GRAPHICS=1`,
`QA_RESOLUTION=1920x1080` ou `2560x1440` et éventuellement
`CD_INTERNATIONAL_UI_OUTPUT`. Utiliser un écran X11 assez grand et isoler les
exécutions sur le même cache d'import Godot. Aucun lanceur n'utilise le profil
personnel ; chacun crée son profil sous le dossier temporaire système.

## Prochaines actions

1. Suite générale du guide reçue : 501/501 ; navigation clavier 133/133. Consulter le bilan cumulatif avant de reprendre les étapes PC.
2. Sur PC, assembler les deux essais Blender manches/carnet, réexporter le GLB
   et reprendre la recette Windows complète de #507. Les fichiers `D:/` cités
   dans la passation ne sont pas accessibles depuis ce Cloud.
3. Fixer le commit retenu, reconstruire le ZIP Windows et vérifier l'import
   Rugby Réel. Aucune nouvelle validation Windows, cadence GPU ou livraison
   de ZIP n'est revendiquée ici. Les branches empilées restent en brouillon.

GPT‑6.1 Sol : effort élevé pour trier les échecs de la suite générale et
assembler le modèle sur PC ; effort moyen pour rejouer les recettes ciblées.
