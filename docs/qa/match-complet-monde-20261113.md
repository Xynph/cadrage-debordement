# Match complet Monde — recette Cloud du 13 novembre 2026

Passation d'origine : https://github.com/Xynph/cadrage-debordement/issues/591#issuecomment-6857605462
Base `main` : `b187b455`. PR dédiée #675, sans fusion.

## Causes et corrections

- Jeu : le moteur peut désigner un porteur hors de l'alignement (rôle `walk`). `_start_maul` distribuait toutes les places avant de lire le `slot` de ce porteur. L'exception interrompait la transition après remplacement de `cast`, mais avant passage de `touche` à `maul` ; `place` et `_frame_points` lisaient alors `mark` dans les dictionnaires de maul. La place du porteur est maintenant réservée avant distribution, sans valeur de repli arbitraire sur `slot` ou `mark`.
- Sonde : `for played: Node in regies` affectait une référence libérée avant le test `is_instance_valid`. Le collecteur garde les tableaux de suivi par identifiant d'instance, sans conserver les Nodes. Les ajouts tardifs restent visibles et sont copiés au rapport. Le dernier résumé de match survit à la fermeture du direct. Le journal est écrit en continu et une erreur GDScript rend désormais la commande rouge même si Godot sort avec 0.

Aucun changement des règles, du résultat sportif, des sauvegardes ou des données privées. Les séquences publiques servent de rejeu de présentation ; aucun ancien mode de carrière n'est exécuté.

## Environnement et commandes

Codex Cloud Linux, SDK officiel Godot 4.7.2 épinglé dans `ci/godot-sdk.json`, archive vérifiée par SHA256. Affichage X11 du Cloud, OpenGL Compatibility / Mesa llvmpipe (rendu logiciel), 960×540, pilote audio Dummy. Aucun accès au PC personnel ni au runner RTX, aucun dispatch vers un dépôt privé.

Le staging de `b187b455` refuse la base commune périmée. #670 porte déjà sa correction : régénération standard locale, staging, puis restauration exacte du fichier suivi ; aucun changement de base commune inclus dans cette PR.

```sh
export CD_GODOT_EXE=/chemin/vers/Godot_v4.7.2-stable_linux.x86_64
mkdir -p work
# Staging temporaire tant que #670 n'est pas intégré :
cp dist/rugby-common-rosters.js work/common-original.js
node scripts/build-rugby-common.cjs
python scripts/build-godot-prototype.py --stage-only --node "$(command -v node)"
cp work/common-original.js dist/rugby-common-rosters.js
"$CD_GODOT_EXE" --headless --audio-driver Dummy --path native/godot --import
CD_LIAISON_EXPORT="$PWD/work/monde.json" node tests/godot-match-liaison-monde.cjs
CD_MATCH_TEMPS_FORTS_EXPORT="$PWD/work/monde.json" \
CD_MATCH_TEMPS_FORTS_PROOF="$PWD/work/recette" \
CD_MATCH_TEMPS_FORTS_SIZE=960x540 CD_MATCH_TEMPS_FORTS_EVERY=60 \
CD_MATCH_TEMPS_FORTS_HORLOGE=eclair CD_MATCH_TEMPS_FORTS_VITESSE=4 \
CD_MATCH_TEMPS_FORTS_GODOT_ARGS='--audio-driver Dummy' \
node tests/godot-match-temps-forts-capture.cjs
node --test tests/godot-match-complet-regression.cjs \
  tests/godot-match-cadrage-arret.cjs tests/godot-match-gestes-adaptes.cjs
"$CD_GODOT_EXE" --headless --path native/godot --script "$PWD/tests/godot-match-gestes.gd"
```

L'export est une carrière jetable `world-champ`, graine 7, club 0, préparée par le vrai worker. Empreinte SHA256 : `b4082152a15c8b262473b08d9993c93c07ce1cb248de4ddf1202f8c3e5b700ca`. L'option `CD_LIAISON_EXPORT` prépare seulement l'export et refuse d'écraser un fichier existant.

## Résultats

SHA corrigé effectivement rejoué : `1e5ce1b8c015130dbd4cf168dce0a1df1aaf5c3f`. Les commits de preuves suivants ne changent que la documentation et les reçus.

- Témoin complet avec le jeu de `main` non corrigé et la sonde instrumentée corrigée : fin à la 81e minute, score 12–13, 14 temps forts, 1 échéance ; **728 erreurs ciblées** (90 `slot`, 638 `mark`).
- Match corrigé complet : **sortie 0**, 81e minute, **12–13**, 14 temps forts, **0 échéance**, 29 images, aucun gel ni troncature. **Zéro SCRIPT ERROR ou Parse Error**, dont aucune erreur `slot`/`mark`.
- Rapport final relu après sortie : `termine=true`, `scene_live_liberee=true`, `regies_collectees=2`, **28 entrées de suivi conservées**. Les captures sélectionnées montrent le maul puis le retour à la Réception. Le rendu du match a duré 478,4 s dans la sonde, commande entière 520 s ; ces durées de rendu logiciel ne sont pas des FPS matériels.

- Régression ciblée : 64 contrôles, zéro échec ; quinze postes, porteur en queue avec place, cohérence distribution/cadrage ; deux régies réellement libérées, dernier ajout conservé, rapport écrit et relu sans doublon.
- Fixture publique de la 75e : 3 contrôles agrégés, zéro échec ; minima TV pénalité/carton 14/18 joueurs, Action 9/15.
- Gestes adaptés : 24 contrôles, zéro échec, bibliothèque synthétique des clips publics CC0 et repli procédural. Ceci ne teste pas Mixamo.
- Séquence publique gestes : 129 contrôles, zéro échec ; aucun script du harnais d'ancien mode n'est exécuté (rejeu GDScript direct de la fixture uniquement).
- La nouvelle suite est découverte automatiquement parmi les suites SDK par `ci/shard-tests.cjs`.

## Preuves publiques

[Manifeste et empreintes](match-complet-monde-20261113/manifest.json), [rapport corrigé complet](match-complet-monde-20261113/report.json), [journal corrigé complet](match-complet-monde-20261113/godot.log), [contrôles ciblés](match-complet-monde-20261113/regressions.log), [gestes existants](match-complet-monde-20261113/gestes-existing.log).

Témoin : [extraits et compte des erreurs](match-complet-monde-20261113/match-main-errors.log), [journal original complet compressé](match-complet-monde-20261113/match-main-godot.log.gz), [rapport du témoin](match-complet-monde-20261113/match-main-report.json), [défaut distinct de la sonde](match-complet-monde-20261113/sonde-before.log).

Deux des 29 captures sont versionnées : [maul à la 24e](match-complet-monde-20261113/tf-00008.jpg), [après fermeture du direct](match-complet-monde-20261113/tf-00029.jpg). Le rapport liste toutes les captures produites ; les 27 autres images ne sont pas versionnées. Les avertissements de bibliothèque de parole absente et de repli UID des textures Gabi sont conservés dans le journal ; ils ne sont pas des erreurs de gestes.

## Limites et intégration

Pas de GPU matériel ni qualification Forward+ Vulkan, pas de mesure RTX/FPS matériel, pas de Mixamo ni pack Rugby Réel, pas d'exécution native Windows. La géométrie des caméras TV/Action de la fixture 75e est vérifiée en headless ; le match entier est rendu sous OpenGL logiciel. Ces résultats ne remplacent pas la recette matérielle privée.

PR initialement en brouillon ; le rouge « Validation CI » de brouillon est attendu. L'intégrateur doit recevoir les contrôles exigés sur le HEAD final et appliquer le gate du dépôt après autorisation de Léo. Aucune fusion ni auto-merge demandé.

Modèle et effort effectivement utilisés : non exposés par le runtime. Recommandation GPT-6.1 Sol : élevé pour cette correction, moyen pour la seule réception des contrôles et la passation.
