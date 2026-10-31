# V52 — Bilan managérial et recommandations expérimentales

## Exécution vérifiée

Sur le commit `b6977c933aa9447c025e6f34cc4bba6bb394788`, les quatre workflows ont réussi. Le laboratoire [#41152045891](https://github.com/Xynph/cadrage-debordement/actions/runs/41152045891) a exécuté 8 scénarios × 30 graines × 15 saisons, soit **3 600 saisons** et **50 400 clubs-saisons**, avec **240 reprises à la saison 7** comparées aux parcours continus. Le rapport est un échantillonnage de clubs fictifs, pas un test de carrières jouables.

| Force | Profil | Titres du dominant | Champions différents | Écart de réputation final | Déficits | Restrictions | Changements d'entraîneurs |
|---|---|---:|---:|---:|---:|---:|---:|
| 15 % | égal | 50,67 % | 5,03 | 21,25 | 0 % | 2,00 % | 161 |
| 25 % | égal | 61,11 % | 3,90 | 36,51 | 0,02 % | 2,63 % | 194 |
| 40 % | égal | 70,67 % | 3,13 | 54,44 | 0,68 % | 4,22 % | 204 |
| 100 % | égal | 86,44 % | 2,13 | 91,47 | 8,40 % | 12,84 % | 230 |
| 15 % | inégal | 58,44 % | 3,97 | 52,69 | 3,79 % | 9,94 % | 211 |
| 25 % | inégal | 66,00 % | 3,27 | 62,17 | 5,46 % | 11,79 % | 215 |
| 40 % | inégal | 70,89 % | 2,97 | 72,83 | 7,63 % | 13,83 % | 219 |
| 100 % | inégal | 86,89 % | 2,07 | 92,97 | 11,32 % | 17,76 % | 234 |

## Enseignements sur les sept axes

- Réputation : 25 % réduit le titre dominant de 25,33 points (égaux) et 20,89 points (inégaux) face à 100 %. Le réglage 15 % donne plus d'alternance mais réduit plus fortement la différenciation.
- Finances : la réduction de domination s'accompagne de moins de restrictions et de déficits dans ce modèle fictif. Impossible d'en déduire l'économie du rugby réel.
- IA concurrente : 6 300 décisions de recrutement sont produites **par scénario** (30 × 15 × 14), mais le banc ne prouve ni transfert ni signature de contrat.
- Entraîneurs : 215 événements de changement avec profil inégal et 25 %, contre 234 à 100 %. Ce ne sont pas nécessairement des licenciements effectifs dans le jeu.
- Hiérarchie : 3,27 champions distincts en moyenne à 25 % contre 2,07 à 100 % (profil inégal).
- Résistance : reprise de 240 simulations, absence de mutation de la fixture et contrôles de finances/reputation réussis dans le run cité.
- Rapport : résultat JSON archivé par GitHub Actions, avec séries annuelles et récapitulatifs par profil/réglage.

## Suite recommandée

**Candidat 25 % pour un prototype configurable et réversible**, **15 % comme alternative** en fonction de l'alternance recherchée. Ne pas modifier le moteur de production avant test dans une vraie carrière avec matchs complets. Priorités : mesurer les signatures effectives de recrutement, distinguer changements d'entraîneurs et licenciements, fixer des critères de réalisme sportifs avec le développeur intégrateur, puis vérifier l'effet sur sauvegardes.

## Vérification ajoutée après le run

Le commit `55e1ebe` renforce les invariants de paiement et événements d'infrastructures et classe les décisions IA. **Ces nouveaux contrôles nécessitent une nouvelle CI verte** : ne pas les présenter comme exécutés tant que son verdict n'est pas confirmé.

Aucune fusion, aucun changement dans le moteur officiel ni dans les sauvegardes.
