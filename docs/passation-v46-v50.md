# Passation V46–V50 — 31 octobre 2026

**Référence :** main `09b92e0` (V40 fusionnée). Les PR #40 à #44 restent **en brouillon** : aucune fusion autorisée depuis ce compte.

## Nouveaux modules et intégration prévue

| PR | Module | Dépendances conseillées | Point de vigilance |
| --- | --- | --- | --- |
| #40 V46 | `dist/club-ai.js` | V44 (coûts de recrutement), V41 (trésorerie) | La décision `scout` est une suggestion : ne pas débiter de fonds ni recruter automatiquement ; équilibrer budgets et effectifs de 14 clubs |
| #41 V47 | `dist/reputation.js` | V42 (objectifs direction), V45 (historique) | Calcul saisonnier, pas hebdomadaire ; réputation fictive 0–100, pas rang officiel |
| #42 V48 | `dist/coach-market.js` | V42 (confiance), V47 (réputation) | Aucune mutation automatique du manager ; tester compatibilité de carrière et licenciement |
| #43 V49 | `dist/facilities.js` | V41 (cash), V43 (formation) | Le niveau 10 est plafonné ; un projet non approuvé ne doit débiter aucune somme |
| #44 V50 | `dist/rugby-world.js` | V45 (registre de carrière) | Dédupliquer les matchs terminés ; ne pas récompenser automatiquement un candidat sans sélection explicite |

## Qualité et limites

- Suites de base : `tests/club-ai.cjs`, `tests/reputation.cjs`, `tests/coach-market.cjs`, `tests/facilities.cjs`, `tests/rugby-world.cjs`.
- Suites pluriannuelles nouvelles : `tests/v46-multiseason.cjs` à `tests/v50-multiseason.cjs`.
- Vérifier les nouveaux SHA et CI de PR avant chaque fusion. Les premiers SHA avaient CI verte pour V46, V48, V49, V50 ; V47 était en cours au contrôle initial de ce cycle. Les nouveaux commits ne sont **pas encore validés** par une CI complète au moment de la rédaction.
- Aucune modification des fichiers partagés `dist/game.js`, `dist/rugby.js`, `dist/style.css`, `dist/economy.js`, `DEVELOPPEMENT.md` ou des modules V41–V45.
- Modules autonomes : aucune intégration UI, de carrière ou de sauvegarde. Pour les rendre jouables, prévoir des actions transactionnelles explicites, garde-fous, migrations et tests d'anciennes sauvegardes.
- Les coefficients sont fictifs : ne pas les présenter comme chiffres officiels du rugby ou budgets réels.

## Ordre d'intégration recommandé

1. Intégrer et stabiliser V41–V45 (autre compte responsable).
2. V47 et V50 : historique saisonnier et réputation, après V45.
3. V49 : finances et centre de formation, après V41/V43.
4. V46 : stratégie IA, après V41/V44 ; simuler 10 saisons sur tous les clubs.
5. V48 : marché des entraîneurs, après V42/V47, prévoir scénarios de licenciement et reprise de club.

**Règle de coordination :** pas de fusion par le compte qui prépare ces modules. L'autre développeur doit examiner les PR #40–#44, leurs tests et leur intégration réelle.
