# Pilotage de saison — bureau du manager

Fonctionnalité **directement jouable**, greffée au bureau existant sans écran isolé : synthèse des contrats de fin de saison, espoirs, places disponibles chez les professionnels (plafond natif 42) et masse salariale hebdomadaire calculée à partir des joueurs du club.

Les priorités sont classées sans simulation parallèle, en fonction de faits déjà établis : feuille à 23 incomplète, contrats arrivant à échéance, blessures, offres de vente, situation financière, relève et missions de scouting. Chaque bouton mène à une commande ou un écran **déjà existant** (effectif, contrats, ventes, finance, recrutement, formation). Les alertes historiques de `officeDecisions` sont conservées.

**Garantie de non-mutation :** `managerSeasonSnapshot` et `managerSeasonPanel` ne créent aucun rapport, contrat, simulation ou sauvegarde. Les actions de navigation sont explicites ; les finances et contrats ne changent qu'avec les commandes natives. Pas de nouveau champ ou de migration.

Tests : `node tests/manager-season-pilotage.cjs`, CI complète de PR sur HEAD et contrôle post-fusion obligatoire. Le navigateur UI01 doit contrôler le bureau réel sur écran étroit et thème clair/sombre. Aucune prévision financière non sourcée n'est affichée.
