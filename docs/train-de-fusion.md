# Train de fusion (18/11/2026)

## Pourquoi

Le dépôt appartient à un compte personnel : la file de fusion native de GitHub (qui
regroupe les PR) n'y existe pas. Chaque PR prête lançait sa propre batterie complète
(~11 jobs de 15 à 25 min) ; à 5 PR en parallèle, on dépassait la limite de 20 jobs
simultanés du compte gratuit et tout attendait.

## Comment s'en servir (agents)

1. Ouvrir la PR **en brouillon** (CI légère : 2 jobs < 1 min) et écrire la passation.
2. Quand elle est prête : poser l'étiquette **`train`**. Ne pas la passer en prête, ne
   pas activer la fusion automatique.
3. C'est tout. Le train passe toutes les 20 minutes (ou à la main : Actions →
   « Train de fusion » → Run workflow) ; il commente la PR, la ferme une fois fusionnée
   et poste `FUSIONNÉ` sur #591.

Si la PR reçoit **`train-echec`** : lire le commentaire du train (conflit, batterie rouge
avec le lien), corriger, retirer `train-echec` et reposer `train`.

## Ce que fait le train (`.github/workflows/train-de-fusion.yml`, `ci/train-de-fusion.sh`)

1. Prend jusqu'à 6 PR ouvertes vers main étiquetées `train` (les plus anciennes d'abord).
2. Construit `train/<date>-<n>` = main + squash de chaque PR, dans l'ordre. PR en conflit,
   vide, ou qui modifie `.github/workflows/` (le jeton du dépôt ne peut pas les pousser) :
   retirée avec `train-echec` et un commentaire.
3. Lance `tests.yml` en `workflow_dispatch` sur cette branche : batterie complète,
   Godot obligatoire. Une seule batterie pour tout le lot.
4. Vert : ouvre la PR « Train de fusion … », la fusionne **en rebase** (un commit
   `titre (#n)` par PR, auteur d'origine conservé), ferme les PR d'origine, supprime
   leurs branches, poste `FUSIONNÉ` sur #591 et relance la recette Windows RTX (les
   fusions par le jeton du dépôt ne déclenchent pas les workflows « push sur main »).
5. Rouge : reteste la première moitié du lot. Verte, elle est fusionnée et le reste
   attend le train suivant ; rouge, on recoupe, jusqu'à une PR seule qui passe en
   `train-echec`.

Le contrôle obligatoire « Validation CI » du ruleset est satisfait par la batterie
lancée sur le commit exact de la PR du train : ni le ruleset ni `tests.yml` ne changent.

## Limites connues

- PR qui touchent `.github/workflows/` : fusion classique (prête + fusion automatique).
- Les recettes non obligatoires lancées au passage en prête (UI Chromium, étiquettes
  `windows-*`, `godot-sdk`) ne tournent pas sur un brouillon : poser l'étiquette voulue
  si la PR en a besoin.
- Un test instable peut faire rougir un lot : la dichotomie coûte alors une ou deux
  batteries de plus.
- Le planning `schedule` de GitHub peut prendre du retard : lancer le train à la main
  si c'est pressé.
- La fusion classique (prête + fusion automatique) reste possible et prime pour un
  lot sensible ou urgent.

## Historique

- 18/11/2026 : mise en service ; premier passage réel avec une PR documentaire (#935 fusionnée).
