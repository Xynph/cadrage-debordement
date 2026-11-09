# Prévision des engagements salariaux selon l'édition

## Problème et correction

La carrière Monde utilise46semaines de gestion par saison, mais `futureWages()` utilisait le calendrier historique de29semaines dès que `S.franceMode` était absent. Sur une vraie création MondeS1W0, club0, la prévision affichait22 084 660€ au lieu de35 030 840€ avec les mêmes salaires et contrats. Ce défaut concerne une estimation affichée, pas les salaires réellement débités. Il n'explique pas l'accumulation de trésorerie observée dans l'audit de dix saisons.

`wageForecastWeeks()` lit désormais `CDWorldCareer.sizing(S).rounds` pour l'édition mondiale active. `futureWages()` conserve le calcul des semaines encore dues cette saison et des années suivantes du contrat. Pour France, le calendrier reste34semaines et emploie `S.franceMode.week` ; pour la carrière historique il reste29semaines et emploie `S.round`. Aucune durée contractuelle, prime, salaire ou recette n'est modifié.

Les deux appelants sont `financeOriginal()` dans `dist/game.js` et `contractsPanel()` dans `dist/economy.js`. Ils utilisent cette valeur uniquement pour l'affichage : aucune sélection, négociation, éligibilité au recrutement ou décision IA ne dépend de `futureWages()`. Le montant d'une saison complète et les deux libellés adjacents emploient le même calendrier, afin que46ou34semaines ne soient pas présentées comme29journées. Les autres simulateurs financiers et leurs scénarios ne sont pas réécrits dans ce lot.

## Validation

Le test `tests/world-wage-forecast.cjs` initialise les cinq éditions Monde via leur vrai bootstrap et leurs catalogues anonymisés. Une petite fixture de trois contrats vaut1000€/semaine sur la saison courante,1500€ sur deux saisons et2000€ sur trois. Son engagement doit être460000€ àW0,356500€ àW23 et253000€ àW46. Ce témoin échoue sur les sources `c07ce6a6` (290000€ àW0), puis réussit avec le correctif. La fixture arithmétique réduite n'est pas présentée comme une carrière exportable.

Les cas de compatibilité conservent les valeurs historiques29semaines et France34semaines, y compris lorsque la journée élite et la semaine France diffèrent. Les cas de fin de saison ne produisent pas de nombre négatif de semaines. Deux vraies carrières complètes (Monde v1 et Monde+Champ v5) conservent intégralement leur état, stockage, curseur RNG et export après consultation ; l'export reste accepté par le validateur courant. Aucun format ni migration de sauvegarde n'est ajouté.

Les rendus HTML réels de Finances et Contrats sont exécutés pour la carrière historique, France, Monde et Monde+Champ : le calendrier et les montants affichés doivent correspondre, sans test fondé uniquement sur une expression régulière du code source.

Commande de réception ciblée :

```bash
node --test tests/world-wage-forecast.cjs tests/france-finance.cjs tests/v31-finance-forecasts.cjs tests/finance-planning.cjs
```

Node22.23.4, Linux : **7 tests réussis, zéro échec, zéro ignoré**, environ7,4secondes. Ce total comprend les quatre nouveaux cas et les trois suites existantes ; les scénarios internes ne sont pas additionnés comme des tests indépendants. La suite historique de prévisions conserve son témoin sur quatre saisons contre les vrais débits de `financeWeek`.

Il s'agit d'une correction du calcul et du HTML de qualification. Aucun parcours Chromium ou Windows n'est revendiqué pour ce lot. Les documents de référence restent l'édition de carrière et son nombre de semaines de gestion, sans nouveau coefficient économique ni changement de règlement sportif.
