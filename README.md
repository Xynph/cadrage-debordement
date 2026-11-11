# Preuves de la recette Linux du 11 novembre 2026

Branche orpheline, sans PR : elle ne sert qu'à rendre téléchargeables les
preuves citées dans la PR #549 (`docs/audit-20261111.md`). Elle ne doit pas
être fusionnée. Elle peut être supprimée après la livraison.

## Périmètre exact

| | |
| --- | --- |
| Commit testé | `3b42dbf2d3eda6450030a5161548ec768ff8bc47` (tête de #543 le 10 novembre) |
| Ce qui a tourné | Le projet Godot stagé, lancé par l'éditeur Godot 4.7.2 Linux, avec le pilote de recette embarqué (`CD_GODOT_SELF_TEST=1`) |
| Machine | Conteneur Linux, 2 processeurs, sans carte graphique : voir `journaux/machine.txt` |
| Affichage | X11 par Xvfb en 2560×1440, rendu logiciel Mesa `llvmpipe` |
| Résultat | 2 586 contrôles, 0 échec, saison 2 atteinte, 102 captures, 29 minutes |

**Ce n'est pas une recette Windows** et ce n'est pas une recette de
l'exécutable exporté : ni l'export, ni le Node embarqué, ni le plein écran
physique n'ont été exercés (`SKIP physical fullscreen/windowed reception: X11`).
Ce n'est pas non plus la version commune de #539.

## Commandes

```bash
python3 scripts/build-godot-prototype.py --stage-only --node "$(which node)"
./Godot_v4.7.2-stable_linux.x86_64 --headless --path native/godot --import
CD_GODOT_SELF_TEST=1 CD_GODOT_DATA_DIR=/tmp/profil CD_GODOT_QA_CAPTURES=/tmp/captures \
CD_NODE_EXECUTABLE="$(which node)" \
xvfb-run -a -s "-screen 0 2560x1440x24" ./Godot_v4.7.2-stable_linux.x86_64 --path native/godot --audio-driver Dummy
```

## Contenu

| Chemin | Contenu |
| --- | --- |
| `captures/*.webp` | Les 102 captures écrites par le jeu, en WebP sans perte |
| `MANIFESTE.json` | Pour chaque capture : dimensions, taille et SHA-256 du PNG d'origine et du WebP, résultat de la comparaison pixel à pixel |
| `journaux/rapport-recette.json` | Le rapport machine écrit par le pilote de recette |
| `journaux/recette-integree.log` | Sortie complète de Godot pendant la recette |
| `journaux/import-godot.log` | Sortie de l'import préalable |
| `journaux/machine.txt` | Système, processeur, versions de Godot, Node, Mesa et Xvfb, empreinte du binaire Godot |

Les PNG d'origine (70 Mo) ne sont pas publiés : les WebP en sont la copie
exacte, 40 Mo. Pour retrouver un PNG : `dwebp capture.webp -o capture.png`
donne les mêmes pixels ; l'empreinte du fichier PNG peut différer, celle des
pixels non.

Les captures montrent la base du jeu (mode « common »), sans pack importé.
