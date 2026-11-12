# Date de compétition : rectangle du Label et pixels visibles

Diagnostic isolé depuis `861b836091b5d32b1f88406b739ae9a7799148aa`,
12 novembre 2026. Aucun produit ni scénario QA n'est modifié. L'intégrateur
a exécuté les deux sondes avec Godot officiel 4.7.2 ; l'auteur du présent
reçu a inspecté les sources, journaux et calculs sans nouvelle exécution SDK.

## Format et calcul vérifiés

`CompetitionCanvas._date` délègue à `P.fixture_date`. Ce dernier utilise
`Club._calendar_date` (date ISO transformée en `jour/mois/année`) puis ajoute
` · ` et `kickoffLocal` lorsqu'il est présent. L'échantillon raster
`12/09/2026 · 15:00` représente ce format numérique effectivement affiché ;
ce n'est pas le texte long « Samedi 12 septembre 2026 » de la sonde métrique.

`D.text` reçoit une ligne de base, pas une position haute :
`y = C.px(231) - C.font(700).get_ascent(max(12,C.px(27)))`.
La police sélectionnée est `BarlowCondensed-Bold.ttf`. La sonde métrique
confirme les ascendants 14, 15, 17, 20 et 27 pixels pour les cinq densités.
Le rectangle du Label dépasse donc le haut de la cible, même après le
correctif de hauteur ; sa largeur inclut aussi de l'espace transparent à
droite hors de la cible. Il serait incorrect d'affirmer que le rectangle
complet est inclus.

La sonde raster finale mesure les pixels non transparents d'un Label seul,
sur fond transparent, sans écran de jeu ni autre contrôle dessiné. Le
viewport réel reste 1280 × 800 et `content_scale_size = root.size` : les
cinq dimensions du tableau servent à configurer `C.density`, et ne sont
pas cinq fenêtres ou captures du jeu à ces résolutions.

| Paramètres de densité | Densité | Cible (x,y,largeur,hauteur) | Encre non transparente (x,y,largeur,hauteur) | Encre incluse |
| --- | --- | --- | --- | --- |
| 1280 × 800 | 0,5 | 18 ; 105 ; 235 ; 18 | 20 ; 107 ; 94 ; 9 | oui |
| 1440 × 900 | 0,5625 | 20,25 ; 118,125 ; 264,375 ; 18 | 23 ; 119 ; 101 ; 11 | oui |
| 1600 × 1000 | 0,625 | 22,5 ; 131,25 ; 293,75 ; 21 | 25 ; 132 ; 115 ; 12 | oui |
| 1920 × 1080 | 0,75 | 27 ; 157,5 ; 352,5 ; 24 | 30 ; 158 ; 135 ; 15 | oui |
| 2560 × 1440 | 1 | 36 ; 210 ; 470 ; 33 | 40 ; 212 ; 182 ; 19 | oui |

Les quatre inégalités d'inclusion ont été recalculées depuis chaque ligne
JSON du journal, indépendamment du booléen `ink_enclosed`. La sonde raster
omet le minimum de hauteur de police hérité du Button ; le produit prend
le maximum avec ce minimum supplémentaire, et ne peut donc réduire cette
aire à position identique. Les pixels de cet échantillon restent inclus.
Le dépassement supérieur du rectangle est ici du leading transparent.

## Décision et portée

Aucune union du rectangle de cible avec celui du Label n'est appliquée.
La sonde métrique montre qu'une telle union déborderait dans les deux
cibles des clubs voisins : chevauchement vertical de 2,5 à 5 pixels selon
la densité. La distinction entre rectangle de mise en page et encre évite
d'introduire ce chevauchement pour corriger un espace transparent.

Ce résultat porte sur un échantillon numérique, cette police et ces cinq
densités. Il ne démontre pas l'inclusion universelle de tous textes,
polices ou formats possibles, ni le hit-test global, un clic réel en haut
ou en bas du texte, les transformations d'un écran complet, la navigation
clavier ou une recette Windows. Les sondes n'instancient pas le jeu et ne
préparent aucune carrière.

Un premier essai raster avait une transformation de contenu différente
(stretch de 1440 vers 1280). Il était invalide pour comparer ces coordonnées
et n'est pas retenu comme preuve. Le journal raster joint est exclusivement
le passage final corrigé avec `content_scale_size = root.size`. Le journal
métrique a été rejoué par l'intégrateur pour en conserver une copie.

Les avertissements `libspeechd.so.2` absente et V-Sync non modifiable sont
conservés dans le journal raster. Ils ne constituent ni une validation de
la parole ni une recette audio. Aucun profil, export ou sauvegarde n'est joint.

## Pièces reproductibles

- [Sonde métrique](competition-date-ink-20261112/competition-date-metrics-probe.gd) et [journal](competition-date-ink-20261112/date-metrics-probe.log).
- [Sonde raster finale](competition-date-ink-20261112/date-ink-probe.gd) et [journal corrigé](competition-date-ink-20261112/date-ink-probe.log).

Ces scripts restent des sondes documentaires, hors registre CI et hors suites
produit. Ils préchargent les primitives du projet ; leur exécution requiert
le projet correspondant et le SDK. Ce reçu n'a entraîné aucun nouveau test.
