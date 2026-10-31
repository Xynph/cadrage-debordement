# V60.2 — Passation de consolidation du calendrier médiatique

**Contexte** : PR #64 (V60) puis #66 (V60.1), branches non fusionnées. Le chantier V59 est en PR #65 sur une autre branche. Aucun code partagé ou sauvegarde officielle modifié.

## Défaut de conception confirmé à la lecture du code
`press-events.tick` ne garde pas la trace des semaines déjà traitées. Un second appel sur la même semaine peut répéter le retrait de confiance et la pression d'une crise active. Par ailleurs, `lastWeek` est global et ne prend pas en compte l'année : un retour à la semaine 1 en saison suivante serait refusé.

## Correction indépendante
Le nouveau module `dist/press-calendar.js` enveloppe les appels sans changer V60 ni V60.1. Il mémorise les paires saison/semaine déjà traitées, protège les appels répétés et ordonne les dates. Il convertit le numéro de semaine local en index global de laboratoire (saison × 1000 + semaine), de façon à distinguer les saisons. L'intégrateur devra remplacer cette convention par le calendrier réel.

## Couverture
- Tests V60 et V60.1 rejoués.
- 7 tests complémentaires d'audit : promesses concurrentes, deux crises en même temps, sanction de promesse unique, résolution, absence de mesures, JSON, quinze saisons.
- 8 tests spécifiques au calendrier : idempotence, deux crises, deux promesses, passage de saison, refus du retour en arrière, résolution, quinze saisons et corruption.
- Rapport JSON en artefact de CI.

## Points restant à corriger avant intégration
Le module est un **adaptateur de simulation**, pas un service du vrai jeu. Les règles de report d'une crise entre saisons, les promesses dont la date d'échéance franchit l'inter-saison, le comportement du calendrier officiel, les sources de résultats et les migrations de sauvegarde exigent encore un travail de raccordement. Il faut éviter tout double impact sur les indicateurs de direction déjà présents. Ne pas fusionner directement les PR empilées, demander une revue de l'intégrateur.
