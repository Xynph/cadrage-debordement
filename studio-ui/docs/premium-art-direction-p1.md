# Studio Premium PC P1 — direction artistique Rugby éditorial

## Composition
Quatre écrans interactifs à fixtures fictives : Bureau manager = couverture de match + priorités, Effectif = liste filtrable + dossier joueur, Tactiques = terrain de rugby XV (15 postes sélectionnables) + plans, Recrutement = short-list + dossier scouting. Ne pas présenter ces chiffres comme des données natives.

## Tokens
Vert encre `#101b1a`, vert panneau `#1c332a`, vert pelouse `#306447`, cuivre `#d9ad78`, ivoire `#f4eee3`. Titres éditoriaux en serif système temporaire, UI dense en sans-serif. Aucun visuel ni blason sous copyright emprunté.

## Tests et statut
Storybook prévisualise le shell interactif et les composants précédents. Playwright capture chaque vue aux résolutions 1440×900 et 1920×1080, contrôle le titre et l'absence de débordement horizontal, sélection joueur / scout / XV et changement de plan. Une capture ne prouve pas l'accessibilité ni la qualité artistique commerciale. Prévoir vraie revue visuelle et sélection typographique/licences avant intégration.

## Protection
Aucun import `dist/**`, aucune modification gameplay, save, MATCH 3D, économie, DATA/LNR, calendrier ou gate. Atelier R&D uniquement, aucune fusion.
