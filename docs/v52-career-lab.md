# V52 — Laboratoire carrière longue, 7 axes

## Périmètre

Branche **isolée** `test/v52-career-balance-lab`, fondée sur le laboratoire V46–V51. Ne pas fusionner directement dans le jeu.

Le banc `tests/v52-career-lab.cjs` exécute 4 intensités de réputation (15 %, 25 %, 40 %, 100 %) × 2 profils (égalité initiale et clubs inégaux) × 30 graines × 15 saisons, soit **3 600 saisons et 50 400 clubs-saisons**. Il rejoue aussi les 30 carrières de chaque combinaison à partir d'un checkpoint de saison 7, pour comparer 240 reprises avec les simulations continues. Les résultats sont archivés en JSON `v52-career-report.json` via GitHub Actions.

## Les sept axes

1. **Réputation dynamique :** comparer la domination sportive à quatre forces de progression, mesurer l'écart final entre clubs et l'évolution annuelle de cet écart.
2. **Finances :** contrôler dettes négatives, déficits, restrictions et investissements, année par année.
3. **IA concurrente :** compter les décisions de recrutement effectivement publiées dans les lignes sportives, sans inventer d'achats réels. Les décisions observées ne garantissent pas la signature d'un joueur.
4. **Entraîneurs :** mesurer les événements `coachChange` par saison et carrière, sans les confondre avec les licenciements du jeu principal.
5. **Hiérarchie sportive :** parts des titres du club dominant, champions différents et diversité des champions par année.
6. **Résistance :** non-mutation des données, 240 reprises après sept saisons, invariants de réputation et de dette, 30 graines fixes.
7. **Rapport :** export automatique des séries de 15 années par combinaison et synthèse comparative avant décision.

## Limites et recommandations

Le moteur V51 ne simule pas les rencontres réelles. Les finances et clubs du laboratoire sont fictifs. La réputation à 25 % reste **un candidat expérimental**, pas un coefficient officiel. Aucune modification du moteur, des sauvegardes ou de l'interface n'est incluse. Faire valider la compatibilité carrière réelle par l'intégrateur avant d'adopter un mécanisme de réputation ou d'économie.

## Commande

`CD_V52_REPORT=v52-career-report.json node tests/v52-career-lab.cjs`.

Si le workflow est vert, le rapport permet de sélectionner un réglage en tenant compte simultanément de la diversité des champions, du risque économique et des entraîneurs, sans ajustements arbitraires.
