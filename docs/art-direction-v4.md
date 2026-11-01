# V4 — direction artistique des écrans et graphiques métier

Cette version **remplace la première proposition graphique** de la PR #162, jugée insuffisante par Léo. Elle ajoute de vraies compositions et visualisations ; le changement ne se limite plus à la palette et aux bordures. **Branche de revue uniquement, aucune fusion autorisée.**

## Ce que chaque écran apporte

| Vue | Apport visuel et lecture permise | Données utilisées |
| --- | --- | --- |
| Bureau | Affiche du prochain match, disponibilité en anneau, calendrier horizontal, résultats et priorités hiérarchisées ; dossiers annexes repliables | Adversaire et stade natifs, phase réelle, blessés, calendrier, historique de la carrière |
| Effectif | Nuage âge / niveau au poste, disponibilité et répartition d’âge | Professionnels du club et calcul natif de leur note au poste |
| Fiche joueur | Radar d’attributs pertinents pour sa famille de poste et trois points d’appui individuels | Attributs natifs du joueur, évalués sur une copie |
| Préparation | Radar du XV sélectionné et condition détaillée des quinze titulaires | Moyenne simple des attributs du XV et conditions individuelles, sans coefficient sportif ajouté |
| Finances | Courbe de trésorerie projetée, échéances, point par semaine, salaires par famille de poste | `careerBudgetModel()` et `CDFinancePlanning.forecast()`, salaires actuels du club |
| Recrutement | Terrain des quinze postes et priorité native ; nuage prime / salaire pour explorer les coûts publics | `recruitmentNeeds()` et champs publics des candidats, **aucune capacité cachée révélée** |
| Formation | Intervalles niveau actuel / plafond de potentiel, passerelle vers les jeunes pros et minutes jouées | Tous les espoirs présents et jeunes professionnels de la carrière |
| Championnat | Écarts de points entre les clubs, votre club repéré, tableau natif conservé | Classement et points réels de la simulation |

La typographie, la densité et la composition varient selon le sujet. L’affiche sportive utilise la photographie de stade existante ; les vues analytiques donnent la place aux données. Aucun faux portrait, logo officiel inventé ou illustration de tableau de bord générée n’est utilisé pour remplacer le jeu.

## Galerie du jeu exécuté

Les captures proviennent de **Playwright exécutant le vrai jeu**, avec un stockage fictif isolé. Les captures « après matchs » ont été obtenues après **cinq matchs réellement calculés par le moteur**, et non en injectant des résultats destinés à embellir les graphiques.

| Écran | Sombre | Clair |
| --- | --- | --- |
| Bureau | [Capture](art-direction-v4-captures/dashboard-analyste-1440.webp) | [Capture](art-direction-v4-captures/dashboard-tribune-1440.webp) |
| Effectif | [Capture](art-direction-v4-captures/team-analyste-1440.webp) | [Capture](art-direction-v4-captures/team-tribune-1440.webp) |
| Finances | [Capture](art-direction-v4-captures/finance-analyste-1440.webp) | [Capture](art-direction-v4-captures/finance-tribune-1440.webp) |
| Recrutement | [Capture](art-direction-v4-captures/recruitment-analyste-1440.webp) | [Capture](art-direction-v4-captures/recruitment-tribune-1440.webp) |
| Formation | [Capture](art-direction-v4-captures/formation-analyste-1440.webp) | [Capture](art-direction-v4-captures/formation-tribune-1440.webp) |
| Préparation | [Capture](art-direction-v4-captures/tactics-analyste-1440.webp) | [Capture](art-direction-v4-captures/tactics-tribune-1440.webp) |
| Championnat | [Capture](art-direction-v4-captures/league-analyste-1440.webp) | [Capture](art-direction-v4-captures/league-tribune-1440.webp) |

- [Fiche joueur et radar](art-direction-v4-captures/player-analyste-1440.webp)
- [Bureau après cinq matchs natifs](art-direction-v4-captures/dashboard-played-1440.webp)
- [Classement après cinq matchs natifs](art-direction-v4-captures/league-played-1440.webp)
- [Recrutement mobile](art-direction-v4-captures/recruitment-analyste-390.webp), [formation mobile](art-direction-v4-captures/formation-tribune-390.webp), [effectif mobile](art-direction-v4-captures/team-analyste-390.webp)
- Comparatifs de la même carrière entre la première passe et la reprise : [bureau](art-direction-v4-captures/dashboard-comparison.webp), [finances](art-direction-v4-captures/finance-comparison.webp), [recrutement](art-direction-v4-captures/recruitment-comparison.webp).

## Rigueur des graphiques

- Axes, unités, légendes, valeurs en tableau et états vides : aucune série historique inventée pour une nouvelle carrière.
- La courbe financière est une **projection du modèle courant**, pas une prévision réelle : partenaires, salaires, formation et entretien ; billetterie, primes, transferts et aléas exclus. Les montants restent fictifs.
- Le potentiel des espoirs est un plafond de simulation, jamais une progression garantie.
- Les graphiques SVG détaillés peuvent se faire défiler sur mobile pour conserver leur lisibilité ; les tableaux de valeurs restent disponibles. Les points du nuage affichent un texte lisible au survol **et au focus clavier**.
- Le diagnostic du terrain est celui du moteur, sans recalcul de seuils sportifs ; la couleur orange représente la priorité native à partir de 20/100.
- Les demi-finales et la finale reprennent leur libellé natif et l’indication **Terrain neutre**.

## Validation et architecture

`art-direction-v4.js` calcule ses projections sur des copies, puis compose le DOM après le rendu natif. `dist/game.js` reçoit uniquement ce point d’accroche de présentation ; aucune fonction de simulation, règle, transaction ou clé de sauvegarde n’est remplacée. Les actions du recrutement, des fiches, de la formation et du match restent celles des modules natifs.

**Exécuté localement :**

- 143/143 suites Node complètes, puis tests ciblés du module après les corrections de revue ; ancienne sauvegarde, valeurs manquantes/zéro/négatives, échappement, projection financière et champs publics du marché couverts.
- 372 contrôles Chromium de direction artistique : sept routes × deux thèmes × six largeurs 320–1920 px, pureté du rendu, quinze postes, valeurs financières natives, clavier, fiches, navigation, export et cinq matchs natifs. Une huitième composition est contrôlée sur la fiche joueur.
- Parcours V4 initial : 529 contrôles ; navigation native UI01 : 462 ; contraste du bureau : 16 mesures. Les tests de présence et géométrie ont été adaptés à la nouvelle composition, sans retirer les contrôles fonctionnels.
- 11 autres suites navigateur existantes réussies (323 contrôles), incluant anciennes carrières LNR, import/reprise, centres natifs, santé, composition et plans de match.
- Revue indépendante : phase/terrain neutre, focus du nuage et cohérence de légende corrigés. Aucun problème de mutation ou de capacité cachée identifié.

Les rapports JSON de ce lot sont conservés à côté des captures. La CI finale du dernier SHA de la PR fait autorité ; la première tête `f70ac617` avait ses onze workflows réussis, ce qui ne préjuge pas des résultats de cette nouvelle tête.

**Limites :** Chromium Linux seulement, pas de certification Safari/Firefox/Windows ni d’audit complet de lecteur d’écran. Figma reste bloqué par le quota MCP Starter constaté lors de la première passe ; aucune nouvelle maquette Figma achevée n’est revendiquée. Cette livraison est une proposition graphique concrète à examiner, pas une affirmation de qualité « AAA » ni une fusion sur `main`.
