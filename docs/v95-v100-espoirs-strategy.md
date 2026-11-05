# V95–V100 — Stratégie du centre de formation

## Six nouvelles décisions pour le manager

- **V95 · Détection régionale :** trois campagnes par saison, six zones fictives, trois candidats par campagne. Chaque profil se distingue par son poste, son niveau, son potentiel et sa région. Frais de détection : 3 000 € fictifs ; recrutement dans l'académie native : 8 000 € fictifs. Maximum cinq recrues et 35 joueurs au centre ; aucun joueur ni donnée réelle ajouté au mod LNR.
- **V96 · Vie collective :** indice de cohésion de 0 à 100, trois réunions payantes par saison, impact des promesses tenues ou non.
- **V97 · Préparation des jeunes :** charge allégée, équilibrée ou intensive. Le bilan annuel améliore au maximum d'un point de note le joueur en charge intensive lorsque son potentiel l'autorise, contre une baisse de condition ; charge allégée et équilibrée servent à récupérer.
- **V98 · Ambitions :** décisions individuelles (accompagner, prêt, passage professionnel, patienter). Les promesses de prêt et de professionnalisation sont vérifiées en fin de saison sur les opérations V77/V78 déjà réellement effectuées, sans mutation automatique.
- **V99 · Identité :** choix entre mouvement, puissance, défense et polyvalence ; orientation managériale persistante et visible dans les bilans. Cette version ne modifie pas les règles ni le moteur de match.
- **V100 · Réputation :** score fictif sur 100 fondé sur les promotions V77, l'activité Espoirs, la cohésion et les promesses ; classement qualitatif et 15 saisons d'historique.

## Contrat technique

API autonome `CDEspoirsStrategyV95V100` dans `dist/espoirs-strategy-v95-v100.js`. État sauvegardable et facultatif `s.v95to100` version 1 ; les sauvegardes antérieures restent valides grâce à `ensure`. Validation stricte et bornes sur campagnes, candidats, ambitions, effectifs, archive et cohésion. Toutes les actions actives utilisent une transaction avec rollback sur échec du callback de sauvegarde. Les recrues sont dérivées du schéma d'un joueur Espoir natif, conservant la structure attendue par le moteur. Les sauvegardes et le jeu ne sont pas modifiés au niveau central.

**Limites claires :** pas d'IA de recrutement adverse réelle, pas de marché caché, pas de blessure automatique, pas de différenciation réelle des régions ou des styles sportifs tant que les modèles centraux ne l'exposent pas. Le score de réputation est une simulation du manager, pas un classement national officiel.

## Tests

`node tests/v95-v100-espoirs-strategy.cjs` couvre les rollbacks de scouting et recrutement, la cohésion, le suivi de la charge, les promesses, les six décisions, les anciennes sauvegardes JSON et 17 saisons. Tests CI complète et Chromium à réceptionner sur le HEAD publié ; les résultats d'anciens HEAD ne comptent pas.

## Raccordement bloqué par réservation

`dist/index.html` est toujours réservé au producteur V82–V85 dans #73 ; il n'est donc **pas modifié ici**. Une fois V82–V94 raccordés et la réservation libérée, inclure ce module après V94, puis exécuter tests de panneau Chromium PC, exports/imports legacy et carrières longues avec les wrappers complets. **Aucun passage READY ni fusion de cette PR DRAFT avant ce raccordement.** Aucune intervention MATCH 3D #300, R&D #315, DATA/LNR, calendrier officiel, CI, gate ou moteur match.
