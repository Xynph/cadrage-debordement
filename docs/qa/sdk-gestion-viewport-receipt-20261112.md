# Gestion Carnet : réception du viewport explicitement configuré

Root a reçu `tests/godot-gestion-carnet.cjs` sur la source exacte `fba9f7f6fa3000225043b323f1ce1703713d590f` : **274 contrôles / 0 échec**, enfant status 0, wrapper vert, aucun `ERROR:` ni `SCRIPT ERROR` dans les journaux. Compteurs de parole requested/started et identifiant `_id` tous à zéro. Cette réception ciblée ne qualifie pas une campagne SDK complète.

Enfant : 45 631 ms ; sous-test TAP : 45 669,93811 ms ; TAP total : 45 725,497737 ms. La borne enfant reste 150 000 ms et la borne parente 180 000 ms. Les assertions et scènes existantes sont conservées, avec un contrôle supplémentaire de la configuration initiale.

## Cause et correction du dernier échec

La trace initiale confirme un viewport headless de 64×64, déjà configuré avec dialogues intégrés. Le test configure maintenant explicitement 1440×900 avant l'instanciation de l'application et conserve explicitement l'intégration des dialogues. L'erreur précédente `Window 0 spawned at invalid position: (-738, -398)` correspondait au centrage d'une fenêtre 1540×860 dans 64×64. Les recettes existantes de contrats en petite fenêtre fournissaient déjà une configuration explicite comparable. Aucun changement produit ni filtrage d'erreur n'a été effectué.

Le nouveau reçu montre 1440×900 dès `startup.viewport-configured` et après réception de la projection ; la matrice termine à 1920×1080. Les trois résolutions existantes restent exécutées. La comparaison confirme identité, libellé de période et montant effectivement affichés : 4 200 € selon le format produit, contre 4 160 € bruts. Le test compare désormais le format public `salary_amount` et `salary_period` sans modifier les formats produit.

## Historique distinct, non requalifié

| Source | Observation | Qualification |
|---|---|---|
| CI `37e085b687b4e9a603085beaa50fecf9d6cace22`, run 43129063385/job 130888398450 | Parent ETIMEDOUT à 180 103 ms sans sortie exploitable | Rouge ; cause du timeout non prouvée par ces logs CI |
| Diagnostic local `c193624b` | `RosterPaginationNext` absent, puis accès invalide à `roster.page` | Erreur déterministe de préparation du test, adaptée à la liste complète défilante ; aucune fausse pagination produit |
| `fe56e8d8` | 273 contrôles / 1 échec de comparaison obsolète **et** erreur native de position du popup | Rouge ; jamais qualifié vert |
| `d8f8a124` | 273 contrôles / 0 échec, parole 0/0/id0, mais `ERROR:` natif de position | Wrapper correctement rouge malgré les assertions fonctionnelles vertes |
| `fba9f7f6` | 274/0, aucun `ERROR:`, wrapper et enfant status 0 | Nouveau reçu vert ciblé |

L'ancien diagnostic local ne démontre pas rétroactivement la cause du timeout CI silencieux. Le présent reçu ne remplace pas les deux journaux rouges ultérieurs.

## Preuves légères

[Extrait vert](receipts/gestion-viewport-20261112/green.log), [comparaison et popup rouges](receipts/gestion-viewport-20261112/red-comparison.log), [assertions vertes mais popup rouge](receipts/gestion-viewport-20261112/red-native-popup.log), [diagnostic pagination](receipts/gestion-viewport-20261112/diagnostic-pagination.log). Les numéros préfixés correspondent aux lignes des logs sources. Un identifiant joueur a été retiré de l'extrait de présentation.

Le [manifeste SHA-256](receipts/gestion-viewport-20261112/receipt.json) rattache ces extraits aux journaux complets, au journal natif vert et aux sources exactes du wrapper, du test et de Dialogs. Source principale : `/workspace/work/night-followup-receipts/gestion-configured-viewport.log` ; journal natif : `/tmp/cd-gestion-carnet-6ryJHI/godot.log`. Aucun profil, export de carrière ou image n'est recopié.

Documentation produite par lecture des reçus centralisés ; aucun nouveau SDK/import exécuté.
