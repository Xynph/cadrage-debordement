# Économie V2 E3.7 — saison native appariée, performance et coût d'opportunité

## Gouvernance
R&D uniquement, cinq nouveaux fichiers, PR DRAFT empilée sur #359, réservations #73. Aucun code du jeu `dist/`, sauvegarde, PRODUCTEUR, MATCH 3D (en pause), DATA/LNR, `main` ou gate modifié. La PR parallèle #358 (autre E3.6) demeure totalement inchangée.

## Protocole reproductible
Six configurations (trois clubs × deux graines) exécutent chacune **trois comparaisons de saison entière** : installation contre statu quo, formation à 4 000 € par période contre zéro, formation à 12 000 € contre zéro. Pour chaque comparaison, deux copies d'une seule sauvegarde authentique sont importées par le parseur natif avec le même état de RNG. Les actions et les 29 périodes sont traitées par de vrais `trainWeek()` / `finishRound()` dans chaque bras : 26 journées et trois phases finales. **Les campagnes héritées E3.6 de 15 saisons (six × quinze = 90) sont des tests de non-régression distincts**, et non 90 saisons d'impact causales.

On collecte : dépenses effectivement débitées (installations, formation), périodes natives réellement payées (sans inventer d'échéances), entretien supplémentaire comparé aux écritures native disponibles, évolution des notes et XP *résiduelle* des mêmes IDs de jeunes joueurs, toutes les rencontres impliquant le club piloté, classement de saison régulière, trésorerie finale, synchronisation des flux RNG et première divergence. Les effectifs présents uniquement dans un bras sont signalés, pas imputés comme un progrès.

## Interprétation prudente
Une hausse de note consomme le compteur `dev.xp` : un delta d'XP résiduelle négatif n'est pas un recul du joueur. Les résultats sportifs et les positions mesurés sont des **observations de paires**, pas une estimation causale incontestable : coûts d'opportunité, trésorerie, tactique et aléatoire peuvent modifier le parcours. Si les appels ou états RNG divergent, la comparaison des scores subséquents n'est plus « toutes choses égales par ailleurs ». L'absence de divergence RNG ne prouve pas l'absence d'autres médiateurs.

Le **coût d'opportunité** publié comprend les dépenses réellement payées et l'écart de trésorerie observé en fin de saison, deux variables à ne pas confondre. Les écarts de caisse peuvent comporter salaires, recettes de victoires, billetterie et autres transactions natives. Les dates disponibles sont `season` pour les travaux et `season:economy.week` pour les débits académie. Aucune dette future, revenu garanti ou gain sportif garanti ne peut être induit des devis.

## Qualification et limites
Un job CI par profil/graine : 15 saisons natives de contrôle, 29 × 2 × 3 périodes-bras par configuration pour E3.7, tests Node, parité et roundtrip des sauvegardes de chaque bras, origine/RNG immuables. Artefacts JSON + SHA256 GitHub obligatoires. Résultats à qualifier seulement si CI du HEAD exact `COMPLETED/SUCCESS`. Zéro READY, gate, /cd-check, /cd-merge ou fusion.
