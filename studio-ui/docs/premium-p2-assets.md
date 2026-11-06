# Premium P2 — manifeste artistique et provenance des assets

## Objectif visuel

Univers rugby éditorial premium : scènes de stade, badges de clubs et visages fictifs distincts des composants interactifs. Les textes, tableaux, sélections et statistiques doivent toujours être rendus par React et non intégrés dans une image générée.

## Assets versionnés sur GitHub

- `public/assets/premium/crests/*.svg` : quatre **blasons fictifs originaux** (Atlantique XV, Stade Armorique, Valmont, Estuaire), dessin vectoriel de ce projet. Aucune reproduction de marque sportive.
- `public/assets/premium/portraits/*.svg` : quatre **portraits illustrés fictifs** réutilisables (Gabriel, Eliott, Théo, manager). Ne pas les présenter comme photographies.
- `public/assets/premium/backgrounds/*.svg` : quatre illustrations vectorielles de stades sous projecteurs.
- `public/assets/premium/backgrounds/*-ai-preview.webp` : quatre **textures photo générées par IA** pour ce projet, extraites de concepts graphiques, recadrées et fortement floutées puis compressées à 240×135 pixels. Ces images ont été dépouillées de leurs faux textes UI par le flou et utilisées uniquement comme sous-couche d'ambiance, jamais comme source de chiffres.

## Pack séparé de prototypes

Les composites IA originaux, fonds recadrés de plus haute résolution et portraits photographiques d'étude sont transmis sous archive de travail distincte. Ils ne sont **pas encore intégrés** au dépôt car ils contiennent parfois des traces de faux boutons ou de textes générés, à détourer/nettoyer avant qualité commerciale.

## Design system

Palette principale : fond #0c1916, vert #1b332a, cuivre #d7ad7a, ivoire #f3eadb. Typographie Georgia est un substitut temporaire à une police serif sous licence adaptée ; interface sans-serif système. Différencier au minimum les états actif, survol et focus visible, respecter reduced-motion.

## Protocole de qualification

- `npm ci`, TypeScript, build Vite, build Storybook.
- Playwright Chromium : 4 écrans × 2 résolutions, interactions, contrôle du débordement horizontal et présence/chargement des images.
- Inspection visuelle réelle obligatoire : portraits entièrement visibles, textes lisibles, illustrations non pixelisées sur écran 1920, qualité des dégradés et contraste. Les WebP 240×135 sont des **ambiances floutées**, non des photos haute résolution.
- Aucun raccord moteur, gameplay, sauvegardes, MATCH 3D, finance, DATA/LNR, calendrier, gate ou `main`. PR DRAFT, pas de fusion.

## Suites indispensables avant qualification commerciale

Rendre les portraits photographiques propres et réellement individuels, introduire typographie licenciée, variantes Penpot, états clavier complets, icônes propres, comparaisons statistiques avec vraies données du moteur en lecture seule après validation du raccord, animation subtile et WCAG AA.
