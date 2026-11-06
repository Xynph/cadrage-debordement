# Économie V2 E3.4 — conseiller consultatif des investissements sportifs

## Objet
Branche de recherche empilée sur E3.3 (PR #355). L'adaptateur `ci/economy-v2-e34-advisor.cjs` reçoit **exclusivement** un snapshot E3.3 contrôlé, sans connexion au moteur chargé. Ce prototype n'est ni une fonction de simulation de résultat sportif ni un ordre de paiement.

## Décisions accessibles, preuves et limites
- **Conserver le statu quo** : zéro débit *supplémentaire immédiat* attribuable à ce choix, sans prétendre prédire les dépenses courantes.
- **Installations** : reprennent le coût du devis instantané natif, le niveau, la disponibilité native, la période `phase` et l'indicateur d'amélioration déjà effectuée cette saison. Un refus du devis natif ou un niveau maximal bloque la suggestion. Seul un événement réellement payé et enregistré en E3.3 figure dans `historicalPaidEvents` ; la date n'est connue qu'à la précision de la saison. La règle d'entrée de progression pour jeunes est décrite mais **aucune progression individuelle n'est garantie**.
- **Formation** : 0, 4 000 ou 12 000 euros fictifs sont des *choix conditionnels de séance*, pas des factures. Le montant n'est débité que si le moteur réalise effectivement la séance. La comparaison se limite à la suffisance de trésorerie **au moment du snapshot** ; disponibilité d'une future séance = inconnue. Les gains sportifs futurs ne sont pas mesurés. Les dépenses déjà observées par E3.3 restent distinctes des intentions.
- **Inconnues** : `futureExpenseSchedule`, `dueLiability`, `futureRevenue`, `futureSportResult`, `facilityEffectMeasured` et `academyEffectMeasured` restent tous `null`. Aucun passif historique, financement, frais ou effet sportif inventé.
- **Jouabilité** : affichage possible d'un choix qui ne crée pas de dette avant d'être exécuté ; pas de pénalité automatique d'un club insolvable. Les compromis sportifs devront être mesurés sur copies appariées avant toute recommandation prédictive.

## Qualification
Tests Node unitaires : parité de la sauvegarde native `state` + `checksum` avant/après le conseil, blocage de champs de dette ou de résultat fictifs, disponibilité immédiate cohérente avec le devis E3.3. Workflow dédié : 3 profils × 2 graines × 15 saisons via le vrai harness E3.3/E3.2/E2.4, 435 tours et trois imports par campagne attendus ; six rapports JSON et parité obligatoire. Les verdicts ne peuvent être affirmés qu'après CI terminale sur HEAD exact ; les chiffres de campagne ne sont pas des progrès sportifs garantis.

## Exclusions
Aucun fichier déjà présent modifié : `dist/`, E1–E3.3, sauvegardes, producteurs, MATCH 3D, DATA/LNR et release gate intacts. Pas de cockpit connecté au jeu, changement de format, READY, `/cd-check`, `/cd-merge` ou fusion. La suite exige mesures sportives appariées et limites du devis après progression temporelle.
