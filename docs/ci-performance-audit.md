# Audit de débit de livraison — 3 novembre 2026

## Échantillon vérifié

20 dernières PR numérotées de #251 à #270 : **14 fusionnées et 6 non fusionnées** au moment du relevé GitHub. La durée mesure uniquement **création de la PR → fusion**, et non le développement préalable, la CI post-fusion ou la qualité du résultat.

Pour les 14 PR fusionnées, médiane **16,5 minutes** (arrondie), minimum **6 minutes**, maximum **16 h 15 min**. Trois PR longues, #255, #256, #258, dépassent 15 heures. Les lots MATCH 3D #263–#270 (hors #269, non fusionnée) se situent entre environ 6 et 19 minutes : éviter d'affirmer qu'une CI uniforme est le principal goulot sans chronométrage détaillé.

## Reproduire

Exécuter `node ci/pr-leadtime.cjs` avec `gh` connecté en **lecture seule**. Option `--json` pour récupérer les données. Le script prend les 20 PR les plus récentes par numéro parmi les 100 dernières créées. La médiane ne porte que sur les PR fusionnées, et les PR encore ouvertes sont reportées à part : biais de sélection assumé.

## Audit technique du gate

Le fichier `ci/chat-release.cjs` exige, pour le déclenchement par commentaire, un auteur propriétaire authentifié sur #73, une commande stricte `/cd-check` ou `/cd-merge` avec SHA, une CI main complète sur son SHA exact, et une CI PR valide via `ci/release-gate.cjs`. Une branche auto-autorisée existe côté fonction `execute`, mais cela ne prouve PAS qu'un déclencheur automatisé sûr est effectivement activé. **Ne pas retirer les contrôles ni utiliser directement l'API GitHub de fusion.**

## Plan d'optimisation, par ordre de risque

1. **Mesurer** les délais PR, CI par workflow, attente entre CI verte et gate, et durée de CI post-fusion sur 20 livraisons (les derniers indicateurs exigent des données Actions supplémentaires).
2. **Automatiser le déclencheur du gate** dans une PR sécurité distincte, sur code de `main` seulement, avec identité vérifiée, SHA immuable, anti-concurrence et tests négatifs. Le gate doit rester unique source de fusion.
3. **Regrouper les changements en lots fonctionnels cohérents** sans grossir inconsidérément les PR sensibles.
4. **Élaguer les documents historiques contradictoires** dans une PR séparée, après contrôle des réservations.
5. Comparer ensuite médiane et P90 avant/après, en suivant aussi les échecs post-fusion, la compatibilité des sauvegardes et la valeur jouable.

Aucune modification du gate, des permissions, de la CI obligatoire ou des protections de `main` dans ce premier lot de mesure.
