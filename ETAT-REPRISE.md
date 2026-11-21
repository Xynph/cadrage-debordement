# Reprise : onglet Contrats (branche claude/effectif-contrats-visuel, PR #1083 ouverte, auto-merge squash)

## Fait
- #1083 (déjà poussée) : tableau proportionnel, phrases d'aide retirées, pastille Staff, tuiles Proposés/Offres/Ventes, prolongation en icône.
- Dans le dernier commit wip (non poussé en PR séparée, même branche) : couleurs franches (orange/vert/bleu/citron/rouge), tuiles du haut
  en boutons teintés avec icône, barres Échéances par année colorées et cliquables (filtre de l'année), couverture des postes colorée + pastille « N au-delà »,
  pastille départs cliquable (Recrutement > offres), pastille Staff cliquable (écran Staff), icône prolongation cliquable (fiche joueur, section contrat),
  tuile salaires -> Finances > Salaires, tuiles 8/36 et 21 -> filtres. Icônes ajoutées dans icon-paths.json (renew, lock, hourglass).
- Test ajouté : `clics_et_destinations()` dans tests/godot-contract-review.gd (vert avant le dernier réglage de hauteur des barres).

## Reste à faire
- Dernière capture 1920 + 1280 après le correctif `link.custom_minimum_size.y = 34` des barres (le rendu précédent montrait les lignes « Échéances par année » écrasées et chevauchant « Couverture »). Vérifier à l'œil.
- Relancer `godot-contract-review`, `godot-prolongations-staff`, `godot-prolongations-staff-carriere` (vertes avant ce dernier réglage).
- Léo : une petite fenêtre visuelle est permise pour un clic (pas de bloc de texte) ; ici tout mène à un écran ou un filtre, à revoir si besoin.
- Merge origin/main avant de passer la PR à jour ; `git checkout -- native/godot/art/office_props/ballon.glb.import`.
- godot-vente-joueurs échoue déjà sur origin/main (ne pas corriger).

## Commandes
- Capture : `. E:\Cadrage-Debordement\environnement.ps1; scripts/ecrans-filmes.ps1 -Sortie E:\Cadrage-Debordement\temp\contrats-1920 -Tailles '1920x1080,1280x720' -Ecrans effectif-contrats -SansDirect -SansPlanche -AttenteGodot 40 -Godot $env:CD_GODOT_EXE -Node E:\Cadrage-Debordement\outils\node.exe` (relancer en boucle : refuse si un autre Godot tourne).
- Tests : `powershell -File E:\Cadrage-Debordement\temp\godot-slot.ps1 -Dossier <worktree> -Commande "E:\Cadrage-Debordement\outils\node.exe tests/<suite>.cjs"`.
- Push : git -c credential.helper= -c "credential.helper=!'E:/Cadrage-Debordement/outils/verification-20261108/gh/bin/gh.exe' auth git-credential" push.

## Pièges
- Une capture dont le PNG ne change pas = le lanceur a refusé (autre Godot) ; vérifier l'heure du fichier.
- Erreur de type GDScript = écran vide ; chercher « SCRIPT ERROR » dans godot.log.
- Hors mode Monde, pas de pastille Staff (test conditionnel).
