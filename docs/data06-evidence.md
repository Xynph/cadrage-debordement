# DATA-06 — Premières preuves officielles indépendantes de Firecrawl

Périmètre : **98 arrivées publiées pour 14 clubs**, provenant du [tableau officiel des transferts TOP 14 2026–2027](https://top14.lnr.fr/actualite/le-tableau-des-transferts-pour-la-saison-20262027), relevé le 31 octobre 2026. Cette sélection est **partielle** et ne représente pas les effectifs complets des 30 clubs. Le nom et le poste reprennent la source, y compris les éventuelles variantes orthographiques à vérifier. Une arrivée publiée ne certifie pas la présence au 01/07/2026 ; prêts indiqués lorsque le libellé officiel le précise.

## Séparation stricte des données et du jeu

- `modding/data06/official-transfers-2026-2027.json` conserve nom, club destinataire, poste, nationalité, provenance, indication de prêt, URL source. Les contrats, budgets, salaires et informations historiques non publiés sont `null` ou explicitement non vérifiés.
- `tools/data06-evidence.cjs` refuse doublons club/nom, absence de source, prétentions financières/historiques injustifiées et contradictions sur les prêts ; rapprochement par nom normalisé et club, uniquement lorsque la correspondance est unique. Les conflits et transferts entre clubs nécessitent une revue humaine.
- Les éventuelles notes de jeu sont des **estimations** distinctes (`kind:game-estimate`) ; aucune note n'est produite sans statistiques fiables transmises au calculateur. L'heuristique provisoire minutes/essais **ne mesure pas la compétence réelle** et ne doit pas être activée par défaut dans la carrière.
- Aucun logo, photographie, chiffre salarial ou budget extrapolé, ni collecte automatique payante. Aucun changement des sauvegardes, de `dist/**` et des bases DATA-03/DATA-05.

## Validation

`node --test tests/data06-evidence.cjs`
`node tools/data06-evidence.cjs`

Cette PR n'intègre pas encore les arrivées au moteur de jeu : les clés doivent être rapprochées des IDs LNR avant toute importation. Priorités suivantes : vérifier le rapprochement 80/1592 sur les véritables effectifs, enrichir les clubs restants (dont PRO D2), puis collecter les staffs et finances uniquement lorsque des documents publics datés les attestent.

Toute utilisation automatique des sites externes exige le respect de leurs règles d'accès, sans contournement de restrictions.

## Rapprochement contrôlé des 98 mutations

La comparaison exacte, normalisée sur le nom et le club, avec les 1 592 entrées DATA-03 donne **52 correspondances exactes**, **12 noms présents dans un autre club (revue manuelle)**, **34 noms absents du roster de référence**. Le fichier `modding/data06/transfer-reconciliation-2026-2027.json` donne les 98 lignes, candidats et IDs lorsque la correspondance est univoque. Aucun des 46 cas litigieux n'est automatiquement créé, déplacé ou rattaché. Une absence peut correspondre à un nouvel arrivant, une variation orthographique ou une erreur d'identité : seule une preuve source peut trancher. Les 47 correspondances ne certifient pas rétroactivement la composition au 01/07/2026.

Le complément porte sur les arrivées officiellement listées pour Toulon, le Stade Français, La Rochelle et Toulouse, y compris Apete NAROGO dont la provenance n'est pas précisée : ce champ reste vide plutôt que supposé. Toute vérification historique au 01/07/2026 reste distincte du tableau des mutations.
