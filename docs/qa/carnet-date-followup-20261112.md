# Carnet : réception ciblée de la date de compétition — 12 novembre 2026

Le passage local consolidé `2d366010181a2211ab96a40e566343331d8e7dc6`
termine à **4 286 contrôles, 0 échec**, sortie 0. Il reçoit le correctif
de hauteur `0ea71cf210804c6d3d7b71f5bca8cbbe8f4cbc6d` et l'ajout explicite
`--audio-driver Dummy` au wrapper, avec Godot officiel
`4.7.2.stable.official.ed1daf0bf`. L'intégrateur a exécuté cette réception ;
aucune nouvelle exécution SDK ni import n'a été lancé pour rédiger ce reçu.

## Échec conservé et périmètre du correctif

La CI initiale, job `130888398450`, sur
`37e085b687b4e9a603085beaa50fecf9d6cace22`, reste un reçu rouge :
**4 281 contrôles, 1 échec**, statut 1, durée du registre **64 970 ms**.
L'assertion exacte est « Cible et texte utilisables Classements
CompetitionNextDateLink ». Voir le [journal CI original](carnet-date-followup-20261112/ci-original.log).

La cible transparente avait une hauteur fixe de 24 unités, insuffisante pour
la police héritée à certaines tailles. Le correctif conserve sa position et
sa destination ; sa hauteur couvre désormais celle du libellé de date et de
la police héritée. Les seuils de `bounds()` restent inchangés. Le test vérifie
aussi que la date visible, non vide, figure dans le libellé accessible de la
cible. Ces assertions supplémentaires expliquent le delta de **5 contrôles**
entre les deux reçus : cinq passages où cette carte est présente, et non
cinq résolutions distinctes. Aucun bouton sans nom n'est accepté par ce contrôle.

L'examen statique de la géométrie aux largeurs 1280, 1440, 1600, 1920 et
2560 ne relève pas de recouvrement avec l'action suivante. Ce constat
statique ne constitue pas une réception graphique de ces cinq largeurs.
Le scénario exécuté ne boucle que sur 1280 × 800, 1440 × 900 et
1920 × 1080, puis trois modes de carrière et des projections particulières.

## Réception locale et limites

Le [journal TAP local](carnet-date-followup-20261112/local-tap.log) donne
**82 862,453128 ms** pour le sous-test et **82 924,730818 ms** au total,
1 test passé, 0 échec. Le [journal Godot local](carnet-date-followup-20261112/local-godot.log)
confirme les 4 286 contrôles sans erreur. Le wrapper conserve son scénario,
ses seuils et son délai de 180 000 ms ; l'exécution reçue est headless.
Ce passage local ciblé ne remplace pas une nouvelle réception CI.

Le scénario reçu ne comptait pas les signaux vocaux : ces journaux ne
prouvent donc aucun compteur `requested`, `started` ou `_id` nul.
Le commit QA séparé `991019d2` ajoute une mise en sourdine immédiatement
après l'instanciation de l'unique client, avant tout `await`, les compteurs
des deux signaux, ainsi que `_id == 0` initial et final avant destruction.
Ces nouveaux contrôles ne font pas partie du total headless 4 286. Ils
sont désormais reçus dans le passage graphique distinct ci-dessous. Le
pilote Dummy est explicite dans le wrapper de ces deux passages locaux.

## Réception graphique distincte

Le candidat exact `303e8a4698bad50066580f06429fa74f7d8da0dd` termine à
**4 346 contrôles, 0 échec**, sortie 0. Le
[journal TAP graphique](carnet-date-followup-20261112/graphics-tap.log)
mesure **154 819,474056 ms** pour le sous-test et **154 875,506123 ms**
au total. Le [journal Godot graphique](carnet-date-followup-20261112/graphics-godot.log)
confirme `CARNET_SPEECH requested=0 started=0 id=0`. Il s'agit d'une
exécution Linux X11/OpenGL Compatibility sur Mesa llvmpipe, Godot officiel
4.7.2, avec le même budget historique de wrapper **180 000 ms**.
Aucun délai n'a été augmenté pour obtenir ce résultat.

Les captures produites restent dans le répertoire local
`/workspace/work/night-followup-receipts/carnet-graphics`. La boucle de
résolutions couvre seulement **1280 × 800, 1440 × 900 et 1920 × 1080**.
L'inspection visuelle rapportée par l'intégrateur confirme la carte et sa
date visibles à 1920 ; les gabarits compacts des autres tailles ne montrent
pas tous cette carte. Ce reçu ne prouve donc pas une cible de date visible
à chaque taille, ni des captures à 1600 ou 2560. Les contrôles de légende
restent conditionnés à la présence effective de la cible. Les totaux
headless et graphique décrivent deux exécutions distinctes ; leur différence
ne constitue pas un comptage de résolutions supplémentaires.

Deux diagnostics de plateforme restent visibles : `libspeechd.so.2`
absente et impossibilité du pilote de modifier la V-Sync. Ils sont
non fatals dans ce passage (sortie 0, aucun échec du scénario). L'absence de
cette bibliothèque ne prouve pas le silence : celui-ci est établi ici par
les compteurs et l'identifiant vocal nuls. Ce reçu n'est pas une recette
Windows, une qualification de la synthèse vocale système, ni une nouvelle
réception CI.

## Pièces conservées

Seuls les cinq journaux explicitement sélectionnés sont joints. Aucun
profil, sauvegarde ni export complet n'est publié. Empreintes SHA-256 :

| Journal | SHA-256 |
| --- | --- |
| ci-original.log | `1dc1659d408e6b8e01200eb3e1be22284173b78e280255ca254eba05fe94fe9b` |
| local-tap.log | `9692e19a6f0bba93c3141564f2b6f111fda9bff1a314898d492ef18ffb76215b` |
| local-godot.log | `7716ba8dd7d287e164b3a02095561059e73a3374c1773d199f8b7389c1d81424` |
| graphics-tap.log | `48232afb36fcb5462f6d67ac9734076264971cd8e027316193fb4e797f0d2056` |
| graphics-godot.log | `b033e33612a16d54de9680f64bff826befe0f1ed7426ecc99e6bd6c316e46219` |
