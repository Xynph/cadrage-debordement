# V51 — Modèle de crise et redressement financier

Module isolé `dist/financial-recovery.js` : trésorerie **signée**, dette explicite, intérêts fictifs 4 %, suspension d'investissement en crise, réduction indicative des coûts opérationnels (5 % en vigilance, 12 % en redressement), enveloppe salariale limitée et pénalité sportive fictive de planification. Aucun licenciement ni retrait de points automatique.

Les fonctions `annual` et `recoveryPlan` sont pures. Le moteur existant `world-simulation.js` reste inchangé, afin de ne pas affecter les scénarios historiques tant que le modèle économique n'est pas validé avec les V41–V50.

Les déficits **ne sont jamais plafonnés à zéro** dans ce module : un club peut rester durablement déficitaire. La dette et les intérêts sont des abstractions de jeu et ne correspondent à aucune règle LNR.

Test autonome : `node tests/v51-financial-recovery.cjs`. Les essais de 10 et 15 saisons sont déterministes et ne touchent ni les sauvegardes ni l'interface.

**Intégration ultérieure :** connecter le modèle à une carrière, calibrer l'échelle monétaire et rendre les décisions du manager explicites ; tests de migration requis.
