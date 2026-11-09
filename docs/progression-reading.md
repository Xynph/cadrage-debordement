# Lire les comparaisons de progression sans fabriquer un vainqueur

`ci/progression-summary.cjs` agrège les six rapports individuels du banc `ci/progression-multiseed-audit.cjs`. Il s’agit d’une lecture descriptive et appariée, pas d’un réglage des coefficients ni d’une notation générale des stratégies.

## Matrice préannoncée

- Graines **827381, 318, 52602**, toutes rapportées.
- Politiques **minimal** et **attentive**, profils et code identiques pour une politique entre les graines.
- Deux saisons jouées par bras, puis deux transitions : captures `initial`, `end-S1`, `opening-S2`, `end-S2`, `opening-S3`. L’ouverture de S3 n’est pas une troisième saison jouée.
- Même état initial et même profil privé par paire de graine. Le simple partage d’un numéro de graine ne remplace pas cette vérification.
- Les trois différences par graine restent visibles. Aucun meilleur seed n’est choisi après les résultats ; aucun test de significativité, intervalle de confiance, probabilité de réussite ou classement universel n’est calculé à partir de ces trois graines.

La synthèse refuse toute matrice incomplète. Les fichiers en cours ou en échec restent les preuves individuelles du banc, mais ne peuvent être passés pour une conclusion multigraines réussie.

## Reproduction et contrat

```bash
node ci/progression-summary.cjs \
  /tmp/827381-minimal.json /tmp/827381-attentive.json \
  /tmp/318-minimal.json /tmp/318-attentive.json \
  /tmp/52602-minimal.json /tmp/52602-attentive.json > /tmp/progression-summary.json
# Les mêmes six fichiers, précédés de --markdown, produisent le bilan lisible.
node --test tests/progression-summary.cjs
```

La CLI lit les six fichiers et écrit seulement sur stdout. Elle n’ouvre ni profil, worker, navigateur ni réseau, et ne modifie aucun rapport d’entrée. Une entrée JSON tronquée, un fichier manquant ou une incohérence donne le code de sortie1 avec un message bref, sans chemin local ni pile d’erreur. Les exports `summarize(reports)`, `validateIndividual(report)`, `distribution(values)` et `markdown(summary)` permettent une utilisation pure depuis d’autres outils.

Schéma accepté : `progression-multiseed-audit-v1`. La validation exige état `completed`, `passed:true`, `reopened:true`, deux saisons complètes, cinq captures aux dates prévues, deux relevés annuels, deux périodes financières et trois reprises exactes `end-S1`, `end-S2`, `opening-S3`. Les nombres de résultats et de fixtures doivent correspondre pour chaque saison. Les IDs de joueurs et les cohortes initiales ne peuvent être dupliqués ou silencieusement omis.

Commit, digest du moteur, hash du runner et hash du fichier de politiques doivent être identiques dans les six bras. La signature de politique correspond au hash de son code source ; son profil ne peut changer entre graines. Les hashes d’état initial, de profil initial et les observations initiales doivent être identiques entre les deux bras d’une graine. Les trois reprises attestent conservation publique et privée. Cette cohérence des reçus n’est pas une signature cryptographique d’un tiers : elle ne rend pas authentique un rapport fabriqué manuellement.

## Sport et qualité de jeu

Les rangs et points ne sont comparés que pour le même club, la même division, la même taille de ligue et le même point de capture. Les promotions/changements de division restent visibles avec une comparaison de rang non applicable. Un classement encore non départagé ne devient pas un rang certain : son delta de rang vaut `null`, tandis que les points de la même division restent comparables. Une valeur numérique plus petite du rang signifie seulement un rang mieux placé ; aucune somme de rang, cash et note ne produit un score global.

La note du XV est la **moyenne des notes naturelles des quinze titulaires réellement sélectionnés**. Ce n’est ni la force optimale de l’effectif ni une note recalculée au poste occupé. La validité de la feuille à23 est la validité du jeu, pas une certification EPCR ou de première ligne.

### Convention des médianes : harmonisation de lecture annoncée avant les résultats agrégés

Le runner figé conserve ses quantiles de roster selon la convention **nearest-rank** : pour `[50,60]`, son p50 vaut50. Cette méthode et les trajectoires restent inchangées. L’agrégateur vérifie les q25/p50/q75 sources à partir des joueurs bruts selon cette convention ; ils sont conservés sous `sourceRatingQuantiles.p50NearestRank` et `sourceAgeQuantiles.p50NearestRank`.

Les comparaisons uniformes de médiane sont **recalculées depuis les valeurs brutes** avec la médiane standard, moyenne des deux valeurs centrales si l’effectif est pair : `[50,60]` donne55. `rosterMedianRatingDelta`, les distributions descriptives et les changements individuels utilisent cette lecture standard. Le p50 source n’est donc jamais comparé à55 comme s’il s’agissait de la même métrique. Ce choix d’harmonisation est indépendant de l’effet observé d’une politique et ne change ni moteur, ni politiques, ni runs.

## Joueurs et biais de survivants

La cohorte est fixée aux IDs présents à l’ouverture de S1. Les groupes d’âge viennent de leur âge **initial** : jusqu’à23 ans, 24–29 ans, au moins30 ans, inconnu. Le vieillissement ne déplace pas un joueur entre ces cohortes.

Pour chaque capture, la synthèse distingue joueurs retenus dans l’effectif, sortants, entrants, joueurs retrouvés ailleurs, retraités et non retrouvés. Les changements de rating/note des seuls retenus sont présentés comme un sous-ensemble de survivants, avec son nombre. Les ratings initiaux suivis ailleurs sont conservés quand ils sont connus. Les retraités et joueurs non suivis ont une observation manquante, jamais une note zéro imputée. La propriété `own` des traces doit correspondre à leur présence réelle dans le roster capturé.

Les mêmes IDs connus dans les deux bras sont également appariés par graine et âge initial. Le nombre comparé et le nombre inconnu restent explicites. Les distributions d’un ensemble de joueurs ne constituent pas autant de répétitions indépendantes de l’expérience : il n’y a toujours que trois graines.

## Trésorerie, dette, salaires et interventions

Cash est un **stock de trésorerie**, pas un revenu, un profit ou une preuve de succès. Dette inconnue vaut `null`, sans être transformée en zéro. Les salaires hebdomadaires restent une mesure distincte. La comparaison des stocks est suspendue si les politiques ne gèrent plus le même club.

Les catégories financières séparent notamment salaires, entretien, partenaires, billetterie, primes, financement annuel, frais contractuels, transferts, investissements et autres flux. Les catégories plus le résidu inexpliqué doivent reconstituer `cashAfterTransition - cashOpening` (tolérance monétaire1e-6). La clôture sportive `cashClosing` ne remplace pas le stock après gestion puis transition. Les endpoints du relevé doivent correspondre aux captures du runner. Le registre de flux est capturé pendant les commandes ; on ne reconstruit pas92semaines depuis un ledger final borné.

Le minimum de cash, les semaines négatives et leur plus longue série restent descriptifs. Un financement de début de saison n’est pas de l’exploitation. Si aucune semaine n’est négative, le redressement financier n’a pas été exercé. Si elle l’est, ces champs agrégés ne prouvent pas un retour durable et autofinancé ; `recoveryAssessment` le laisse non établi. Aucune vente, emprunt ou restructuration non exécutée par les politiques n’est attribuée aux trajectoires.

Les requêtes API sont comptées séparément en acceptations et refus, par politique et commande. Une acceptation d’offre n’est pas une signature : seules les réponses `ok:true`, commande `extend_contract`, `negotiation.status:'signed'` comptent comme contrats signés et primes réellement engagées. Les contre-offres sont comptées à part ; leur prime proposée n’est pas additionnée aux paiements signés. Ces totaux sont vérifiés contre `policySummary`. Une signature réellement reçue ne démontre pas à elle seule un gain sportif causal.

## Qualification

Treize tests courts sous Node22 : matrice complète et non-mutation, rapports absents/tronqués/dupliqués ou hors graines, commits/hashes/profils incohérents, mauvais hashes initiaux, saison/reprise incomplète, comparaison entre divisions, rang non départagé, entrants et cohortes manquantes, absence d’imputation zéro, financement distinct du profit, conservation monétaire, signature contre simple contre-offre, conventions de quantiles validées et médiane standard harmonisée, CLI JSON/Markdown et refus d’un JSON tronqué.

Les fixtures de tests sont synthétiques et ne sont pas des résultats de gestion. La synthèse réelle exige les six trajectoires terminées et compatibles ; aucun pilote isolé n’est présenté comme une expérience multigraines complète. `validateIndividual` contrôle un reçu unique sans le transformer en matrice comparative.

### Premier reçu réel de compatibilité

Les deux reçus individuels terminés de la graine827381, `minimal` et `attentive`, ont passé `validateIndividual` sous Node22.23.4 : cinq captures, deux saisons, deux périodes financières, trois reprises, cohérence des catégories et des signatures. Leurs sources et leurs états initiaux sont compatibles. Cette vérification réelle porte sur **une paire**, sans conclusion multigraines ; le lancement d’une synthèse complète attend les quatre autres bras. Les fixtures unitaires ne remplacent pas ces trajectoires.
