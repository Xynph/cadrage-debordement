# Audit manuel Monde sur dix saisons — Cloud, 9 novembre 2026

## Reproduction

Le banc `ci/world-ten-season-audit.cjs` est une commande manuelle, située hors de `tests/` : il ne rejoint pas la CI automatique. Il appelle le vrai worker `native/engine/worker.cjs`, une carrière **Monde v1 de 58 clubs (56 jouables et deux invités)** à club fixe, le catalogue anonymisé versionné et un profil créé dans un répertoire temporaire. Aucun pack privé ni profil personnel n'est requis.

```bash
node ci/world-ten-season-audit.cjs \
  --seed 827381 --seasons 10 --club 0 --budget-ms 1200000 \
  --out /tmp/world-ten-season-progress.json
```

Utiliser Node 22 comme la CI. La graine et le chemin de compte rendu sont obligatoires. Le budget s'applique entre les commandes ; une commande déjà engagée conserve les limites du worker. Le compte rendu est publié atomiquement après chaque semaine et à chaque clôture. À ces frontières sans match actif, le banc conserve aussi un profil complet `<out>.profile.json` et son reçu `<out>.resume.json` hors Git. Le reçu associe SHA-256 du profil, saison, semaine et phase. Le profil temporaire actif est supprimé à la sortie, mais ces checkpoints restent disponibles. Une erreur ou un budget atteint laisse un état `failed`, le nombre de saisons effectivement achevées, la position et la commande fautive ; il ne compte jamais le résultat demandé comme acquis.

Une reprise explicite utilise la même source et la même graine :

```bash
node ci/world-ten-season-audit.cjs \
  --seed 827381 --seasons 10 --club 0 --budget-ms 1200000 \
  --resume-profile /tmp/world-ten-season-progress.json.profile.json \
  --prior-report /tmp/world-ten-season-progress.json.resume.json \
  --out /tmp/world-ten-season-resumed.json
```

Les deux fichiers de checkpoint sont exigés ensemble. Le banc refuse une paire dont le hash, la position ou les saisons annuelles divergent ; il compare ensuite l'état public et le profil privé à la reprise. Un checkpoint ne peut contenir de match actif, pour éviter de confondre la pause de sécurité appliquée au démarrage avec une mutation de carrière. Les saisons déjà achevées ne sont pas recomptées.

## Politique de simulation et preuves

Le club0 dispute ses vrais matchs de championnat et de Coupe d'Europe lorsqu'il est qualifié. Le banc passe par `begin_match`, `delegate`, `finish_round` et `next_season`. Si nécessaire il emploie d'abord `auto_lineup`, puis `promote_cover` avec confirmation publique ; chaque promotion est enregistrée avec les erreurs initiales. Il ne modifie pas l'état pour rendre une feuille valide et n'injecte aucun score. Aucun entraînement, recrutement, investissement ou renouvellement de contrat manuel n'est ajouté.

L'horloge du worker est déterministe pour cette expérience. Ce choix permet de comparer exactement les exports lors d'une réouverture ; les temps de calcul sont mesurés séparément par l'horloge de la machine. Une checksum FNV sur les unités UTF-16, indépendante de l'appel de création de l'export, contrôle chaque export annuel ; le worker valide aussi chaque commande et chaque export. La taille doit respecter la limite Monde v1 de 16 Mio.

Aux clôtures S5 et S10, le worker est fermé puis rouvert avec une graine proposée différente. L'export entier, ainsi que le profil privé contenant le curseur RNG et l'horloge, doivent être identiques. Les exports volumineux ne sont pas enregistrés dans Git. Le répertoire temporaire est supprimé en fin de commande.

Le bilan annuel inclut, par ligue, trésorerie fictive totale/minimum/maximum, nombre de clubs négatifs, effectifs et bornes par club, âges observés, joueurs blessés/non blessés, masse salariale et échéances de contrat. Le marché libre et ses identifiants uniques sont comptés séparément. Les clubs invités sont inclus dans le total mondial mais ne constituent pas une ligue domestique simulée. L'éligibilité des 24 et 18 entrants européens est vérifiée aux transitions ; la validité de la feuille du club humain est vérifiée avant chaque coup d'envoi. Le banc ne prétend pas recalculer une feuille de 23 pour tous les clubs à chaque clôture.

## Résultats mesurés

Exécution réelle sur le moteur `e2f111a2330462aa6545866441289346ac92f2d0`, Node 22.23.4, **une seule graine, 827381**, club0 fixe, Monde v1/58 clubs (et non Monde + Champ) : **dix saisons achevées, 7 910 rencontres** (791 par saison), **1 219 commandes** et neuf transitions de saison. Les 46 semaines de chaque saison sont effectivement exécutées. Temps cumulé du banc : **785 245 ms**, soit environ **13 min 05 s**. La première saison a coûté 73 805 ms ; son extrapolation à dix saisons était de 738 050 ms, sans promesse de durée.

Ce n'est pas un run ininterrompu : le premier segment s'est arrêté normalement au budget de 600 000 ms, à S8W23, après sept saisons closes. Son compte rendu `world-ten-season-budget-segment.json` et son log sont conservés dans le dossier de travail Cloud. La version initiale du banc ne conservait pas encore de checkpoint autonome ; un observateur de fichier a préservé un profil complet et son rapport de la même frontière hebdomadaire. Avant reprise, leur hash et leur position ont été rapprochés. La reprise à S8W23 avec budget relevé a prouvé l'égalité de l'état public et du profil privé (RNG et horloge inclus). Le banc livré conserve désormais ces checkpoints nativement. L'arrêt budget n'est pas un échec du moteur et n'est pas effacé du reçu de cette expérience.

Un premier essai de démarrage avait aussi révélé un garde d'audit arbitraire imposant 16 ans minimum ; le catalogue contient des joueurs de 15 ans. Ce garde a été supprimé et remplacé par des observations de tranche d'âge. Aucun moteur n'a été changé pour faire passer le banc. Son reçu d'échec de banc est conservé séparément.

Les fermetures/réouvertures **S5 et S10** conservent exactement l'export entier et le profil privé avec une graine proposée différente. Chaque clôture satisfait `results === fixtures`. La qualification européenne reste de 24 et 18 clubs aux transitions ; les doublons de clubs dans les poules et de joueurs actifs sont refusés. Pour poursuivre les matchs du club humain, **61 commandes de promotion**, portant sur **72 espoirs**, ont été nécessaires : ce coût et cette politique font partie de la trajectoire, sans autre recrutement ou renouvellement manuel.

| Clôture | Joueurs actifs monde | Trésorerie fictive totale (€) | Clubs domestiques négatifs | Export (octets) |
| --- | ---: | ---: | ---: | ---: |
| Départ | 3208 | 222400000.00 | 0 | 7216805 |
| S1 | 3227 | 126468784.00 | 6 | 8549944 |
| S2 | 2886 | 247746264.00 | 4 | 8961151 |
| S3 | 2617 | 437076147.82 | 0 | 8853546 |
| S4 | 2335 | 690837556.02 | 0 | 8656849 |
| S5 | 2157 | 1009220727.58 | 0 | 8543057 |
| S6 | 2023 | 1365027000.73 | 0 | 8313805 |
| S7 | 1959 | 1760886620.73 | 0 | 8032934 |
| S8 | 1910 | 2185973340.73 | 0 | 7750570 |
| S9 | 1854 | 2656341180.73 | 0 | 7501219 |
| S10 | 1821 | 3160737460.73 | 0 | 7203821 |

Le maximum annuel d'export est **8 961 151 octets** en S2, sous la limite de 16 Mio de cette édition. Le dernier export porte le SHA-256 `901b8eae6ef71266995dcb23a377a7418ad75ae3e02a6f5116c2f14d31b21375`.

| Ligue en S10 | Joueurs | Effectifs min–max par club | Âges min–max / moyenne | Masse salariale hebdomadaire (€) | Cash fictif total (€) |
| --- | ---: | --- | --- | ---: | ---: |
| elite | 449 | 31–33 | 18–36 / 25.83 | 2056260 | 892539353.23 |
| accession | 514 | 30–35 | 18–36 / 25.87 | 2340680 | 955369257.96 |
| prem | 318 | 28–36 | 18–37 / 27.49 | 1340620 | 447313690.77 |
| urc | 483 | 27–33 | 18–36 / 26.57 | 2011460 | 828169549.18 |

Le marché libre passe de neuf à **66 joueurs**, tous d'ID unique au dernier bilan. Les effectifs mondiaux baissent de **43,24 %** entre création et fin S10, tandis que la trésorerie totale est multipliée par **14,21**. Ces observations justifient une investigation de l'évolution des effectifs et de la masse salariale, puis de l'économie. Elles ne démontrent ni un manque de 23 joueurs par club (les minima fin S10 sont de 27 à 31 selon la ligue), ni la cause exacte de l'accumulation financière. Une comparaison appariée, d'autres graines et une analyse des flux sont nécessaires avant toute modification de coefficient.

Les comptes rendus complets `world-ten-season-progress.json`, les logs des deux segments et les checkpoints sont dans le dossier de travail Cloud, hors Git. Le hash du banc chargé au deuxième segment est `60d99ff7ea6605a64d0008c9381d46717322043cac567f38df823d75b0e79414` ; le tout premier segment ne l'enregistrait pas. La version livrée complète ensuite les gardes de reprise et les métadonnées de provenance, sans modification de commandes de simulation. Une reprise de contrôle du checkpoint final S10 a exécuté cette version finale et conservé les dix bilans, sans ajouter de saison simulée. Les gardes ont également refusé des reçus avec faux hash, mauvaise position et bilan d'une saison future ; la revue indépendante a exercé en plus le refus d'un match actif.


## Limites d'interprétation

Une trajectoire avec une graine et une politique de gestion ne démontre pas l'équilibrage général. Les bilans annuels ne révèlent pas toutes les situations déficitaires en cours de saison. Les sommes sont les montants fictifs du jeu, pas les budgets réels des clubs. Le nombre de blessés/non blessés ne constitue pas à lui seul une qualification réglementaire de feuille. Les règles provisoires documentées du moteur restent provisoires ; ce banc ne les transforme pas en règles officielles confirmées. Aucun coefficient, moteur, format d'export ou jeu de données n'est modifié.
