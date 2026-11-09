# Réconciliation bornée des flux hebdomadaires Monde

Audit manuel du 9 novembre 2026 sur le moteur `c07ce6a68adfa4f6aee72caab4523c77508bf8e3`, Node 22.23.4, graine `827381`, horloge déterministe `1794178800000`, club humain 0, Monde v1. Montants fictifs du jeu. Aucun coefficient, règle de recrutement, contrat, profil utilisateur ou fichier de production existant modifié.

## Méthode et reproduction

```bash
node --test tests/world-finance-flow-audit.cjs
node ci/world-finance-flow-audit.cjs --seed 827381 --weeks 3 --club 0 \
  --out /tmp/world-finance-flow-report.json
```

Le banc manuel demeure hors de `tests/` ; la seule suite courte de régression rejoint les tests usuels. Le banc crée un profil jetable et appelle les commandes publiques du vrai worker. Si un match humain est prévu, il utilise `auto_lineup` et, si nécessaire, `promote_cover` confirmé, puis `begin_match` et `delegate`. Chaque commande et son résultat sont enregistrés ; aucun refus moteur n'est ignoré. Le relevé avant/après encadre exclusivement `finish_round`, après le match humain éventuel. Il ne mélange donc pas les dépenses de préparation avec la semaine mesurée. Aucun entraînement ou recrutement manuel, score injecté ou intervention d'intersaison.

Les checkpoints sont de vrais exports validés par le moteur. Le journal JSON hors Git contient leurs SHA256, les empreintes des profils privés avant/après, le commit moteur, les hashes des sources et du banc réellement exécutés, les composants par club et les inconnues. Les profils temporaires sont supprimés et le worker fermé même si le banc échoue. Les états complets ne sont pas versionnés. Le journal final de cette réception est `/workspace/work/world-finance-flow-report-received.json` ; il ne contient ni identités privées ni carrière personnelle.

## Formules effectivement confrontées

`native/engine/world-career.cjs:finishWeek()` appelle `financeWeek` pour le club humain puis `worldWeeklyEconomy(results)`. Le calcul IA réel, dans `dist/world-career.js`, saute le club humain :

`160000 − salaires + 360000 si domicile non neutre + 80000 si victoire − entretien`.

Les résultats proviennent des nouvelles entrées d'historique, dont les vainqueurs d'élimination éventuels sont pris en compte. L'entretien utilise le calcul existant `CDFacilities.maintenanceForecast` : zéro aux niveaux 1–2 ; pour un niveau supérieur, le code de production arrondit son résultat hebdomadaire avec `baseWeekly:2000`. Le module d'audit appelle ce calcul pur existant, sans créer une nouvelle formule financière.

Les sommes de salaires sont relevées avant et après. Un roster ou niveau d'installation modifié au cours de la commande reste **unknown**, sauf une exception de source explicitement bornée aux trois premières semaines : `simulate()` appelle `ensureAISheet` avant `createRugbyMatch`, puis vient la facturation. Après celle-ci, `careerBoardWeekReview` et les objectifs concernent l'humain ; `refreshMarket` ne recrute pas d'IA aux semaines de destination 1/2/3 (ses seules fenêtres sont 0 et 13), et `repairSheet` ne change que la feuille humaine. Les ajouts de couverture IA observés sont donc déjà présents à la facturation, sans flux de roster ultérieur dans ce périmètre.

Le statut distinct **reconciled-source-order** exige cette fenêtre, des anciens salaires identiques et tous les ajouts associés à un événement `emergency` ou `promote` sans frais, ainsi qu'un résidu nul avec le payroll de clôture. Le banc vérifie ensuite ce résultat par un replay de la vraie `worldWeeklyEconomy` dans une VM isolée : cash d'ouverture, rosters de clôture et résultats réels. Un replay seul ne prouve pas l'ordre ; il complète ici la preuve de code. Les colonnes payrollBefore/payrollAfter, ajouts et résidu avec payroll d'ouverture sont toujours conservées. Hors de ce périmètre, ou avec un résidu non expliqué, le statut reste unknown. Aucune recette ou charge n'est renommée automatiquement en transfert, dette ou investissement.

Le club humain est réconcilié séparément à ses nouvelles lignes de grand livre : partenaires, salaires, billetterie, prime et entretien. Les autres lignes éventuelles restent visibles, sans leur inventer une cause. Sa billetterie est `rand(300,450)*1000`, pas les 360000 fixes IA. Les primes de sponsor éventuelles appartiennent au grand livre humain ; le banc ne leur applique pas la formule IA. La recherche d'une queue commune du ledger détecte les lignes ajoutées ; si cette queue n'est pas identifiable, le résultat est unknown.

## Résultats reçus : trois vraies semaines

Chaque semaine a simulé 15 rencontres. Les 58 clubs du monde, dont les deux invités, sont inclus : un humain et 57 IA. Un club sans match reçoit néanmoins sa base hebdomadaire et paie ses salaires selon la formule actuelle.

| Semaine avant → après | IA stables + expliquées par ordre source | Delta IA observé | Résidu avec payroll d'ouverture | Recettes partenaires IA | Billets IA | Primes IA |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| S1W0 → W1 | 54 + 3 / 57 | −3 038 226 € | −8 000 € | 9 120 000 € | 5 040 000 € | 1 200 000 € |
| S1W1 → W2 | 56 + 1 / 57 | −2 920 226 € | −2 000 € | 9 120 000 € | 5 400 000 € | 960 000 € |
| S1W2 → W3 | 57 + 0 / 57 | −3 200 226 € | 0 € | 9 120 000 € | 5 040 000 € | 1 040 000 € |

**Les 171 observations club-semaine IA sont réconciliées : 167 à payroll stable et quatre par ordre source vérifié et replay de la fonction réelle.** Les quatre ajouts concernent les clubs 14/25/27 en W0, puis 25 en W1. Leurs payrolls augmentent respectivement de 2000/4000/2000 puis 2000 €, avec cinq joueurs anonymisés ajoutés à 2000 €/semaine. Les résidus avec le payroll d'ouverture sont exactement l'opposé de ces hausses ; avec le payroll effectivement présent à la facturation, ils sont nuls. Les trois replays de facturation retrouvent chacun les 57 deltas IA réels. Cette réception n'autorise pas le même raccourci pour une fenêtre de recrutement ou l'intersaison.

Les trois variations humaines, toutes réconciliées au ledger, sont +198330, −154670 et +102330 €. Les partenaires sont 160000 €/semaine et les salaires 394670 €/semaine. Les billets observés sont 433000, 0 et 337000 €, la prime de victoire 0, 80000 et 0 €. L'entretien observé est zéro, les installations restant au niveau initial 2. Ce run ne mesure pas un entretien non nul ou un investissement ; le test pur couvre un niveau 3 et un résidu non expliqué.

## Contre-factuel isolé et absence de double versement

Une copie du premier checkpoint et de ses vrais résultats est chargée dans le vrai bootstrap Monde. Deux VM isolées exécutent la fonction de production `worldWeeklyEconomy`, avec mêmes état, résultats et graine. Une seule différence est introduite dans la seconde copie : +1000 € de salaire hebdomadaire pour un joueur IA du club 1.

Résultat reçu : **−1000 € exactement de variation supplémentaire de cash**. Après normalisation de ce salaire et de ce cash, les deux états entiers sont égaux. Les historiques, rencontres et match courant n'ont pas changé ; aucun appel au RNG n'a été consommé. Réappeler la fonction avec la même clé saison/phase/semaine renvoie false et conserve exactement cash, ledger, état et RNG, dans les deux variantes. Cette preuve concerne le garde de `worldWeeklyEconomy`, pas une prétendue idempotence globale de `financeWeek` ou d'une commande qui avance à la semaine suivante.

Il s'agit d'un contre-factuel financier sur copies isolées, pas de deux simulations sportives. Le profil réel n'est pas modifié. Le supplément de salaire n'est pas introduit dans les carrières utilisées pour la réconciliation.

## Validation et limites

Trois tests Node 22 réussis, zéro échec/ignoré, environ cinq secondes. La suite couvre la semaine réelle et les invariants du contre-factuel, ainsi qu'un résidu artificiel de 999 € qui doit rester unknown, un changement de payroll et le refus d'une transition d'intersaison. Elle interdit également l'explication par couverture hors de la fenêtre prouvée, avec un événement payant ou un résidu non nul. Un premier essai de configuration de la VM avait omis `nativeWorldRegistryText` ; il a été corrigé avant réception et n'est pas une panne du moteur.

Le journal `passed:true` signifie que les commandes et assertions du banc ont terminé ; il n'autorise pas à masquer une ligne unknown dans un autre relevé. Dans cette réception, les résidus finaux sont nuls ; les résidus d'ouverture restent affichés pour montrer les ajouts de couverture. Aucun montant n'est extrapolé sur dix saisons à partir de ces trois semaines. Les transferts, commissions, primes d'intersaison, dettes, investissements, clubs dans des éditions étendues et autres graines demandent une réception dédiée. Ce résultat ne démontre ni l'équilibrage global ni un double versement historique. Il fournit une première réconciliation réelle et un témoin causal exact sur le coût salarial.
