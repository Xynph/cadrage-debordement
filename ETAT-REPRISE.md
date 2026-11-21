# État de reprise : Entraînement › Groupes (option B choisie par Léo)

## Fait (commité sur claude/visuel-entrainement-groupes, partiellement testé, PAS de PR)
- Option A et variable CD_VARIANTE_VISUELLE retirées ; B (anneaux) est l'affichage normal.
- native/godot/ui/anneau_repartition.gd : anneau cliquable par part (palette locale REPOS #4fb3a9, NORMAL #7fbf7a, INTENSIF #e0a04a).
- native/godot/ui/immersive08/training_group_plans.gd : tuiles de plan (fond teinté, icône teintée, pastilles de règles avec texte complet en infobulle, légende cliquable, bouton grisé avec raison en infobulle).
- native/godot/ui/immersive08/training_group_panel.gd : panneau flottant visuel (portraits, nom -> fiche, jauge de condition) pour une part d'anneau ou un poste.
- training_canvas.gd : _groups réécrit, _chart refait (barres charge + condition par poste, seuil 55, zones cliquables -> joueurs du poste), vigilance avec jauge verticale de condition, tuiles du haut cliquables, helper _zone().
- tests/godot-training-groups-clicks.(gd|cjs) : clique chaque élément ; 86 contrôles, 0 échec (avant la refonte du graphique, à relancer).
- tools/ecrans-filmes/visite.gd : écran « entrainement-groupes » ajouté.

## Reste à faire
1. BUG : sur la dernière capture, les barres du graphique « Charge & récupération » ne s'affichent pas (seul le trait de seuil apparaît). Cause non trouvée. Vérifier _chart() : boucle sur FAMILIES, filtre squad par p.fam, deux D.rect par poste. Piste : compter les enfants de TrainingLoadChart dans un petit script de test (un script dbg-chart.gd a été lancé, résultat non lu).
2. En 1280 : un texte tronqué signalé (« Sauvegardé 26/09 », barre latérale, hors de cet écran, sans doute préexistant) ; la fiche Vigilance y montre 2 joueurs (mode dense, normal).
3. Lancer godot-effective-training-receipt et godot-observed-training-consequences (vérifier sur origin/main si un rouge préexiste) ; relancer godot-training-identity-links, godot-training-groups-clicks et godot-ecrans-filmes.
4. Captures 1920 + 1280 dans E:\Cadrage-Debordement\temp\integration-visuel\entrainement\ (regarder le graphique et le panneau de joueurs ouvert).
5. Jetons de charte : attendre la PR Staff (claude/visuel-travail-staff, pas encore ouverte le 21/11) ; ensuite git merge origin/main et remplacer les constantes locales de anneau_repartition.gd par celles de charte.gd (CONDITION, MORAL, CONFIANCE, REPOS, NORMAL, INTENSIF, GAIN, PERTE) ; après 90 min sans fusion, les ajouter soi-même avec ces noms.
6. git merge origin/main, PR prête (titre FR, description courte + choix autonomes, finir par la ligne « Generated with Claude Code »), gh pr merge <n> --auto --squash.

## Destinations cliquables (à rendre à la fin)
Tuiles Condition, Charge moyenne, À surveiller -> Entraînement › Fatigue ; Moral -> Vestiaire ; chaque part d'anneau et chaque ligne de légende non vide -> panneau des joueurs du groupe (nom ou portrait -> fiche) ; part vide : neutre ; barres du graphique -> panneau des joueurs du poste ; joueur de Vigilance : nom/portrait -> fiche (mini-fiche au survol via entity_link), reste de la ligne -> réglage de charge (fenêtre existante conservée : le test identity-links l'exige) ; Appliquer le plan inchangé.

## Commandes utiles
- Lancement Godot : powershell -NoProfile -ExecutionPolicy Bypass -File E:\Cadrage-Debordement\temp\godot-slot.ps1 -Dossier <worktree> -Commande "node tests/godot-training-groups-clicks.cjs"
- Captures : E:\Cadrage-Debordement\temp\cap-groupes2.ps1 (sortie integration-visuel\entrainement ; -AttenteGodot 3300 car ecrans-filmes attend qu'aucun autre Godot ne tourne).
- Poussée : git -c credential.helper= -c "credential.helper=!'E:/Cadrage-Debordement/outils/verification-20261108/gh/bin/gh.exe' auth git-credential" push

## Pièges
- GDScript : « trait » est réservé ; pas de if/else sur une ligne dans un lambda ; typer explicitement (var x: float).
- Après _open_tab ou navigation, la page est reconstruite : ne pas garder de références aux contrôles.
- Machine saturée de Godot : captures et tests peuvent attendre très longtemps.
- Ne pas tuer de processus par motif de chemin du worktree (cela tue aussi le shell).
