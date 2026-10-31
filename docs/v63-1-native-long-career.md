# V63.1 — Douze saisons du véritable moteur et reprise de carrière

Ce chantier reste indépendant de la PR #65 (IA des effectifs) et des PR #60-68. Il ne modifie aucun script de jeu, fichier partagé ni sauvegarde réelle.

La suite `tests/v63-1-long-career.cjs` charge le **vrai harness du dépôt**, les scripts `game.js`, `rugby.js`, `career-integration.js`, `world-career.js`, `saves.js`, et simule **12 saisons complètes** avec les vrais matchs. Elle vérifie l'activation, les décisions natives des moteurs IA/coach, la comptabilisation unique de l'investissement, la validité des sauvegardes chaque saison, les champions, les classements, les réputations, la dette, la borne d'historique, les salaires/ledger et la taille du JSON.

Après les saisons 4 et 8, une reprise est effectuée dans un nouveau contexte natif à partir de l'état de carrière JSON. **Cette reprise ne garantit pas le même flux aléatoire, car le harness réinitialise sa graine : c'est un test d'intégrité et de continuité, pas de replay bit à bit**. Les archives finales et l'idempotence sont vérifiées après la saison 12. Un cas négatif injecte une réputation impossible et exige son rejet.

Ce banc sert de référence avant/après l'intégration des fonctionnalités hors match. Il ne valide pas encore les PR V58-V61, ni le mode Windows natif. L'intégrateur reste seul responsable des fusions. Rapport de jalons JSON en artefact GitHub Actions. Ne pas présenter les fortunes simulées comme des budgets réels.
