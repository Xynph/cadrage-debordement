# V4 Premium — refonte graphique proposée

**État : réalisée sur `integration/v4-premium`, sans fusion.** Base vérifiée : `1b1d7d624995af823dcbdce42a6a1d6ad148d336`. L’autorisation de Léo est nécessaire avant toute fusion de cette V4.

## Direction artistique

L’accueil conserve les deux photographies synthétiques locales de la V3 : stade cinématique et ballon légèrement boueux. La nouvelle couche `premium-v4.css` étend leur identité au jeu : vert forêt, accents cuivre, titres Barlow Condensed, tableaux alternés, surfaces et espaces cohérents. Les deux préférences existantes restent disponibles : **Analyste sombre** et **Tribune clair**. Les polices demeurent locales.

Les changements concernent l’accueil à cinq carrières, le choix du club, la navigation à deux niveaux, le bureau du manager, les indicateurs, l’effectif, les fiches, le recrutement, la formation, la préparation, le centre de match, le classement, le mercato, les finances, les sauvegardes, l’aide, les modales et le cockpit live. Le bureau affiche ses trois colonnes sans superposition à partir de 1300 px ; les dispositions natives empilées sont conservées aux petites largeurs. Le terrain SVG et les couleurs des équipes ne sont pas remplacés.

Un panorama original supplémentaire (`dist/assets/premium-v4-matchday.webp`, environ 153 Kio) habille le bureau et la préparation : sortie de tunnel, pelouse humide, poteaux de rugby, soleil cuivré et ballon légèrement boueux. Décoratif uniquement : ni résultat, ni logo ou donnée officielle injectés. Le code de jeu n’effectue aucune requête vers le service de génération.

## Figma et génération

[Fichier Figma V4 créé](https://www.figma.com/design/1l49iJzk7x5dMghVJjh6un). La lecture/édition suivante a renvoyé : « You've reached the Figma MCP tool call limit on the Starter plan ». **Ce fichier n’est donc pas une maquette finalisée et aucune validation de design Figma n’est revendiquée.** Le travail d’implémentation et les captures réelles ont continué dans Work.

Image créée avec l’outil intégré `image_gen`, puis conversion PNG → WebP avec Pillow (qualité 86, sans retouche). Prompt :

> Panoramic photographic banner for a French rugby union management game. Empty professional XV stadium viewed from just inside the players tunnel after rain at golden dusk; believable H-shaped rugby goalposts, emerald pitch, fine mist, copper orange light from the right, deep forest green shadows. A slightly muddy ivory rugby ball in the lower right, natural pebbled leather and oval shape. Left 55% dark and quiet for UI text. No people, text, logos, sponsors, watermarks, soccer nets or UI. Restrained cinematic sports-management art direction.

## Preuves visuelles

Les fichiers dans `premium-v4-captures/` sont de **vraies captures Playwright du jeu local**, avec carrières fictives de test. Le comparatif `comparison-dashboard.webp` utilise la même carrière et la même fenêtre : la seule différence est l’activation du CSS V4. Ce sont des captures du navigateur, pas des maquettes générées par IA.

- [Avant/après du bureau](premium-v4-captures/comparison-dashboard.webp)
- [Accueil desktop](premium-v4-captures/home-1440.webp)
- [Bureau V4](premium-v4-captures/dashboard-after.webp)
- [Recrutement](premium-v4-captures/recruitment-analyste-1440.webp)
- [Formation claire](premium-v4-captures/formation-tribune-1440.webp)
- [Effectif](premium-v4-captures/team-analyste-1440.webp)
- [Finances claires](premium-v4-captures/finance-tribune-1440.webp)
- [Bureau mobile](premium-v4-captures/dashboard-tribune-390.webp)
- [Accueil mobile](premium-v4-captures/home-390.webp)
- [Match live](premium-v4-captures/live-1440.webp)

## Validation locale exécutée

| Vérification | Résultat |
| --- | --- |
| Toutes les suites Node `tests/*.cjs`, hors harness | **142/142 réussies**, 5 processus concurrents, délai de 180 s par suite |
| `premium-v4-browser.py` | **529 contrôles réussis**, 14 routes × 2 thèmes × 6 largeurs (1920, 1440, 1024, 768, 390, 320 px), absence de mutation de carrière et de réécriture sur consultation, images locales décodées, cinq slots, pause live, contraste du commentaire, trois colonnes sans recouvrement |
| `ui01-browser.py` | **462 contrôles réussis**, navigation réelle par boutons, export de carrière, erreurs de sauvegarde visibles, modales et pont offline doublé |
| `ui01-contrast.py` | **16 mesures réussies**, quatre textes × deux thèmes × deux largeurs, seuil 4,5:1 |
| 11 autres suites navigateur existantes | **11/11 réussies**, 323 contrôles : fiches joueurs, disponibilité, centres natifs, formation, préparation, feuille à 23, plan de match, carrières LNR et menu V3 |
| `git diff --check`, compilation Python | Réussis |

Le défaut de contraste du commentaire live a été reproduit par un test rouge avant correction. La revue visuelle a également corrigé une mauvaise priorité CSS héritée, un espace vide dans le bureau et une superposition de colonnes. La revue indépendante a aussi identifié une priorité CSS neutralisant les préférences de texte agrandi et de contraste du menu : deux contrôles de styles calculés ont reproduit puis couvert la correction. Aucun autre problème majeur n’a été relevé. Le test d’origine du choix de club conserve son assertion de palette, actualisée de bleu vers vert sombre.

Les rapports JSON conservés ici documentent les exécutions locales. La CI distante sur le dernier SHA fait autorité pour une éventuelle fusion ; aucun résultat futur n’est présumé. Le workflow `V4 Premium visual acceptance` publie les captures et son rapport en artefact. Le workflow existant UI01 et le workflow JavaScript complet restent actifs.

## Compatibilité et limites

Aucune fonction JavaScript du jeu, moteur de match, règle sportive, clé de stockage ou structure de sauvegarde modifiée. Le seul changement HTML charge la couche CSS finale. Les tests natifs incluent les anciennes sauvegardes, la migration, l’import/export, les verrous en match, les carrières longues et le rejet des sauvegardes corrompues. Les tests navigateur utilisent exclusivement leur stockage isolé.

Chromium Linux testé ; aucune certification Windows native, Safari, Firefox ou appareil tactile réel. Les mesures de contraste ciblées ne constituent pas un audit WCAG exhaustif. La maquette éditable Figma reste à produire après résolution du quota. La V4 graphique est proposée pour revue, **pas livrée sur `main`**.
