# Univers fictif jouable — clubs 2026/27

## Résultat
Les **14 clubs du championnat principal jouable** portent des noms, abréviations et stades originaux fictifs. Le catalogue R1 (30 clubs, deux ligues) reflète ces 14 nouvelles identités dans sa première division ; les 16 autres clubs restent un référentiel préparatoire, **non simulé** dans cette version.
Les notes, couleurs, budgets de simulation et joueurs générés restent de la pure fiction ; les coefficients et règles sportives ne changent pas.

## Sauvegardes
Les noms sont **déjà inclus dans l'état `S.clubs`**. Les carrières commencées avant ce changement conservent leurs identités antérieures après rechargement, sans conversion ni renommage forcé. Les nouvelles carrières démarrent avec les clubs fictifs. Aucun changement de format du document de sauvegarde et aucune liaison aux mods non encore activés.

## Réception
`node tests/fictional-league.cjs` valide l'alignement du catalogue R1, les anciennes sauvegardes et le départ d'une nouvelle carrière. La CI complète sur SHA final et la CI post-fusion sont obligatoires. Les anciennes captures de versions précédentes restent historiques.
