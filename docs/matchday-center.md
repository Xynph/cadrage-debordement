# MATCHDAY-01 — Briefing d’avant-match dans le vrai jeu

Le nouvel encart se situe en tête du menu **Préparation** déjà jouable et agrège sans mutation de carrière : la feuille à 23 (fonction `sheetErrors`), la fatigue et les blessures réellement enregistrées, l'aptitude par chacun des 15 postes (`slotEligible`) et le rapport adverse de `matchDossier`. Les risques sont affichés par priorité, avec accès explicite à la feuille, la rotation, la couverture et le plan de jeu.

Le joueur voit **ses choix actuels** face à **la recommandation du staff**, ainsi que les deux justifications natives. Appliquer le plan passe uniquement par `adoptDossierPlan`, sans automatisme ; les consignes locales restent prioritaires. Le rapport adverse est une projection approximative sur terrain sec, et ne garantit aucun résultat. Le panneau est indisponible pendant un match en cours ou une saison achevée.

Les données d'affichage ne sont pas sauvegardées, aucun champ de sauvegarde ou moteur modifié. Tests `node tests/matchday-center.cjs`, vraie réception Chromium `tests/matchday-center-browser.py` (1280, 768, 390 et 320 pixels, navigation et sauvegarde), puis gate CI complet sur HEAD et post-fusion sur main. Les vérifications Chromium Linux ne certifient pas le lanceur Windows.
