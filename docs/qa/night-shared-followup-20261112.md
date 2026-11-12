# Suivi du candidat commun — date et recette SDK

Ce lot est empilé sur le candidat figé `37e085b687b4e9a603085beaa50fecf9d6cace22`. Il agrandit la cible de consultation de la date du prochain match selon la hauteur réelle de son texte, sans changer la destination, la police ou les commandes du jeu. Le contrôle géométrique initial est conservé ; le libellé accessible est également vérifié.

Les autres changements concernent la recette : sélection explicite de l’onglet des employés avant une prolongation ; remplacement des anciennes assertions de pagination par la liste complète et son défilement ; salaire de comparaison vérifié selon la période et l’arrondi affichés ; viewport Gestion initialisé en 1440×900 avec dialogues intégrés. Les matrices 1280×800, 1440×900 et 1920×1080 restent présentes. Aucun message `ERROR:` n’est filtré.

Les clients de lecture sont désormais mutés et leurs signaux observés avant la première attente. Les contrôles finaux incluent les demandes, démarrages et l’identifiant vocal nul. L’identifiant n’est pas remis à zéro par mute/stop : il couvre aussi une éventuelle émission antérieure au branchement. Les limites des anciens reçus restent explicites dans l’[audit](sdk-new-readers-silence-audit-20261112.md).

## Reçus locaux distincts

| Source exacte | Parcours | Résultat | Preuve |
| --- | --- | --- | --- |
| Pilotes `e373c8f3`, produit `37e085b6` | Recrutement Staff puis client Staff voisin | 104/0 ; 186/0 | [Staff](staff-hire-directory-followup-20261112.md) |
| `2d366010` | Carnet headless, cible de date corrigée | 4 286/0 | [Carnet](carnet-date-followup-20261112.md) |
| `303e8a46` | Carnet graphique et silence sur toute la durée | 4 346/0 ; parole 0/0, identifiant 0 | [Reçu](carnet-date-followup-20261112.md), [trois captures et revue](night-carnet-visual-20261112.md) |
| `4dde9914` | Finances, Entraînement, Analyse/Club, Fiche joueur, chaîne des lecteurs | 38/0 ; 55/0 ; 56/0 ; 40/0 ; 115/0 | [Cinq lecteurs](sdk-silent-readers-receipt-20261112.md) |
| `d8f8a124` | Entités, Navigation, Vestiaire, Analyse/Club/Bureau public graphique, gardes graphiques | 51/0 ; 156/0 ; 61/0 ; 72/0 ; 103/0 | [Réception core](sdk-silent-core-receipt-20261112.md) |
| `fba9f7f6` | Gestion, viewport configuré et silence strict | 274/0 ; enfant 45,631 s ; TAP 45,725 s | [Gestion](sdk-gestion-viewport-receipt-20261112.md) |

Ces résultats ne constituent pas une campagne globale du nouveau HEAD. La campagne complète initiale sur `37e085b6` reste à **71 réussites / 75 exécutions**. Sa reprise ciblée guards verte sur le même SHA strict ne remplace pas ce bilan. Les preuves initiales sont conservées séparément dans le brouillon [#581](https://github.com/Xynph/cadrage-debordement/pull/581).

La tentative Gestion sur `d8f8a124` reste rouge : 273 assertions passent, mais le wrapper refuse correctement la position invalide d’une fenêtre. Le reçu ultérieur `fba9f7f6` est distinct. Les erreurs antérieures de pagination et de présentation du salaire sont conservées ; le timeout CI initial ne fournissait pas de trace permettant de lui attribuer une cause unique.

## Validation commune et passation

La syntaxe des cinq CJS modifiés et les six contrats du registre ont été reçus localement sur `fba9f7f6`. Le registre ne change pas : 75 exécutions, 56 suites distinctes, 74 couples suite/cas, avec le doublon historique Guide/layout-native conservé. Une nouvelle campagne SDK complète et une validation JavaScript complète doivent recevoir la tête publiée du suivi ; leurs verdicts et SHA seront consignés séparément. Aucun ancien vert n’est transféré implicitement à cette tête.

Aucun moteur, donnée, économie, calendrier, workflow, réglage GitHub, `project.godot`, asset ou conversion Mixamo n’est changé par ce suivi. Aucun délai existant n’est relevé. Les images sont des captures réelles ; les projections synthétiques sont signalées. Les trois résolutions photographiées ne sont pas les cinq passages du contrôle de cible. Aucun clic ni rectangle invisible n’est déduit d’un PNG. Aucune recette Windows ou livraison ZIP n’est revendiquée.

Aucune fusion Cloud dans main avant le 12 novembre à 09 h Europe/Paris. Après cette heure, réconcilier #572, #576, le suivi et les preuves avec le main effectivement intégré, sans doubler le correctif Art de #577 ; recevoir le cumul et son gate avant fusion. Les PR familiales restent ouvertes jusqu’à intégration et réception réelles. Claude conserve le ZIP et la recette PC.
