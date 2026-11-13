# Mesurer la progression avant de changer ses coefficients

Ce banc manuel compare deux politiques déterministes de gestion, avec **trois graines annoncées avant les résultats : 827381, 318 et 52602**, club 0 en mode `world-champ`, deux saisons jouées par bras. Chaque paire commence avec la même graine, la même horloge de carrière et le même état initial. Cela ne signifie pas que les trajectoires sportives ou le curseur RNG doivent rester identiques après des décisions différentes.

## Reproduction et portée

```bash
node ci/progression-multiseed-audit.cjs --seed 827381 --policy minimal --out /tmp/progression-827381-minimal.json
node ci/progression-multiseed-audit.cjs --seed 827381 --policy attentive --out /tmp/progression-827381-attentive.json
node --test tests/progression-multiseed-audit.cjs
```

Répéter les deux bras pour 318 et 52602, sans choisir une graine après examen des résultats. Chaque exécution est indépendante et peut tourner en parallèle avec les autres graines. Le budget par défaut est de vingt minutes par bras (`--budget-ms`). Une sortie déjà existante est refusée. Les profils sont temporaires et supprimés après la réception ; en cas d'échec, le rapport partiel et un profil synthétique `.failure-profile.json` sont conservés à côté du rapport. Cette version ne prétend pas reprendre automatiquement un contrôleur interrompu : relancer le bras entier dans un nouveau fichier garantit sa mémoire de décisions initiale.

Les longues campagnes ne tournent pas dans la CI générale. Les cinq tests courts vérifient le protocole, les comptes du journal, la séparation des informations visibles, le suivi de cohortes et les arguments. Aucun score, résultat, qualification, joueur ou coefficient de progression n'est injecté.

## Politiques annoncées

Les profils et leurs critères exacts sont dans `ci/progression-policies.cjs`, dont le hash est enregistré dans chaque rapport. `minimal` maintient la jouabilité via le sélecteur et, si nécessaire, la promotion publique confirmée. `attentive` ajoute un renouvellement sélectif borné : six candidats par saison, choisis avec les notes, potentiels estimés, âges, contrats et coûts visibles, sous une réserve de trésorerie fixée avant la campagne. Ce bras mesure cette intervention précise ; son nom ne représente pas toutes les formes possibles d'une bonne gestion.

Les politiques reçoivent uniquement une copie immuable du modèle effectivement visible par le client, privée de `meta.exportText`. Les exports complets servent aux mesures, jamais aux décisions. Les seules commandes de politique autorisées sont celles publiées par le module de politiques ; import, création, export, simulation et modification arbitraire d'état sont interdits aux contrôleurs. Le banc exécute séparément les commandes publiques du parcours de carrière. Chaque phase suit la borne de **16 actions**, identique dans les deux profils ; elle n'est pas tronquée silencieusement. Toute erreur critique de politique arrête le bras avec un rapport d'échec. Une réponse technique `ok` ne prouve pas une signature : les reçus de négociation distinguent notamment `counter` et `signed`.

## Points, sources et conservation

Cinq observations distinctes sont requises : ouverture S1, fin S1, ouverture S2, fin S2 et ouverture S3. Il y a **deux saisons jouées et deux transitions**, pas trois saisons jouées. Les réouvertures de fin S1, fin S2 et d'ouverture S3 comparent exactement l'export public et les octets du profil privé, contenant le RNG, l'horloge et le store.

Chaque bras enregistre le commit, l'empreinte des fichiers moteur/core, les hashes du banc et des politiques, l'état et le profil initiaux, les actions publiques, refus, reçus de négociation, points de passage et durée réelle. Le contrôle final refuse des sources modifiées en cours d'exécution. Les six rapports d'une comparaison doivent donc provenir de la même méthode figée et des mêmes sources. Les hashes initiaux doivent correspondre à l'intérieur de chaque paire, sans exiger leur égalité entre graines différentes.

## Mesures séparées

- **Sport :** championnat courant, rang, taille de ligue, percentile normalisé, points et différence de score par match. Les deux bras peuvent changer de compétition ou de classement ; ne pas comparer leurs points bruts sans ce contexte. Le marqueur `unresolvedTie` conserve les égalités non résolues : un rang de jeu provisoire n’est pas présenté comme un départage officiel. Aucun score composite de « meilleure gestion » n'est créé.
- **Effectif :** taille actuelle, salaires hebdomadaires fictifs, distribution des âges et des niveaux bruts de simulation, note moyenne au poste naturel des quinze titulaires réellement sélectionnés (ni note au poste joué ni force optimale du XV), validité de la feuille du modèle. Cette dernière n'est pas une certification officielle des inscriptions ou habilitations.
- **Cohorte fixe :** tous les IDs professionnels présents à l'ouverture S1 sont suivis parmi les clubs, académies et viviers. Le statut distingue toujours propre club, autre professionnel, académie, agent libre, marché, retraite ou identité non retrouvée. Les niveaux inconnus restent `null`. Les groupes d'âge sont fixés par l'âge initial (≤23, 24–29, ≥30) ; les départs ne sont pas retirés silencieusement pour embellir une moyenne des survivants.
- **Finances :** le stock de trésorerie n'est jamais appelé revenu. Chaque période financière couvre **ouverture d'une saison → après sa transition**, avec clôture sportive et après-gestion également séparés. Salaires, partenaires, billetterie, entretien/amortissement, primes, financement, contrats, transferts, investissements et autres écritures sont distincts. Le financement de 2,5 M€ est séparé de l'exploitation. Une dette non visible vaut `null`, jamais zéro inventé.

Les nouvelles entrées du journal sont détectées par recouvrement ordonné, en conservant les répétitions. Le journal est borné et n'a pas d'identifiant par écriture : toute variation de cash non réconciliée est conservée dans `unexplainedCash`, pas inventée comme revenu. La conservation vérifiée est `cashAfterTransition − cashOpening = somme(categories) + unexplainedCash`. Les minima de cash portent sur les commandes observées ; les semaines négatives et leur plus longue série portent sur les semaines de gestion 0–45.

L'analyse finale doit montrer les trois paires brutes et la médiane ainsi que l'étendue des écarts, sans sélectionner la graine favorable. Trois graines et deux saisons ne permettent pas une affirmation de significativité, une causalité générale sur toute gestion, ni une calibration économique à dix saisons. Les coefficients restent inchangés jusqu'à examen des résultats et de leurs limites.
