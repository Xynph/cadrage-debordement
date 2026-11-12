# Retour natif Linux avec scroll non nul — 12 novembre 2026

Source produit exacte `76077ed3f2af0ff029c8a413fc26451a25ac647f` : **59 contrôles,
zéro échec, sortie 0 observée par root, 67,632 s**. Le temps comprend les attentes
des actions OS externes ; il ne constitue pas un benchmark comparable au
précédent 47/0. Les cinq hashes produit sont vérifiés contre ce SHA et runtime
`/workspace/work/night-followup/native/godot`. Le SHA de rédaction 186f4151 n’est
pas une nouvelle source d’exécution. Aucun produit 7607 n’a été modifié.

## Checkpoint public existant et identité du score

Le profil jetable est une copie exacte du checkpoint de vraie mission
Common 0 déjà reçu : source SHA256
`016760df473facd2b7e389fb8454d8e2276489f1c0bbd4dc1d1ac7d4b27fffaa`.
Il conserve deux matchs réellement joués ; aucun événement/fixtureId/score
n’est ajouté pour allonger la page. La cible est `s1-elite-league-1-0`, pair 12/0,
archive domicile/extérieur **20–10**. Toulouse est à l’extérieur : sa vue
Analyse affiche donc **10–20**, puis la fiche montre 20–10 dans l’ordre des clubs.
Cette différence de perspective n’est pas une mauvaise entité ni un score
réécrit. L’autre match conservé est 18–13 contre Vannes.

La préparation initiale a inspecté des métadonnées de profils privés existants ;
les profils de stratégies retrouvés n’avaient pas d’ID réutilisable. Le candidat
à deux matchs suffisait : **aucune nouvelle préparation Node 8–12 matchs et
aucune exécution du repli Common 0 scroll 0 n’ont été nécessaires**. Les trois
fichiers originaux sauvegarde/guide sont inchangés avant/après et seulement
hashés ; aucun profil, guide privé ou export complet n’est publié.

## Vrai scroll UI, puis touches OS externes

Le probe lit max-page du ScrollBar réel : limite 45 px. Le réglage de lecture UI
avant baseline demande min(90,limite), donc atteint 45 px avec le score focalisé
entièrement visible. Ce n’est pas une preuve de molette OS : le déplacement
initial du scroll est une préparation UI explicite.

Root inspecte X11, observe PointerRoot 0x1 et le seul Godot 0x600003 avec son titre,
puis focalise explicitement ce Godot. Return et Alt_L+Left sont ensuite envoyés
par XTest au focus courant. Le helper ne choisit pas silencieusement une autre
fenêtre. Le journal garde inspection, focus initial et les deux actions ; les
témoins Godot root/modal/scene-input observent keycodes et modificateurs.
Le probe n’injecte pas d’input et n’appelle ni pressed.emit, ni _travel, ni
commande métier. Aucune nouvelle tentative Cua et aucun réglage sandbox changé.
Cette preuve est Linux/X11 uniquement, pas Windows ni une réception Cua.

Après Return→fiche exacte→Alt+Left, le rapport brut sérialise baseline==after
pour tous les champs : scroll 45/limite 45, même instance/focus du score,
profil/model_sha, seed 735614731, horloge 1794440632004, bridge_next_id 1,
requested 0 / started 0 / id 0. Les hashes source originaux sont aussi revérifiés par
le probe à la clôture. Audio Dummy et mute précoce, sans commande de consultation.

## Trois PNG originaux, état égal mais pixels différents

- [Source prête, scroll 45](images/ready-2560.png).
- [Fixture exacte, score 20–10](images/modal-2560.png).
- [Retour au même score et scroll 45](images/returned-2560.png).

Trois captures natives 2560×1440 inspectées, sans retouche. **Ready et returned
ont des hashes différents** : la bulle textuelle Gabi présente avant est
transitoire et disparaît. Aucun pixel identique ni égalité des captures n’est
affirmé. L’état métier, le focus, l’instance et le scroll restent strictement
identiques dans le rapport. Les compteurs de parole sont réellement sérialisés
à 0/0/id 0 malgré cette animation de présentation.

## Préparation agent et exécution root

Les scripts publiés sont les fichiers exacts exécutés, avec hashes dans la
provenance brute. Sa note Prepared only concernait la préparation functional_qa
avant le lancement ; root a ensuite exécuté et reçu le cas. selection.json
est actualisé avec cette réception ; selection-preparation.json conserve la
sélection antérieure. Le repli non exécuté, mentionné dans les scripts et la
provenance, n’est pas annoncé reçu. Aucun statut brut de report.json n’est modifié.

Rapport, state, logs et provenance sont copiés octet pour octet. Le manifeste
consigne origines, tailles, hashes et dimensions. Vérification :
`sha256sum --check SHA256SUMS`. Ce reçu complète le
[précédent probe scroll 0 sur 37e085b6](../night-native-os-20261112/README.md),
sans fusion de leurs SHA/comptages. Aucun nouveau SDK, import, input ou capture
n’est exécuté pour cette publication documentaire.
