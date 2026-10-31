# V60.1 — Questions, promesses et crises médiatiques

Module indépendant `dist/press-events.js` complémentaire de la V60 (PR #64). Cinq questions contextualisées, choix de ton via le module V60, promesses avec objectifs et échéance, bilan tenu/rompu/non vérifiable, crises médiatiques à durée limitée, effets sur confiance des médias/supporters et pression de la direction, briefing et archivage.

La fonction `tick` attend des métriques **réelles à fournir par l'intégrateur** : victoires, points, classement. Si une métrique manque, l'engagement devient `unverified` sans sanction inventée. Les identifiants de saison et semaine sont fictifs et doivent être adaptés au calendrier réel. Les montants et coefficients sont des hypothèses de game design, non calibrées.

**À raccorder :** résultats et objectifs existants, écrans du manager, calendrier des semaines, persistance optionnelle avec migration des anciennes sauvegardes testée sur copies, et absence de double effet avec les indicateurs de la direction. Ne pas remplacer le vrai historique du championnat par ces données.

Tests : 10 scénarios V60.1 et 10 V60, 15 saisons déterministes, reprise JSON. Aucune interface ni sauvegarde officielle modifiée. Ne pas fusionner cette branche empilée avant revue par l'intégrateur.
