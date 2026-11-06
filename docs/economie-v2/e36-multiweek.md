# Économie V2 E3.6 — quatre semaines natives appariées et scores observés

## Contrat expérimental

PR empilée sur E3.5 (#357) ; R&D exclusivement, aucun moteur ni sauvegarde utilisateur modifié. Deux copies d'une **même sauvegarde native et du même RNG** sont comparées durant quatre cycles natifs consécutifs par configuration. Chaque cycle exécute vraiment `trainWeek()` et `finishRound()` dans les DEUX bras. Les trois variantes : installation activée vs aucune, formation à 4 000 vs zéro, formation à 12 000 vs zéro.

Observations détaillées `weekIndex` et `startingRound` : trésorerie et dépense réelle via le registre natif et `academySpent`, différence de notes et `dev.xp` des joueurs communs par ID, nombre de joueurs perdus de vue, points / victoires / scores cumulés réellement enregistrés par le moteur, état et nombre d'appels RNG dans chaque bras. Une différence de match est un **écart observé**, jamais une garantie ni une causalité établie si les états ou séquences d'aléatoire divergent. La première divergence RNG est rapportée ; un RNG encore aligné n'établit pas que les résultats ultérieurs seront identiques.

**Précision chronologique :** amélioration d'installation payée = événement à la saison seulement. Formation = `season:economy.week` dans le moteur ; `startingRound` est le tour du test, sans inventer de date civile ni d'échéance.

**Limites :** quatre semaines ≠ quinze saisons appariées ; la campagne 6×15 héritée d'E3.5/E3.4 assure seulement la non-régression native et la parité des anciennes sauvegardes. `crossSeasonEffect=null`, `guaranteedSportOutcome=null`, dettes historiques créées = zéro. Aucun passif induit par une simple sélection d'investissement. Les différences peuvent mêler effet financier, progression, sélection, et hasard ; les constats de match ne sont pas un estimateur causal de rendement sportif.

## Qualification
Six jobs : trois clubs × deux graines ; par job trois expériences de quatre semaines chacune (24 tours-bras) + quinze saisons natives de non-régression, trois imports, comparaison état/checksum et RNG de la source inchangée, tests ciblés. GitHub Actions doit être terminal `SUCCESS` sur SHA exact avant toute qualification ; archives JSON à contrôler. L'histoire du registre natif est bornée, ne pas la déclarer exhaustive.

## Exclusions
Aucun fichier `dist/`, E1–E3.5, `main`, sauvegarde, PRODUCTEUR, MATCH 3D en pause, DATA/LNR ou gate modifié. Aucune promotion READY, /cd-check, /cd-merge ni fusion.
