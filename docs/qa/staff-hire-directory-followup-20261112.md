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
