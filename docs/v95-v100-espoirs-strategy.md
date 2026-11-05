# V95–V100 — Stratégie du centre de formation

## Six nouvelles décisions pour le manager

- **V95 · Détection régionale :** trois campagnes par saison, six zones fictives, des joueurs persistants issus de clubs amateurs français fictifs. Les candidats sont suivis par observations et essais, puis peuvent accepter ou refuser le projet du centre. Frais de détection : 3 000 € fictifs ; intégration dans l'académie native : 8 000 € fictifs uniquement si le jeune accepte. Maximum cinq recrues et 35 joueurs au centre ; aucun joueur ni donnée réelle ajouté au mod LNR.
- **V96 · Vie collective :** indice de cohésion de 0 à 100, trois réunions payantes par saison, impact des promesses tenues ou non.
- **V97 · Préparation des jeunes :** charge allégée, équilibrée ou intensive. Le bilan annuel améliore au maximum d'un point de note le joueur en charge intensive lorsque son potentiel l'autorise, contre une baisse de condition ; charge allégée et équilibrée servent à récupérer.
- **V98 · Ambitions :** décisions individuelles (accompagner, prêt, passage professionnel, patienter). Les promesses de prêt et de professionnalisation sont vérifiées en fin de saison sur les opérations V77/V78 déjà réellement effectuées, sans mutation automatique.
- **V99 · Identité :** choix entre mouvement, puissance, défense et polyvalence ; orientation managériale persistante et visible dans les bilans, avec jusqu’à trois bonus de développement par an pour les profils compatibles ; la défense peut également améliorer légèrement la cohésion. Cette version ne modifie pas les règles ni le moteur de match.
- **V100 · Réputation :** score fictif sur 100 fondé sur les promotions V77, l'activité Espoirs, la cohésion et les promesses ; classement qualitatif et 15 saisons d'historique.

## V95 renforcée — filière d'origine et détection persistante

Les 16 clubs fictifs (10 français, 6 étrangers) constituent un vivier initial de 32 jeunes, renouvelé par générations. Chaque joueur dispose d'un club formateur, d'un pays de fédération, d'une région, d'un âge, de préférences scolaires et familiales, d'une ambition, d'un potentiel non immédiatement visible et d'un historique.

Un réseau permanent de trois recruteurs (Nord, Sud et international) fournit des rapports de fiabilité variable selon sa spécialité ; les observations successives affinent l'information. Une campagne dans une région ouvre l'accès aux premiers rapports. Le manager peut ensuite observer de nouveau (500 € fictifs), inviter à un essai (1 000 €), bâtir un partenariat avec le club (2 000 €), puis proposer un projet (8 000 € uniquement si accepté). **L'accord n'est pas automatique** : un score de projet sportif/scolarité/proximité/temps de jeu est comparé à une décision déterministe ; l'intérêt d'autres centres réduit l'attractivité et certains joueurs les rejoignent entre saisons. Les refus peuvent être réévalués la saison suivante.

**Mobilité internationale :** le simulateur interdit l'intégration de jeunes de moins de 18 ans en provenance d'une autre fédération et exige pour les majeurs un statut de clearance simulé explicitement enregistré. Il ne prétend pas avoir contrôlé une clearance réelle, un visa, une autorisation parentale, une licence ou une qualification. La règle World Rugby 4.6 traite les autorisations de mouvement inter-fédérations ; la réglementation nationale et les règles particulières liées aux mineurs continuent de s'appliquer.

**Indemnités de formation :** le modèle conserve les clubs d'origine des recrues et attribue un crédit **descriptif, non monétaire** au club formateur durant au maximum dix saisons suivant la première promotion professionnelle connue, sans inventer de montant légal ou débit immédiat au recrutement. La réforme RIF française rémunère les clubs formateurs selon le parcours et la rémunération du joueur ; les barèmes ne sont pas reproduits ici. Les frais de gestion fictifs utilisés par le gameplay ne représentent ni une indemnité RIF ni une obligation légale.

Références contrôlées le 05/11/2026 :
- FFR, Avis hebdomadaire n°1172 du 06/05/2026, Règlements généraux saison 2026–2027 : https://amp.www.ffr.fr/actualites/avis-hebdomadaire-n1172
- FFR, RIF : https://ffrugby.zendesk.com/hc/fr/articles/360018456679-RIF-Visualiser-les-indemnit%C3%A9s-de-formation-vers%C3%A9es-par-la-LNR
- Convention FFR–LNR 2022–2027 : https://www.lnr.fr/actualite/signature-de-la-convention-2022-2027
- World Rugby Regulation 4 : https://www.world.rugby/organisation/governance/regulations/reg-4

## Contrat technique

API autonome `CDEspoirsStrategyV95V100` dans `dist/espoirs-strategy-v95-v100.js`. État sauvegardable et facultatif `s.v95to100` version 1 ; les sauvegardes antérieures restent valides grâce à `ensure`. Validation stricte et bornes sur campagnes, candidats, ambitions, effectifs, archive et cohésion. Toutes les actions actives utilisent une transaction avec rollback sur échec du callback de sauvegarde. Les recrues sont dérivées du schéma d'un joueur Espoir natif, conservant la structure attendue par le moteur. Les sauvegardes et le jeu ne sont pas modifiés au niveau central.

**Limites claires :** pas d'IA de recrutement adverse réelle, pas de marché caché, pas de blessure automatique, pas de différenciation réelle des régions ou des styles sportifs tant que les modèles centraux ne l'exposent pas. Le score de réputation est une simulation du manager, pas un classement national officiel.

## Tests

`node tests/v95-v100-espoirs-strategy.cjs` couvre les rollbacks de scouting et recrutement, la cohésion, le suivi de la charge, les promesses, les six décisions, les anciennes sauvegardes JSON et 17 saisons. Tests CI complète et Chromium à réceptionner sur le HEAD publié ; les résultats d'anciens HEAD ne comptent pas.

## Raccordement bloqué par réservation

`dist/index.html` est toujours réservé au producteur V82–V85 dans #73 ; il n'est donc **pas modifié ici**. Une fois V82–V94 raccordés et la réservation libérée, inclure ce module après V94, puis exécuter tests de panneau Chromium PC, exports/imports legacy et carrières longues avec les wrappers complets. **Aucun passage READY ni fusion de cette PR DRAFT avant ce raccordement.** Aucune intervention MATCH 3D #300, R&D #315, DATA/LNR, calendrier officiel, CI, gate ou moteur match.
