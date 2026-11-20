# Relecture adverse - 07 Effectif (cliquabilité, petites fenêtres, fidélité à la maquette)

Branche claude/da-effectif-20261119. Lu : `squad_canvas.gd`, `shell.gd` (fil d'Ariane), `squad_views.gd` (comparaison), `epcr_preparation_dialog.gd`, `recruitment_comparison.gd`, `mini_fiche.gd`, captures 1920 et 1280, maquette v2, fiche UX 07. Rôles adoptés : ux-designer puis art-director. Rien n'a été lancé.

## A. Cliquabilité

| Élément | Effet du clic (code) | Verdict |
|---|---|---|
| Tuile Aptes | filtre « Aptes » (puce Aptes ajoutée) ; survol/focus = infobulle Équilibre par poste | OK. Aucun état « tuile active » (voir C) |
| Tuile Indisponibles | puce Indisponibles | OK |
| Tuile Fins de contrat | puce Fin de contrat | OK |
| Tuile Niveau moyen du XV | tri par niveau, décroissant | À CORRIGER : dans l'onglet Condition la colonne Niv. n'existe pas, le tri porte sur une colonne invisible |
| Onglets Vue d'ensemble / Condition / Contrats / Développement | changent la vue en place | À CORRIGER : « Contrats » affiche exactement les colonnes de « Vue d'ensemble » (seul le tri change) : onglet qui paraît inerte |
| « Ctrl Tab » | onglet suivant | OK |
| « Comparer 0/2 → » | ouvre une AcceptDialog (`recruitment_comparison.open`) | BLOQUANT (règle 2) ; voir B |
| « Vestiaire » | navigue vers l'écran Vestiaire | OK (pas de flèche, contrairement aux autres liens) |
| « Préparer l'Europe → » (si préparation européenne en cours) | ouvre une AcceptDialog | BLOQUANT (règle 2) ; voir B |
| Champ recherche, « / » | saisie en place, filtre | OK |
| Puces Tous / Avants / Arrières / Indisponibles / Fin de contrat / À surveiller | filtre en place, compteurs | OK |
| Menu « Poste : Tous » | menu déroulant | OK (exception) |
| « Filtres & tri » | menu déroulant (PopupMenu) | OK (exception) ; icône séparée du texte (C) |
| En-têtes de colonne (N°, Joueur, Poste, Niv., Pot., Condition, Âge, Fin de contrat, Statut) | tri, bascule du sens, tooltip | OK |
| Bandeaux AVANTS / ARRIÈRES | rien | Non cliquables, d'apparence titre : OK |
| Ligne entière | fiche complète | OK |
| Nom, portrait, drapeau | fiche complète ; survol = mini-fiche (`MiniFiche.lier`) | OK. Le drapeau a un tooltip « nationalité » qui n'apparaît jamais (mouse_filter IGNORE) : AVIS |
| « i » | mini-fiche au survol/focus ; clic = fiche (à vérifier : `MiniFiche.icone`) | OK. Sur la capture 1280 trois « i » s'affichent en cercle pointillé (Atherton, Smart, Ollerenshaw, Coates) : glyphe incohérent, À CORRIGER |
| Numéro / ovale | clic = ligne = fiche | OK |
| Poste, Autres, Pot. (tooltips), Condition, Âge, Statut | clic = fiche (la ligne) ; tooltips | OK |
| Fin de contrat | fiche, section contrat ; tooltip « Consulter le contrat » | OK. Rien ne le distingue visuellement d'un texte ordinaire : AVIS |
| Repère A / B en bout de ligne | rien (simple libellé) | À CORRIGER : à la souris, aucun moyen d'ajouter un joueur au comparateur (seulement Maj Espace) |
| Fil d'Ariane (« Alder Fen XV », « Effectif ») | cliquable (fiche du club, page racine) | OK (code shell) |
| Pied « 40 / 40 joueurs · tri : … » | texte | OK, non cliquable d'aspect |
| Message liste vide | texte, pas de lien de remise à zéro | AVIS : ajouter « Réinitialiser les filtres » |

## B. Petites fenêtres

1. **Comparateur** (`Comparer 0/2 →`, partagé avec Recrutement et fiche joueur) : AcceptDialog. BLOQUANT. Écran proposé : page pleine « Comparateur » (route propre, fil d'Ariane Effectif / Comparateur, Échap = retour à l'effectif avec la ligne et les filtres conservés). Deux colonnes joueurs (jusqu'à 3), portrait + nom (mini-fiche au survol, clic = fiche), 36 attributs côte à côte en 4 familles colorées au barème, meilleur valeur de chaque ligne en gras (pas seulement la couleur), contrat, condition, forme. Un sélecteur de joueur en tête de colonne (menu déroulant avec recherche) pour remplacer ou ajouter, ce qui règle aussi l'état « 0/2 » : à 0 ou 1 joueur l'écran s'ouvre quand même avec des emplacements vides « Choisir un joueur ». Mêmes données depuis Recrutement (les rapports d'observation) et la fiche (« Comparer avec… »). Retire une fenêtre dans trois écrans à la fois.
2. **Préparer l'Europe** : AcceptDialog. BLOQUANT. Le lien est de plus hors sujet dans l'Effectif : l'envoyer vers la page Compétitions (section Europe) et y construire l'écran de préparation (liste des joueurs retenus, quotas, règles). À défaut minimal : le lien navigue vers cet écran, la fenêtre disparaît.
3. Hors blocage : menu Poste, menu Filtres & tri, infobulle Équilibre par poste (Panel posé dans la coque, sans souris), mini-fiche : conformes.

## C. Fidélité à la maquette de Léo

### BLOQUANT
- Les deux fenêtres ci-dessus (B1, B2).
- Aucun moyen à la souris de choisir les joueurs à comparer : sans cela « Comparer n/2 » est un lien dont le compteur ne peut pas bouger (règle 1). Correction : case ou bouton « A/B » au bout de chaque ligne (visible au survol et sur les lignes choisies), clic = ajoute/retire.

### À CORRIGER
- **Colonne AUTRES** présente à 1920 avec des codes cryptiques (« 3E L-8 », « 2E L-3E L ») que la fiche UX et la maquette ont retirés (autres postes en infobulle du poste). Retirer la colonne ; garder l'infobulle.
- **Titre** : « Les hommes du projet · 40 joueurs sous contrat · saison 2026-27 » dans la maquette, « 40 joueurs sous contrat · saison 2026-2027 » en jeu. La phrase d'identité est présente sur tous les autres écrans (`TITLES`). Jugement : la remettre, sauf décision contraire de Léo ; le sous-titre garde alors le compte.
- **Repère à 80 %** de la barre de condition (maquette : tiret vertical ; fiche UX 6.2) absent de la barre en jeu. Ajouter. Vérifier aussi que 69 % gris et 100 % vert ne reposent pas que sur la couleur (le chiffre est écrit : OK).
- **Pas d'état actif sur les tuiles** : la maquette encadre/marque la tuile Aptes ; en jeu rien n'indique qu'une tuile filtre. Ajouter le marqueur ivoire incliné sur la tuile dont le filtre est actif.
- **Boutons secondaires** (Comparer, Vestiaire, Ctrl Tab, onglets, puces) : style `_lien` local avec fond au survol ; la charte veut ivoire + flèche + souligné au survol. Convertir vers le style commun de `components.gd` une fois fusionné. Mettre une flèche sur « Vestiaire ».
- **Icône « Filtres & tri »** à 50 px du texte (deux objets à 1920) : rapprocher (maquette : adjacents).
- **Onglet Contrats** = Vue d'ensemble (voir A) : ajouter les colonnes salaire/semaine, durée, prolongation possible, ou masquer l'onglet jusqu'à ce que sa vue existe (fiche 6.3).
- **Pied contradictoire** : la ligne de l'écran dit « Échap menu » ; le pied de la coque à 1280 dit « Échap Retour » et « Ctrl F Rechercher » (trois raccourcis de recherche : / , Ctrl K, Ctrl F). Un seul pied, une seule règle (Échap, décision de Léo du 19/11).
- **1280, bloc club** : « Division d'accessi… 13e » est barré / coupé par le filet sous le nom du club. Corriger dans la coque (retour à la ligne ou abréviation).
- **Glyphe « i »** cassé à 1280 (voir A).
- **Tuile Niveau** en onglet sans colonne Niv. (voir A).

### AVIS
- Les puces, le champ de recherche et le menu Poste ont un cadre complet de 1 px (art-bible §3 l'interdit) ; la maquette validée les encadre aussi : la maquette prime, mais à trancher avec la DA.
- Ligne 1 sélectionnée par défaut avec fond et marqueur, ressemble à un survol permanent : ne marquer qu'après un vrai choix, ou garder si le clavier l'exige.
- Tendance du XV : « = stable cette saison » vs « ▲ +1,2 sur 2025-26 » : valeur rendue honnête (omise si inconnue), bien.
- Bandeaux AVANTS / ARRIÈRES non repliables : un clic de repli serait cohérent avec « tout ce qui ressemble à un titre de bloc ».
- Tooltip du drapeau inatteignable ; fin de contrat sans signe de lien ; liste vide sans bouton « Réinitialiser ».
- Données : aucune valeur figée repérée (compteurs, club, championnat, saison lus dans le modèle ; « Division d'accession » vient du jeu).
