# Entraînement : consulter les personnes sans régler leur charge

Base : `b02452e7f905d43969ad7a564edc6de0b9d8da56`.
Branche : `cloud/rg27-night-training-links-20261111`.

## Inventaire et résultat

Les lignes individuelles possédaient déjà un lien vers la fiche complète avec
`TrainingOpenPlayer_ID`. En revanche, les cartes Axes individuels et Vigilance
ouvraient le réglage de charge jusque sur le nom/portrait, et les cartes du staff
présentaient des identités statiques.

Ce lot ajoute des zones d’identité précises, qui emploient le contrat commun
`open_entity` et son historique. Le nom et le portrait d’un axe ouvrent le joueur ;
le libellé d’axe et le reste de la carte continuent d’ouvrir le réglage existant.
Dans Vigilance, le nom et le poste ouvrent le joueur ; les raisons à droite
continuent d’ouvrir le réglage. Les noms et portraits du staff ouvrent leur profil
par ID publié. Les placeholders sans personne et les IDs absents n’obtiennent
aucun bouton : aucune personne, notamment aucun médecin, n’est inventée.

Le helper de style existant `Fatigue.profile_link` est conservé et délègue à
`entity_profile_link`, identique visuellement mais acceptant une cible typée.
Aucune position, photo, police, charge, mode, seuil 55 ou statut de séance changé.

## Contrôles stables

- `TrainingAxisPlayerName_ID`, `TrainingAxisPlayerPortrait_ID`.
- `TrainingRiskPlayer_ID`.
- `TrainingStaffName_TrainingStaff_ID`, `TrainingStaffPortrait_TrainingStaff_ID`.
- Les mêmes préfixes avec `TrainingStaffCompact` distinguent l’onglet Staff.

Les métadonnées communes `entity_kind` et `entity_id` portent les vrais IDs ;
les suffixes de noms de contrôles sont uniquement normalisés pour Godot.

## Recette préparée, pas encore exécutée

`tests/godot-training-identity-links.cjs` prépare une carrière réelle et utilise
son effectif, ses professionnels et son staff projetés. Le scénario sépare
l’activation clavier du nom, le clic portrait, puis le clic dans la zone de
réglage restante. Il vérifie la fiche complète, le bon ID de staff, le retour,
le refus des placeholders, l’absence de commande/écriture sportive pendant la
consultation, l’état/RNG exportés inchangés et les compteurs de parole à zéro.

La branche Vigilance utilise séparément une fixture du composant : son tableau
`watched` reçoit un vrai joueur projeté sans changer sa condition ou la projection
du worker. Elle vérifie le routage des zones, sans prétendre produire une vraie
alerte physique. Aucun faux état sportif ni capture de cette fixture n’est livré.

Aucun Godot ni UI lancé sur ce worktree, conformément au gel de la recette
commune. Les validations et captures éventuelles doivent être consignées sur
le SHA effectivement intégré et testé par l’intégrateur.
