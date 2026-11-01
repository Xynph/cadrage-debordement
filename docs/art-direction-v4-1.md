# V4.1 — audit et finition accessibilité des huit compositions

## Base et périmètre

Issue de `main` au commit `f72e2c47fd05cacdd3f0e8cf0b3e8899f3a59f20`, après la fusion et validation de la V4 Premium dans la PR #162. Cette V4.1 est une **branche de revue** : aucune fusion automatique.

La revue statique couvre le bureau, l’effectif, la fiche joueur, la préparation du XV, les finances, le recrutement, la formation et le championnat. Les compositions et graphiques métier, le stade, le ballon légèrement boueux, les couleurs forêt et cuivre sont conservés. Les calculs et valeurs des graphiques restent ceux du moteur natif.

## Problèmes précis et corrections

- **Défilement horizontal au clavier** : les zones SVG défilantes des finances, nuages de points (effectif et recrutement) et intervalles de potentiel (formation) étaient des `div` non focusables. Elles portent désormais `tabindex="0"`, `role="region"` et un nom accessible ; la bordure de focus est visible. L’effet est particulièrement utile en largeur mobile, lorsque le SVG conserve sa largeur de lecture.
- **Sémantique des points** : le nuage exposait une image SVG globale (`role="img"`) contenant des cercles focusables. Il est désormais un groupe SVG nommé (`role="group"`) pour ne pas masquer ses enfants interactifs aux technologies d’assistance. Chaque point garde son nom accessible, la lecture au focus et le tableau de valeurs.
- **Contraste forcé** : indicateurs de focus, grilles et tracés essentiels reçoivent une prise en charge `forced-colors: active`, sans remplacer les couleurs du thème normal.

## Lot métier élargi — quatre écrans enrichis

Cette version n'est plus limitée à des retouches de focus. Elle introduit **quatre compositions/lectures supplémentaires** fondées strictement sur les mêmes données simulées déjà visibles dans le jeu :

1. **Finances :** échelle verticale de la courbe adaptée à la variation réellement observée dans la projection, au lieu d'imposer systématiquement le zéro sur l'axe (ce qui écrasait les variations lorsque la trésorerie de départ était élevée). Les nouveaux repères affichent la variation entre première et dernière semaine, le point bas et le point haut, avec leurs échéances natives. Aucune nouvelle prévision ni donnée historique.
2. **Effectif :** lecture de la composition du groupe par unités sportives — avants, charnière, trois-quarts — obtenue à partir des familles de postes déjà présentes. Le nuage âge/niveau et les données de disponibilité sont conservés.
3. **Recrutement :** les trois besoins prioritaires, triés par score de diagnostic natif décroissant et numéro de poste en cas d'égalité, remplacent la mise en avant peu informative du premier élément du tableau. Les motifs du diagnostic original sont affichés ; aucun rating de joueur inconnu n'est dévoilé.
4. **Championnat :** rang et retard du club sur le leader, plus un tableau d'écarts de points pour toutes les équipes. L'ordre et les points viennent du classement de la carrière ; en début de saison, aucune différence fictive n'est introduite.

Les autres vues (bureau, fiche joueur, préparation et formation) conservent leurs compositions V4 existantes, la correction d'accessibilité et leurs commandes natives. Le travail n'est donc pas une refonte fictive des huit écrans : **quatre lectures métier étendues, huit parcours couverts par l'audit**.

**Tests ajoutés :** `tests/art-direction-v41-insights.cjs` couvre la variation visible de trésorerie, les changements de signe/zéros, les points haut et bas, les catégories d'effectif, l'ordre des besoins, les écarts de championnat et l'absence de mutation. Ces tests n'ont pas été exécutés localement dans l'environnement GitHub connecté : la CI distante de la PR doit confirmer leur réussite, ainsi que celle des suites de navigateur existantes.

## Matrice de revue et limites

| Écran | Point contrôlé statiquement | Régression à garder |
| --- | --- | --- |
| Bureau | Affiche de match, anneau et calendrier, dossiers repliables | Navigation native, sauvegardes |
| Effectif | Nuage âge/note, point focusable, tableau de valeurs | Aucun attribut modifié |
| Fiche joueur | Radar d’attributs et trois points d’appui | Données du joueur uniquement |
| Préparation | Radar du XV et conditions | Aucune modification de sélection |
| Finances | Courbe projetée et tableau en zone défilante focusable | Projection native, sans écriture |
| Recrutement | Terrain des 15 besoins, nuage de coûts publics | Aucun talent non observé |
| Formation | Intervalle de potentiel et valeurs alternatives | Plafond ≠ progression garantie |
| Championnat | Répartition des points et tableau natif | Classement fictif du moteur |

**Validation à distinguer :** `tests/art-direction-v41.cjs` ajoute des assertions ciblées sur le balisage des trois zones défilantes, le groupe SVG, le focus, les tableaux de données et les champs publics du marché. Les suites Node et Chromium existantes doivent être validées via la CI de la tête exacte de la PR ; aucune nouvelle capture ni audit lecteur d’écran (NVDA/VoiceOver) n'est revendiqué dans ce lot. Les tests locaux ne sont pas présumés exécutés si seuls les contrôles GitHub sont disponibles.

## Exclusions

Aucun changement à `dist/game.js`, au moteur, aux sauvegardes, aux données ou aux travaux DATA-06 du producteur. Les limitations Windows/Safari/Firefox et lecteur d’écran complet restent non certifiées.
