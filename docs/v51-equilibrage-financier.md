# Rapport d'équilibrage V51 — scénarios économiques (31 octobre 2026)

## Périmètre et hypothèses

Le pont `dist/world-finance.js` simule 14 clubs fictifs sur 10 ou 15 saisons, avec graine déterministe 42. Dans le jeu réel, les finances devront être raccordées aux montants et unités des sauvegardes.

| Groupe fictif | Clubs | Trésorerie initiale par club | Recettes annuelles | Charges annuelles |
| --- | ---: | ---: | ---: | ---: |
| Aisé | 4 | 750 000 | 320 000 | 150 000 |
| Modeste | 6 | 120 000 | 185 000 | 180 000 |
| Déficitaire | 4 | −150 000 | 90 000 | 275 000 |

Chaque profil demande 20 000 d'investissements et 5 000 de remboursements par saison ; leur réalisation dépend des restrictions. Le modèle de dette applique 4 % d'intérêts annuels fictifs.

## Invariants couverts par les tests

- Simulations de 10 et 15 saisons déterministes avec les mêmes entrées.
- Tous les 14 clubs conservés, sans modifier les données d'entrée.
- Trésoreries signées et dettes non négatives ; aucune disparition artificielle des déficits.
- Restrictions et reports d'investissements présents dans les trajectoires déficitaires.
- Trajectoires contrastées : les clubs aisés progressent ; les clubs durablement déficitaires conservent un cash négatif.
- Rejet des durées invalides et des dettes négatives.

## Mesures et limites

Ces tableaux présentent les **paramètres de fixtures**, pas des résultats certifiés de simulation : ne pas déclarer les tests verts avant la CI du dernier SHA. La simulation sportive applique encore un modèle fictif de classements non dérivé des matchs. Les infrastructures et les sanctions sportives du pont ne sont pas pleinement transactionnelles. Les paramètres de recettes et charges sont arbitraires et devront être équilibrés par un banc d'essai réel avant la fusion.

**Passation à l'intégrateur :** attendre que V41–V45 / PR #45 et les modules V46–V50 soient stabilisés, valider la cohérence des unités monétaires et de l'investissement, exécuter les tests et les migrations de sauvegardes, puis seulement envisager une intégration jouable.
