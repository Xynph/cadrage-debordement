# Match natif 0.7 — préparation visuelle au contact

Réception du 8 novembre 2026. Le référentiel `rugby-rules-reference.md` a été lu.
Ce lot de présentation ne change aucune loi, règle de compétition, décision
sportive, position source, identité, statistique, tirage ou sauvegarde.

## Ce qui est reçu

Le porteur mis en avant par l'instantané protège davantage son buste lorsqu'un
adversaire réellement présent se trouve tout près. Cet adversaire incline
légèrement le haut du corps et prépare ses avant-bras. À distance d'anticipation,
les mains restent en garde ; elles approchent le haut du buste seulement lorsque
les racines affichées sont déjà proches. Elles visent au-dessus et à l'extérieur
du ballon : cette garde ne représente pas une prise de possession.

`match_contact.gd` sélectionne uniquement le porteur explicitement mis en avant
du côté en possession et le plus proche adversaire transmis, dans un rayon de
2,6 unités de terrain. Le porteur doit également être à moins de 0,5 unité du
ballon transmis. La force est recalculée sur **les positions effectivement
affichées**, avec une montée progressive et une limite géométrique immédiate à
l'éloignement. Les superpositions schématiques de moins de 0,42 unité restent
sans réaction. Une égalité de distance se départage par l'identifiant stable.

Seules les catégories existantes `carry` et `turnover` sont éligibles. Un
`turnover` ne désigne ici que son nouveau porteur transmis : aucun adversaire
n'est présenté comme une victime ou un plaqueur. Essai, coup de pied, message,
réception, conquête, reprise, pause et ballon absent désactivent cette couche.
La suppression d'un joueur supprime également sa paire de proximité.

Le torse est incliné au maximum de 0,16 radian pour le porteur et 0,22 pour
l'adversaire. Les racines ne sont jamais déplacées. Les clips, les jambes, les
longueurs des membres et les ressources GLB restent ceux du rendu existant.
Chaque pose source est restaurée avant la prochaine évaluation : un même
instantané ne rejoue aucun choc et n'accumule aucune inclinaison. Le ballon est
repositionné après le torse, puis les deux mains du véritable porteur sont
résolues sur sa position affichée.

## Vérifications exécutées

La nouvelle suite a d'abord échoué sur l'absence de préparation du torse et des
bras. Une seconde régression a montré des paumes adverses trop proches du
ballon ; leur cible a été corrigée puis le témoin reçu au vert.

Godot **Windows 4.7.2**, mode headless : les six suites `godot-match-contact07`,
`godot-match-motion`, `godot-match-presentation`, `godot-match-framing`,
`godot-match-silhouettes` et `godot-match-journal` passent sous Node 22.23.4,
sans test ignoré. La nouvelle suite et la génération de ses vrais fragments
passent également sous Node 26.13.0.

Sur la fixture fixe de proximité : inclinaison du porteur 0,1600 radian ; distance
maximale d'une paume du porteur au centre du ballon 0,2153 m ; distance minimale
d'une paume adverse au centre du ballon 0,3657 m ; écart relatif maximal de
longueur des segments de bras et de jambes, comparés au même clip sans couche,
inférieur à 0,000001. Ce sont des mesures locales à la fixture, pas des garanties
sur toutes les animations. Les tests couvrent aussi la séparation réelle pendant
une interpolation, les rafraîchissements répétés, l'immuabilité de la projection,
les catégories exclues, les présences retirées, l'absence de ballon et la pause
du squelette et du ballon.

## Réception graphique et reproduction

Preuves externes : `E:/Cadrage-Debordement/artefacts/native07-contacts/`.
`contact-comparatif-10s.webm` contient 150 images à 15 images/s en 1280×720 :
cinq secondes de fixture de proximité explicitement nommée, puis cinq secondes
de sept vrais instantanés produits par le worker dans une carrière commune
générée, seed 62511. Aucun profil personnel n'a été ouvert. Le comparatif
emploie deux fois le même rendu, avec et sans la seule couche de contact ; les
trajectoires, la caméra, les tenues et l'éclairage sont identiques.

Le rendu Windows sur NVIDIA GeForce RTX 4080 SUPER a été exécuté, les captures
de proximité et la planche de huit temps `contact-sequence.png` inspectées.
L'approche, la garde proche, l'éloignement et les reprises se distinguent sans
chute ni téléportation. Les véritables fragments incluent une superposition
exacte de positions en bord de terrain : elle reste sans faux choc. Ce clip
ne démontre donc pas un plaquage réel et ne constitue pas un benchmark de FPS.

Après chargement de `E:/Cadrage-Debordement/environnement.ps1` :

```powershell
$env:CD_MATCH_CONTACT_PROOF='E:/Cadrage-Debordement/artefacts/contact07-reproduction'
$env:CD_MATCH_CONTACT_PREPARE='1'
node --test tests/godot-match-contact07.cjs
Remove-Item Env:CD_MATCH_CONTACT_PREPARE
$source=Get-Content native/godot/match_view.gd -Raw
$source=$source.Replace('class_name NativeMatchView','').Replace("`t_update_contact(delta)","`t# Contact désactivé pour le comparatif")
$env:CD_MATCH_CONTACT_BASE="$env:CD_MATCH_CONTACT_PROOF/baseline-view.gd"
[IO.File]::WriteAllText($env:CD_MATCH_CONTACT_BASE,$source,[Text.UTF8Encoding]::new($false))
$env:CD_MATCH_CONTACT_REAL="$env:CD_MATCH_CONTACT_PROOF/real-fragments.json"
& $env:CD_GODOT_EXE --path native/godot --script ../../tests/godot-match-contact07-capture.gd --max-fps 30
```

Les sept instantanés de cette recette ont été régénérés et comparés : ils sont
identiques à ceux de la réception. Le harness refuse le mode headless, exige
de vrais fragments et signale les erreurs d'écriture. Un seul run GPU à la fois.

## Limites et données nécessaires ensuite

La scène canonique conserve des placements schématiques et des séquences
atomiques. Elle ne contient ni plaqueur officiel, ni trajectoire physique de
contact, ni phase au sol. Une proximité peut donc produire une préparation
visuelle, jamais une preuve de plaquage, de blessure, de carton ou de causalité
du changement de possession. Les rapprochements insuffisants restent neutres ;
ce lot ne force pas deux joueurs à se rejoindre pour rendre un effet visible.

Un plaquage complet honnête demanderait au moteur des participants et rôles
explicites, un point et une orientation de contact, une chronologie, l'état
debout/sol et la possession/libération du ballon. Aucune chute, récupération au
sol, mêlée spontanée ou simulation physique de ruck/maul n'est ajoutée ici.
Les trois caméras, qualités, interfaces, sons et le guide restent hors périmètre.
