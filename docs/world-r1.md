# R1 — Référentiel mondial 2026/27 (fondations indépendantes)

## Périmètre livré
- Schéma versionné 1 : compétitions, clubs, joueurs, membres de staff, jeunes.
- Identifiants stables préfixés et validation des références club/compétition.
- Provenance obligatoire **par enregistrement** : URL HTTPS, date de vérification, type de source, état de réutilisation.
- Contrôles de types, postes normalisés, rôles du staff, dates ISO, unicité des IDs, références et absence de chiffres financiers non étayés.
- Import JSON, fusion de catalogues sans mutation et outil en ligne de commande.
- Référentiel français **partiel** : TOP 14 (11 clubs nommés dans le communiqué officiel vérifié) et PRO D2 (10 clubs nommés dans le communiqué officiel vérifié), soit 21 clubs identifiés sur les 30 places. Les neuf autres clubs et les effectifs nécessitent un relevé officiel complémentaire.

## Sources et droits
TOP 14 : https://top14.lnr.fr/actualite/decouvrez-le-calendrier-2026-2027-de-top-14
PRO D2 : https://www.lnr.fr/actualite/decouvrez-le-calendrier-2026-2027-de-pro-d2
Contrôle au 31/10/2026. Les formats de compétition 14/26 et 16/30, ainsi que les clubs nommés, proviennent de ces pages LNR.

**Licence de réutilisation non établie** : statut `permission-required`. La citation d'une source officielle ne vaut pas autorisation de republication commerciale ou de copie de base structurée. Pas de photos, logos, données sous licence, biographies ni contrats intégrés. Vérifier le droit de distribution de ces données avant publication d'un produit utilisant cette base ; envisager une base sous licence ou des saisies d'informations autorisées.

## Données de personnes
Les collections joueurs, staff et jeunes sont **vides** en R1 plutôt que d'inventer des effectifs, dates de naissance, potentiels ou salaires. Les attributs simulés doivent rester dans une autre couche et ne sont pas acceptés comme faits du catalogue.

## Raccordement futur
R1 n'est pas encore jouable : aucun nouveau script chargé par `dist/index.html`. Les anciennes sauvegardes et le catalogue historique de 14 clubs restent intégralement inchangés. R2 devra compléter les participants 2026/27 à partir de sources officielles, les effectifs avec licences contrôlées, puis proposer un adaptateur vers un **nouveau format** de carrière multi-ligues avec migration volontaire. L'intégrateur seul autorise ce raccordement.

## Tests
`node tests/world-catalog-r1.cjs`
`node tools/world-import.cjs world-data/r1/fr-2026-2027.json`
Puis CI complète sur la tête de PR, contrôles sauvegardes inchangées et validation post-fusion.
