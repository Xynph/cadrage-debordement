# Lot unique V77–V81 — Parcours des jeunes vers le rugby professionnel

Toutes les fonctionnalités sont livrées dans la **même PR #319**, sans fusion par le producteur.

- **V77** : promotion manuelle du centre vers l'effectif professionnel, premier contrat 1–3 saisons, maximum 3 promotions/saison, effectif senior de 42 joueurs, accès à la feuille de 23 native, progression via les minutes de jeu déjà gérées par le moteur.
- **V78** : prêt saisonnier d'un jeune professionnel non sélectionné dans les 23 vers un autre club fictif du championnat, maximum 3 prêts/saison ; mutation des effectifs des deux clubs et retour automatique en fin de saison. Même joueur/identité/progression.
- **V79** : engagement de formation 1–3 saisons pour les Espoirs, coût fictif débité de la trésorerie du club, enregistré séparément du contrat professionnel obligatoire (le champ `contractEnd` reste nul tant que le joueur est Espoir).
- **V80** : stage fictif U20 pour joueurs de 20 ans au plus, au maximum 5 jeunes/saison et un stage par joueur. Gain de niveau borné par le potentiel, aucun match, joueur réel, sélection officielle ou calendrier international inventé.
- **V81** : améliorations jusqu'au niveau 3 des installations et des éducateurs, prix progressifs prélevés sur la trésorerie fictive. Chaque fin de saison, bonus borné par le potentiel des joueurs du centre (jusqu'à 2 points pour les niveaux cumulés).

## Sauvegardes
Champ optionnel `v78to81` versionné avec historiques bornés à 4 saisons. Anciennes sauvegardes sans ce champ valables. Les opérations de prêt/engagement/stage/investissement utilisent une transaction avec retour arrière si `save()` échoue. La promotion V77 possède son propre rollback transactionnel. Les prêts reviennent au groupe à la transition vers la saison suivante avant réinitialisation des plafonds annuels.

## Sécurité et limites
La sélection U20 est un **stage de simulation**, non une sélection officielle authentifiée. Les prêts portent uniquement sur les joueurs professionnels issus du centre, et n'altèrent pas le calendrier officiel. Les mouvements de joueurs utilisent le moteur et les effectifs du jeu, sans changer les fichiers V73–V76, DATA/LNR, MATCH 3D #300, R&D #315, les workflows ni le gate. Les salaires et prix ne sont pas des données financières réelles de clubs.

## Tests
`node tests/v77-espoirs-pro.cjs` et `node tests/v78-v81-espoirs-parcours.cjs`. Couverture prévue : contrats, prêts et retours, plafonds, sauvegardes, rollback, historiques, progression U20, infrastructures, cinq saisons. Tous les 11 workflows de PR, dont Tests JavaScript 7/7, doivent être reçus sur le **dernier HEAD commun**, avant READY puis gate officiel unique d'intégration.
