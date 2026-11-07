# Rugby Réel : logos et portraits, collecte du 7 novembre 2026

Base : `712d0254ef738c1367fda486f8428d5a2569d1a8`. Réservation #73 commentaire 6709743141. Chantier distinct de la calibration V16 / PR #389.

Les fichiers originaux ont été réellement téléchargés : **30 logos et 1 549 portraits pour 1 592 joueurs (97,30 %)**. Il reste **43 joueurs sans portrait de club vérifié**. Le pack privé contient les originaux, une galerie HTML hors ligne, les inventaires CSV, les manques et les planches de contrôle. Les images ne sont pas incluses dans ce dépôt ni raccordées au jeu.

## Méthode et résultat

- Rapprochement exhaustif du master par ID LNR et club, sans modifier les identités ni l'effectif.
- Lecture des 30 pages officielles LNR : 1 590 fichiers téléchargés, dont **83 silhouettes génériques identiques**. Deux portraits ne figuraient pas sur les pages d'effectif.
- Vérification des 83 profils individuels LNR : même silhouette, donc aucune fausse couverture à partir de ces fichiers.
- Compléments sur les pages professionnelles et centres de formation des clubs : **41 portraits**. Tristan Labouteley retrouvé sur son profil LNR ; Rémy Lanen récupéré sur la page officielle de Nevers, en maillot de Nevers, plutôt que sur son profil LNR actuel de Clermont.
- Résultat final : **1 508 portraits LNR + 41 portraits clubs**. Les 43 silhouettes restantes sont exclues des dossiers d'images exploitables.
- Les 30 badges et les 41 compléments de clubs ont fait l'objet d'une inspection visuelle sur planches. Les autres associations reposent sur l'ID officiel LNR et le club source. Cela ne constitue pas une vérification biométrique ni une certification individuelle du maillot de chaque saison.

## Format demandé et exceptions

La majorité des originaux LNR sont des WebP RGBA de 800 × 1 200 pixels, studio, face et torse, exploitables pour un cadrage visage/buste. La galerie affiche le haut des originaux par CSS ; cliquer ouvre le fichier complet. Les fichiers restent intacts : aucun visage inventé, remplacement de maillot, agrandissement artificiel ou recadrage bitmap.

La qualité réelle et l'ancienneté varient malgré les dimensions nominales. Les compléments de clubs vont notamment de 289 × 493 à 4 500 × 7 367 pixels. Cinq alternatives sont explicitement signalées : Mafileo en monochrome ; Tafili avec fond sombre ; Abel en pose inclinée avec ballon ; Enzo Jean avec geste et ballon ; Baramia avec ballon et fond décoré. Il ne s'agit donc pas encore d'une collection uniformisée de 1 549 vignettes identiques à l'exemple fourni.

Neuf variantes de légende sont conservées dans `validation.json` : prénoms supplémentaires/abrégés, ordre du nom pour Abel et Jules Bonnard Martin, alias Maka Mafileo. Les noms du master ne sont pas changés. Le cas Finn Newton est rejeté : le titre du média officiel indique Newton mais le fichier indique Sandro Morvan. Les images de Papali'i Abraham ne sont pas attribuées à Dalton Papalii.

## Reproduire les originaux et vérifier

Dépendances locales : Python 3.10+, Pillow ; `httpx` facultatif pour les connexions réutilisées. Node est utilisé par la découverte initiale des pages LNR. Installer les dépendances dans un environnement local, hors production.

```sh
python tools/rugby-real-media-v1/collect.py --pack /tmp/rugby-media --manifest data/scouting/media-v1-20261107.json --workers 6
python tools/rugby-real-media-v1/validate.py --pack /tmp/rugby-media
node tests/rugby-real-media-v1-20261107.cjs
```

Le mode `--manifest` rejoue les URL examinées et exige les mêmes empreintes SHA-256. Une source qui change provoque une erreur, à réexaminer manuellement. Sans ce paramètre, le collecteur effectue une **découverte brute LNR** : son bilan de fichiers téléchargés n'est pas un bilan de vrais visages et nécessite une nouvelle curation des silhouettes et des manques. Les compléments ne sont pas redécouverts automatiquement par cette commande brute.

Le validateur ouvre intégralement chaque image sélectionnée, vérifie son format, ses dimensions et son empreinte. Aucun contenu identique n'est attribué à deux joueurs dans la sélection finale. Le test JavaScript vérifie les 1 592 associations avec le master, les 30 clubs, les décomptes, les manques, les chemins et l'exclusion des silhouettes connues. Les tests CI ne retéléchargent pas les images.

## Réutilisation et périmètre

Le manifeste expose les URL officielles, les associations et les empreintes ; la disponibilité publique ne prouve pas les droits de redistribution. Le pack de travail est remis séparément. Une éventuelle diffusion publique dans le jeu demande de traiter les droits des images et des marques ; cette PR ne les déclare pas acquis.

Seuls les cinq chemins réservés sont ajoutés. Aucun actif DATA/LNR, moteur, interface, Godot/France30, MATCH3D, sauvegarde, calendrier, workflow ou protection n'est modifié. Aucune fusion ni passage READY.
