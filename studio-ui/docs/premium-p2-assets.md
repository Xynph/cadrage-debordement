# Premium P2 — manifeste artistique et provenance des assets

## Reprise P3 du 7 novembre 2026

Deux nouveaux assets photographiques IA propres, générés pour ce projet, sans texte ni interface incorporée :

| Asset | Définition | Usage |
| --- | --- | --- |
| `portraits/players-atlas-p3.webp` | 1254 × 1254, grille 3 × 3 (418 × 418 par visage) | Neuf identités fictives, listes et dossiers avec le même cadrage CSS |
| `backgrounds/stadium-night-p3.webp` | 1672 × 941 | Fond de stade nocturne avec deux joueurs à droite, Bureau et bandeau Recrutement |

Sources PNG originales conservées séparément ; WebP transcodés en qualité 91 sans modification du contenu. Les assets P2 restent versionnés comme historique et repli. Les visages P3 sont entièrement fictifs ; aucune identité de sportif réel revendiquée.

**Direction des prompts** : atlas 3×3 de portraits photographiques de rugbymen adultes fictifs, maillots vert forêt sans marque, fond vert encre, lumière douce et liseré cuivre, têtes entières ; stade de rugby de nuit sous la pluie, poteaux en H, espace sombre à gauche pour les textes HTML, deux joueurs de dos à droite, sans numéros, logos, texte ni interface.

**Indices stables** : Gabriel 0, Noah 1, Mathis 2, Sacha 3, Eliott 4, Léo 5, Théo 6, Milan 7, Rayan 8. Aucune répétition d'identité entre ces neuf personnages. Les noms et statistiques de démonstration restent en HTML.

Penpot : la passation P1 #73 commentaire 6698325202 décrit les pré-maquettes natives existantes. À cette reprise, le connecteur répond « No Penpot instance connected » : aucune modification ni synchronisation P3 de ces pré-maquettes n'est revendiquée.

## Objectif visuel

Univers rugby éditorial premium : scènes de stade, badges de clubs et visages fictifs distincts des composants interactifs. Les textes, tableaux, sélections et statistiques doivent toujours être rendus par React et non intégrés dans une image générée.

## Assets versionnés sur GitHub

- `public/assets/premium/crests/*.svg` : quatre **blasons fictifs originaux** (Atlantique XV, Stade Armorique, Valmont, Estuaire), dessin vectoriel de ce projet. Aucune reproduction de marque sportive.
- `public/assets/premium/portraits/*.svg` : quatre **portraits illustrés fictifs** réutilisables (Gabriel, Eliott, Théo, manager). Ne pas les présenter comme photographies.\n- `public/assets/premium/portraits/photo-atlas-ui.webp` : quatre **visages photographiques fictifs issus des concepts IA originaux**, recadrés/nettoyés et compressés en miniatures (54×72 chacun), affectés aux listes Effectif et Recrutement ; ne jamais les agrandir en portraits de dossier pleine taille.
- `public/assets/premium/backgrounds/*.svg` : quatre illustrations vectorielles de stades sous projecteurs.
- `public/assets/premium/backgrounds/*-ai-preview.webp` : quatre **textures photo générées par IA** pour ce projet, extraites de concepts graphiques, recadrées et fortement floutées puis compressées à 240×135 pixels. Elles sont utilisées uniquement comme sous-couche d'ambiance, jamais comme source de chiffres.\n- `public/assets/premium/backgrounds/bureau-hero-ai.webp` : recadrage photographique IA original des joueurs fictifs sous les projecteurs, optimisé 220×146 ; photo scénique propre (sans faux labels UI), utilisée à droite du Bureau. Cette version allégée devra être remplacée par un export haute résolution avant un produit commercial.

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
