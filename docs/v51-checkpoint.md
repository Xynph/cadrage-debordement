# V51 — Checkpoints et reprise déterministe

Le pont `CDWorldFinance.simulate` accepte désormais un `checkpoint` facultatif de version 1 : l'état final, les pénalités différées, les événements et l'historique sont copiés. Pour une reprise, fournir les mêmes clubs initiaux, la même graine et les mêmes adaptateurs/profils, avec une durée totale supérieure au nombre de saisons déjà simulées.

Le test `node tests/v51-checkpoint.cjs` compare une simulation de 15 saisons d'un seul tenant à une simulation de 5 saisons reprise jusqu'à la saison 15. Il vérifie aussi le rejet de versions, graines, longueurs d'historique et dettes invalides.

**Important :** il s'agit d'un mécanisme de reprise d'un **simulateur de laboratoire**, et non de la sauvegarde officielle d'une carrière. Il ne doit pas être intégré au stockage utilisateur tant que les validations de schéma/migration et la prévention des données altérées ne sont pas renforcées. Les adaptateurs et profils restent externes au checkpoint.
