# V4.1 — audit et finition accessibilité des huit compositions

## Base et périmètre

Issue de `main` au commit `f72e2c47fd05cacdd3f0e8cf0b3e8899f3a59f20`, après la fusion et validation de la V4 Premium dans la PR #162. Cette V4.1 est une **branche de revue** : aucune fusion automatique.

La revue statique couvre le bureau, l’effectif, la fiche joueur, la préparation du XV, les finances, le recrutement, la formation et le championnat. Les compositions et graphiques métier, le stade, le ballon légèrement boueux, les couleurs forêt et cuivre sont conservés. Les calculs et valeurs des graphiques restent ceux du moteur natif.

## Problèmes précis et corrections

- **Défilement horizontal au clavier** : les zones SVG défilantes des finances, nuages de points (effectif et recrutement) et intervalles de potentiel (formation) étaient des `div` non focusables. Elles portent désormais `tabindex="0"`, `role="region"` et un nom accessible ; la bordure de focus est visible. L’effet est particulièrement utile en largeur mobile, lorsque le SVG conserve sa largeur de lecture.
- **Sémantique des points** : le nuage exposait une image SVG globale (`role="img"`) contenant des cercles focusables. Il est désormais un groupe SVG nommé (`role="group"`) pour ne pas masquer ses enfants interactifs aux technologies d’assistance. Chaque point garde son nom accessible, la lecture au focus et le tableau de valeurs.
- **Contraste forcé** : indicateurs de focus, grilles et tracés essentiels reçoivent une prise en charge `forced-colors: active`, sans remplacer les couleurs du thème normal.

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
