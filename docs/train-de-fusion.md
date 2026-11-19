# Fusion rapide (19/11/2026) et train de fusion (18/11/2026)

## Fusion rapide

Décision de Léo du 19/11/2026 : gagner du temps. Voie par défaut :

1. PR en brouillon (CI légère), passation dans la description.
2. Prête : passer la PR en prête et activer la fusion automatique en squash. La CI de la PR
   tourne en **mode rapide** : suites JS de poids ≤ 60 s, suites Godot de poids ≤ 20 s (si le
   diff touche Godot) et toutes les suites modifiées par la PR (`ci/shard-tests.cjs`,
   `CD_RAPIDE`). ~10 min au lieu de 35-40. Étiquette `batterie-complete` : batterie complète
   pour cette PR. Les PR du train (`train/*`) passent toujours la batterie complète.
3. Chaque heure (`tests.yml`, schedule `41 * * * *`), la batterie complète (10 runners JS +
   5 Godot, ~20 min) vérifie `main` ; sautée si ce commit a déjà une batterie horaire verte.
4. Rouge : `main-rouge.yml` relance une fois les seuls jobs en échec ; toujours rouge, il poste
   « MAIN ROUGE » sur #591 (cause : délai dépassé ou assertion, PR fusionnées depuis la dernière
   batterie horaire verte) et, si une seule PR est en cause et que main n'a pas bougé, ouvre sa
   PR de retour arrière avec fusion automatique. Plusieurs PR : pas de retour arrière
   automatique ; corriger main avant toute autre fusion.

Risque accepté : un bug attrapé seulement par une suite longue peut rester jusqu'à une heure sur
main. Poids des suites recalculés le 19/11 sur 8 runs verts (`ci/suite-weights.cjs`, à refaire
quand l'équilibre des shards se dégrade).


## Pourquoi

Le dépôt appartient à un compte personnel : la file de fusion native de GitHub (qui
regroupe les PR) n'y existe pas. Chaque PR prête lançait sa propre batterie complète
(~11 jobs de 15 à 25 min) ; à 5 PR en parallèle, on dépassait la limite de 20 jobs
simultanés du compte gratuit et tout attendait.

## Comment s'en servir (agents)

1. Ouvrir la PR **en brouillon** (CI légère : 2 jobs < 1 min) et écrire la passation.
2. Quand elle est prête : poser l'étiquette **`train`**. Ne pas la passer en prête, ne
   pas activer la fusion automatique.
3. C'est tout. Le train part dès que l'étiquette est posée (s'il roule déjà, il
   repart juste après), et toutes les 20 minutes en secours (ou à la main : Actions →
   « Train de fusion » → Run workflow) ; il commente la PR, la ferme une fois fusionnée
   et poste `FUSIONNÉ` sur #591.

Si la PR reçoit **`train-echec`** : lire le commentaire du train (conflit, batterie rouge
avec le lien), corriger, retirer `train-echec` et reposer `train`.

## Ce que fait le train (`.github/workflows/train-de-fusion.yml`, `ci/train-de-fusion.sh`)

1. Prend jusqu'à 6 PR ouvertes vers main étiquetées `train` (les plus anciennes d'abord).
2. Construit `train/<date>-<n>` = main + squash de chaque PR, dans l'ordre. PR en conflit,
   vide, ou qui modifie `.github/workflows/` (le jeton du dépôt ne peut pas les pousser) :
   retirée avec `train-echec` et un commentaire.
3. Ouvre aussitôt la PR « Train de fusion … » (si GitHub refuse, le train s'arrête en
   une minute au lieu d'attendre la batterie). Cette PR déclenche elle-même la batterie
   complète `tests.yml`, avec les règles d'une PR ordinaire ; repli en
   `workflow_dispatch` si aucune exécution n'apparaît. Une seule batterie pour le lot.
4. Vert : fusionne la PR du train **en rebase** (un commit `titre (#n)` par PR, auteur
   d'origine conservé), ferme les PR d'origine, supprime leurs branches, poste
   `FUSIONNÉ` sur #591 et relance la recette Windows RTX (les fusions par le jeton du
   dépôt ne déclenchent pas les workflows « push sur main »). Si GitHub refuse quand
   même la fusion, la PR du train reste ouverte pour une fusion à la main.
5. Rouge : reteste la première moitié du lot. Verte, elle est fusionnée et le reste
   attend le train suivant ; rouge, on recoupe, jusqu'à une PR seule qui passe en
   `train-echec`.

Prérequis : secret **`TRAIN_TOKEN`** (Settings → Secrets and variables → Actions) = jeton
personnel *fine-grained* limité à ce dépôt, permissions Contents, Pull requests, Issues et
Actions en lecture/écriture (Metadata en lecture), validité 90 jours — à renouveler avant
l'échéance. Sans lui le train s'arrête avec un message clair. Ni le ruleset ni `tests.yml`
ne changent.

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
- 18/11/2026 : 1er passage — batterie verte, création de la PR du train refusée (réglage
  ci-dessus, coché ensuite). 2e passage — PR créée, mais la batterie déclenchée par la PR
  elle-même rendait « Validation CI » en attente : la fusion lancée sur la batterie
  séparée était bloquée. Correctif : la PR du train est ouverte d'abord et sa propre
  batterie fait foi.
- 19/11/2026 : fusion de la PR du train refusée avec le jeton du dépôt (CI de la PR en `action_required`) ; passage au jeton personnel `TRAIN_TOKEN`.
- 19/11/2026 : 6e passage — test avec le jeton personnel.
