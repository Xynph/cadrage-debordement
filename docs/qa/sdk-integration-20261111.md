# Intégration Cloud des petites fenêtres et recettes SDK

Léo a autorisé les fusions et confirmé cet accord permanent le 11 novembre
2026. Claude prend en charge la livraison du ZIP sur PC ; Cloud poursuit ici
l'intégration, le gate officiel et la réception CI du commit réellement fusionné.
Aucun constructeur ou dispatch Windows supplémentaire n'est demandé par Cloud.

## Lot commun

La PR #572 contient déjà la totalité de #566 (`d83a817` est son ancêtre).
Elle porte donc les deux lots en une seule intégration vers main. #566 reste
un brouillon de provenance jusqu'à la réception du lot, puis sera clôturée avec
le lien du commit qui reprend ses changements. Aucune double fusion ni seconde
campagne globale séparée pour le même contenu n'est nécessaire.

Le candidat reçu `ce76163` est raccordé au nouveau main
`9c2ea18c87085ba8241b2527398f3c8482ea63af`, qui contient la PR #558 sur les
packs pendant les rendez-vous. Les trois fichiers de ce nouveau main ne
recouvrent aucun fichier de #566 ou #572 ; le merge local ne présente aucun
conflit. Les sources réservées de #552, #553 et #573 ne sont pas reprises.

Les anciens reçus restent historiques : 625 suites Node sur d83a817,
campagne SDK301 à47/48 puis Carnet ciblé ce761 vert. Le raccord du nouveau main
justifie une CI PR complète sur le nouveau SHA avant fusion, avec les 35 suites
Godot et les mesures géométriques. Une compilation ou un reçu d'une ancienne
tête ne remplace pas cette campagne.

## Verrous de fusion et réception

Avant le gate : dernier main exact vert avec classification, les cinq shards
et Validation CI ; PR ouverte, prête, base main, tête exacte et CI PR complète
verte. L'intégrateur utilise le CLI officiel avec SHA attendu, base et reçu CI
attendus. Aucun bypass, auto-merge ou changement de paramètres GitHub.

Après fusion : le SHA vient du reçu du CLI. La branche main et les CI sont
contrôlées sur ce commit exact ; un dispatch de secours n'est effectué que si
le workflow requis n'a réellement pas été créé. Les résultats et liens finaux
seront ajoutés à la passation #556 et aux descriptions des PR, sans réécrire
les preuves des anciennes têtes.
