# V51 — Pont de simulation sportive/financière (hors match)

`dist/world-finance.js` appelle le simulateur sportif V51 **une saison à la fois**, puis le module `financial-recovery.annual` pour appliquer des recettes, charges, remboursements et restrictions aux données persistantes **du simulateur uniquement**.

- Trois profils testés sur 14 clubs : aisé, modeste, déficitaire.
- Trésorerie signée, dettes conservées, intérêts annuels, restrictions et suspension théorique d'investissements.
- Le cash négatif est temporairement présenté à la simulation sportive comme zéro, mais la dette et le vrai cash signé restent conservés dans le pont financier.
- Les résultats économiques fictifs issus de `world-simulation.js` sont ignorés pour ne pas compter deux fois des recettes.
- Les effets d'investissement internes au simulateur sportif restent **provisoires** ; l'achat réel d'infrastructure n'est pas encore synchronisé avec le modèle financier. De même, la pénalité sportive est calculée mais non appliquée au classement.
- Les candidats de recrutement restent vides dans le moteur sportif. Aucune signature ni licenciement automatique.
- Aucune écriture dans les sauvegardes, aucun contrôle réglementaire de solvabilité prétendu.

Tester : `node tests/v51-world-finance.cjs`. Ce test est autonome dans la PR #46 et vérifie les parcours de 10 et 15 saisons sans exiger les PR #40 à #44.

**À valider avant intégration :** doubles décisions sur infrastructures, transactions, présentation des finances, impacts sportifs, anciennes sauvegardes, calibrage des coûts et revenus réels du jeu (fictifs, pas chiffres officiels).
