# Rapprochement de la BDD commune et des audits GitHub

Audit en lecture seule du8novembre2026 pendant la mission autonome. Sources comparées : [PR389 au SHA a539b7bb](https://github.com/Xynph/cadrage-debordement/pull/389), [PR388 au SHA37b9390c](https://github.com/Xynph/cadrage-debordement/pull/388), registre d'effectifv2 actuel et état initial d'une véritable nouvelle carrière native commune. Aucun dossier statistique de production, attribut, potentiel, contrat ou identité n'est modifié par cet audit.

## Postes : ne pas réappliquer les anciens correctifs

Les16dossiers de postes de l'auditV16 ont été retrouvés par ID dans les1592professionnels du worker. Douze postes actuels correspondent déjà à la proposition. Les quatre écarts restants correspondent **exactement aux quatre quarantaines existantes** :

| ID | Poste de jeu conservé | PropositionV16 | Motif du maintien |
|---|---|---|---|
| lnr:13516 | Pilier droit | Talonneur | La proposition est contredite par une autre page primaire ; le côté n'est pas établi par cette page. |
| lnr:13531 | Pilier gauche | Aucun côté établi | Publication de pilier sans côté précis. |
| lnr:13650 | Pilier droit | Pilier gauche | Proposition fondée seulement sur une source secondaire. |
| lnr:13711 | Talonneur | Pilier gauche | Proposition fondée seulement sur une source secondaire. |

Le registrev2 doit donc conserver sa priorité ; les mappingsV16 ne doivent pas être appliqués en bloc. Le rôle de jeu initial et une qualification réglementaire réelle restent deux notions distinctes. Les raisons ci-dessus résument la quarantaine déjà consignée, pas une nouvelle vérification des sites de clubs.

Le catalogue brut et la carrière ne montrent pas la même couche : `common-rosters.cjs` applique le registre initial avant de construire le monde. **78postes effectifs diffèrent du catalogue brut**, cumul des références déjà intégrées ; ce nombre ne constitue pas78nouveaux changements de ce lot. Les anciens «67changementsv2» ne doivent pas être comparés sans leur base et leur couche de référence.

## Notes et potentiel : aucune hausse globale

Les neuf dossiers de calibration proposés dansV16 et les40priorités de trajectoireV14 sont tous présents dans la base actuelle. Le champ `activationAuthorized` des neuf propositions reste faux. Le potentiel historique et `dev.potential` de carrière sont relevés séparément : leur différence ne suffit pas à justifier une correction automatique.

La campagne C02 a ensuite exécuté neuf saisons initiales complètes : 323 semaines et260matchs utilisateur réellement délégués, avec53checkpoints export/import/reprise et RNG strictement identiques. Huit carrières atteignent S2semaine2. Le dossier1793 s'arrête àS2semaine1 : un demi de mêlée blessé laisse le banc incomplet ; aucune garde de feuille n'a été contournée. Un joueur naturellement retraité et deux joueurs libérés en fin de contrat ne reçoivent aucune note fictive après leur départ.

Le rating scalaire, la note au poste et le potentiel projeté sont distingués. Par exemple184 conserve rating69, mais sa note au poste passe69→70 à l'intersaison. L'évolution annuelle des attributs existe malgré un rating arrondi parfois stable. Ces observations sur une graine par dossier ne constituent pas une validation statistique d'équilibrage ni une autorisation d'appliquer les doses de calibration. Les tests généraux de carrière et la BDD de l'autre développeur restent complémentaires.

Deux limites produit restent visibles : les agents libres sont bornés à60 par le moteur historique, ce qui peut retirer du monde courant un joueur pourtant jeune ; une carrière doit parfois recruter ou promouvoir un renfort pour retrouver une feuille valide. La réception n'a imposé ni prolongation ni recrutement pour masquer ces cas. Aucun changement de cette mécanique économique centrale n'est inclus dans l'audit.

Les divisions ont été vérifiées dans les vraies lignes des championnats sur18reprises. Vannes appartient initialement à l'Élite du catalogue fictif : il est relégué dans une carrière et maintenu dans l'autre. Ce résultat ne doit pas être décrit comme une promotion initiale ni comme la composition officielle2026–2027.

Preuves locales C02 : `E:/Cadrage-Debordement/temp/c02-trajectoires-G4a2tD/verification.json`, `summary.json`, `league-models.json` et `annual-comparison.json`. Les sources moteur et les données ont les mêmes empreintes avant/après. Export maximal observé :3839395octets/5Mio et235842nœuds/650000 ; aucune borne mathématique de tous les états possibles n'est revendiquée.

## Compilation et invariance

Le contrôle du constructeur avait détecté deux empreintes périmées après les correctifs de capacité dans `dist/rugby.js` et `dist/development.js`. Une comparaison complète montre que seule la clé `sources` du catalogue généré a changé. Les30clubs et1592objets joueurs sont profondément identiques au blob du HEAD précédent, avant application du registre initial.

Preuve locale : `E:/Cadrage-Debordement/temp/cd-bdd-reconciliation-Rv8mHQ/audit.json`, produite depuis les objets Git exacts et un profil jetable. Le pack privé et les données personnelles n'ont pas été lus par cet audit.
