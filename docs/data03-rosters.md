# DATA-03 — Première collecte exhaustive des pages Effectif & staff LNR

## Données réellement récupérées le 31 octobre 2026

**30/30 pages de clubs couvertes** : 14 clubs TOP 14 et 16 clubs PRO D2, quatre fichiers JSON :
- `modding/data03/top14-a.json` — 336 fiches
- `modding/data03/top14-b.json` — 469 fiches
- `modding/data03/prod2-a.json` — 411 fiches
- `modding/data03/prod2-b.json` — 376 fiches

**1 592 fiches de joueurs recensées**, 1 592 IDs LNR uniques. Champs : `id` joueur (LNR numérique préfixé), nom, lien profil individuel, club et URL page d'effectif, championnat, date de collecte.

**Contrôle exécuté contre les quatre fichiers relus depuis GitHub :** 30 clubs, 805 TOP 14 + 787 PRO D2, zéro URL/nom/ID invalide et zéro ID de joueur présent dans deux clubs. Des contrôles exécutables sont ajoutés dans `tests/data03-rosters.cjs` pour reprise en CI.

## Prudence indispensable sur les dates

Les pages sont **l'état affiché le 31/10/2026**, et **ne démontrent pas** que chaque joueur était présent au `01/07/2026` (date de début d'une carrière). Les données collectées sont une **photographie des listes LNR**, à recouper avec les transferts et départs datés (PR #119), notamment pour les prêts. `historicalAsOfJuly1Verified: false` est volontairement conservé.

## Limites et prochaine étape

Il reste à extraire **poste précis et éventuels autres postes, date de naissance, nationalité, mensurations**, et **entraineurs/staffs** des fiches individuelles officielles ; à distinguer joueurs pros et Espoirs quand la source le prouve ; à valider les transferts, contrats, budgets (uniquement publications authentifiées), joueurs retirés et nouvelles arrivées.

**Aucun joueur imaginaire, rémunération ou budget non sourcé n'a été inventé.** Les noms et URLs publics sont référencés ; aucune photo ni logo téléchargé ou embarqué.

Ces fichiers ne sont **pas encore branchés** au moteur de jeu : le mod Rugby Réel reste optionnel et non jouable à ce stade. Aucun `dist/**` ni sauvegarde n'est modifié. La date d'ouverture des nouvelles carrières reste le 1er juillet 2026.

Sources : pages officielles `https://top14.lnr.fr/club/<slug>/effectif-staff` et `https://prod2.lnr.fr/club/<slug>/effectif-staff`.
