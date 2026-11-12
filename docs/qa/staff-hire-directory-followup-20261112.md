# Recrutement staff : onglet explicite dans la recette

Diagnostic statique de la réception SDK portraits job 130888398043, source commune 37e085b6 : 89 contrôles, six assertions en échec. Le recrutement puis la reprise du devis après refus disque réussissent ; la première absence intervient à la recherche de StaffRenew après signature.

Depuis 47e8a388, `native/godot/ui/staff_career_view.gd` conserve `management_ui.staff.tab`, recherche, page et défilement pour respecter les liens et le retour. `candidates_page()` sélectionne l’onglet 1. Après recrutement, `staff_page(name)` du helper parent ouvre Staff et recherche le nom, mais ne sélectionne pas l’onglet équipe. Le candidat signé disparaît normalement des candidats disponibles : les boutons de prolongation sont donc absents. La recette supposait l’ancien reset implicite de l’annuaire.

Les trois absences de commande attendues correspondent aux deux ouvertures de StaffRenew et à StaffContractConfirm ; l’absence du choix de durée puis les deux assertions de prolongation sont leur cascade. Aucun code de contrat ou de durée n’a changé dans le diff des vues staff concernées.

Le correctif touche uniquement la recette `deepen-staff-hire-ui.gd` : un helper `employed_page` sélectionne explicitement le vrai contrôle StaffCareerTab, onglet 0, avant les deux ouvertures de prolongation. Il vérifie la présence de cet onglet. Le parcours candidats reste explicitement sur 1. Les six assertions existantes, les vrais événements clavier de confirmation, le refus disque, les états exportés et la reprise sont conservés. Aucun reset de lecture produit ni commande métier supplémentaire.

Validation avant réception : `git diff --check` seulement ; aucun Godot, import ni collecte lancé dans ce worktree. L’intégrateur doit confirmer le diagnostic par la recette réelle sous verrou sur le candidat assemblé.

## Invariant audio distinct du défaut d’onglet

Un commit QA séparé ajoute `--audio-driver Dummy` aux wrappers `deepen-staff-real-ui.cjs` et `deepen-staff-hire-ui.cjs`. La recette hire mute le coach immédiatement après l’ajout de chacune des deux instances du client, avant toute attente ou commande. Elle compte les signaux requested/started sur les deux instances, conserve le compteur `_id` du premier client avant sa destruction et vérifie au finish que signaux et identifiants restent à zéro. Aucune commande supplémentaire ; tous les contrôles fonctionnels existants sont conservés.

L’intégrateur peut exécuter le script corrigé avec le produit et les imports du common figé :

```sh
cd /workspace/work/staff-hire-followup
flock /workspace/work/rg27-godot.lock env CD_GODOT_EXECUTABLE=/workspace/work/tools/Godot_v4.7.2-stable_linux.x86_64 CD_STAFF_REAL_ROOT=/workspace/work/night-common /workspace/work/tools/node-v22.23.4-linux-x64/bin/node --test tests/deepen-staff-hire-ui.cjs
```

Même commande avec `tests/deepen-staff-real-ui.cjs` pour la recette de paie/rupture, si réception souhaitée. Les scripts de test viennent du worktree ; scènes produit et cache restent ceux du common. Aucun SDK/import lancé par le producteur.

## Réception root, scripts séparés du produit

Les deux scripts ont été exécutés par root depuis ce worktree à la source tests `e373c8f321bc8b9d95db9c6d897124ba3f60de4a`. Les scènes produit et leur cache provenaient de `/workspace/work/night-common`, exactement `37e085b687b4e9a603085beaa50fecf9d6cace22`, via `CD_STAFF_REAL_ROOT`. Cette réception mixte qualifie les scripts corrigés contre ce produit figé ; elle ne prétend pas être une nouvelle exécution CI ni un produit modifié. Aucun nouveau SDK exécuté pour rédiger ce reçu.

| Recette | Contrôles / échecs | Durée sous-test | Durée TAP | Sortie | Extrait publié |
|---|---:|---:|---:|---:|---|
| Hire : recrutement, refus disque, devis/durées, prolongation, reprise | 104 / 0 | 29,657434 s | 29,724364 s | 0 | [staff-hire.log](receipts/staff-followup-20261112/staff-hire.log) |
| Real : devis, adoption, paie, rupture, refus disque, reprise | 186 / 0 | 41,899808 s | 41,950403 s | 0 | [staff-real.log](receipts/staff-followup-20261112/staff-real.log) |

Mapping des changements reçus :

- `b5145db4aa3840c4bd0c2e5c4f5eb441ddc67d25` : helper test `employed_page` et ses deux appels, sélection explicite de l’onglet équipe après l’onglet candidats conservé. Le défaut initial CI reste consigné : 89 contrôles / 6 échecs en cascade. Aucun changement produit.
- `e373c8f321bc8b9d95db9c6d897124ba3f60de4a` : pilote Dummy explicite dans les deux wrappers ; hire mute les deux clients et vérifie au finish requested/started ainsi que les identifiants `_id` à zéro. Ces compteurs sont contrôlés dans hire uniquement. Pour real, la preuve porte sur le pilote Dummy et les assertions fonctionnelles existantes ; aucun compteur de parole supplémentaire n’est revendiqué.

Les logs publiés contiennent exclusivement les résumés DEEPEN, le JSON checks/failures vide, le nom/succès du sous-test et ses deux durées. Aucune ligne de commande métier, identité individuelle, état exporté, chemin de profil temporaire ni sauvegarde n’est copiée. Les logs complets demeurent chez root : `/workspace/work/night-followup-receipts/staff-hire.log` et `staff-real.log`. Empreintes SHA-256 de ces sources complètes, pour rattachement :

- `staff-hire.log` : `038eea6a3ca0b55f437bca37b536cd6d611013cb2e97f78017180aac8c05f0c4`
- `staff-real.log` : `c4ee11c04035863e2b72c4781555e72880ed908c680b4dc5d7cc3808e27c524c`
