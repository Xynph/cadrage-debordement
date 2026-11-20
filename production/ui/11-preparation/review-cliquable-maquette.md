# Relecture adverse, écran 11 Préparation (cliquabilité, petites fenêtres, fidélité à la maquette)

Lecture seule : code de `preparation_canvas.gd`, `preparation_briefing.gd`, `preparation_match_context.gd`, `entity_link.gd`, `mini_fiche.gd`, diff de `navigation_controller.gd`, captures 1920/1280 (dossier, bas, conseils, repères), maquette `11-preparation-1.png` et `11-preparation-2.png`. Godot non lancé.
Rôles : ux-designer puis art-director.

## A. Cliquabilité : élément → effet du clic → verdict

| Élément | Effet du clic (lu dans le code) | Verdict |
|---|---|---|
| Onglets Dossier adverse / Consignes | agit en place (`_choose`) | OK |
| Onglet Entraînement | `_choose(2)` : rend l'écran Entraînement (plein écran) | OK |
| « Revoir la composition → » | écran Composition | OK |
| « Aller au jour de match → » (ivoire plein) | écran Match (`open_match`) ; actif même quand le match n'est pas prêt (la maquette l'affiche verrouillé avec cadenas et « S'ouvre la veille du match ») | OK / voir C |
| « Carnet de jeu → » (barre d'onglets) | écran Plan de jeu | OK |
| « Préparer la suite » (icône calendrier) | `manager_planning.open` = **AcceptDialog** | **BLOQUANT** (B) |
| « La reprise » (si pertinent, hors match) | `reprise_dialog.open` = **AcceptDialog** | **BLOQUANT** (B) |
| Noms des deux clubs sous le titre | fiche du club adverse / écran Club (`name_link`) | OK |
| Libellé compétition, date, « Fenbank Ground », « 13e (0 pts) contre 1er (5 pts) » | texte non cliquable (le stade n'a pas d'écran), pas de soulignement | OK |
| Bandeau Danger, phrase | texte | OK (non cliquable, rien ne l'annonce) |
| « Plan conseillé : … → » | sous-page Conseils détaillés (en place, historique) | OK |
| Plaques « ALDER FEN XV nous » / « TRENTWOOD ARCHERS eux » | fiche du club (`name_link`) ; seul le nom est actif, la plaque entière et « nous / eux » ne le sont pas | À CORRIGER : plaque entière cliquable |
| Ligne de secteur du Rapport de force (6) | `_agir` : Composition, Plan de jeu ou Entraînement | OK, mais en 1280 (mode dense) le sous-titre « agir : … » disparaît : rien n'annonce le clic hors survol → À CORRIGER |
| Chiffres 53/57, barres, « −4 contre toi » | portés par la ligne cliquable ci-dessus | OK |
| Lignes « À faire avant le match » (5) | `Briefing.open_action` : Réception, Composition, Sélections, Effectif, Calendrier, Match, onglet Consignes | OK. « Presse » : `_show_press_inbox` = écran Réception, pas une fenêtre |
| « Tous les repères (5) » + loupe | sous-page Repères (en place) | À CORRIGER : la loupe est collée au bord droit du bouton, loin du texte (capture 1920) et promet une recherche |
| « Conseils détaillés → » | sous-page Conseils | OK |
| « Adopter le plan du staff → » | agit en place (`set_tactics`), aucun retour visible de la prise en compte | À CORRIGER (confirmation en place, par exemple libellé « Plan adopté » + coche) |
| Pastilles V/N/D de la forme adverse (5) | RIEN | À CORRIGER (ovales qui ressemblent à des boutons ; ouvrir la rencontre ou les rendre plates) |
| Nom du club adverse dans Forme récente | fiche du club | OK |
| Lignes de résultat (J1, nom, score, dom./ext.) | seul le nom de l'adversaire est actif ; ligne zébrée, score, journée : RIEN | À CORRIGER : ligne entière vers la rencontre (Compétitions > résultat) ou au minimum vers le club |
| « Face à eux » + pastilles + dernier score | RIEN (la maquette met « Plus → » sur les confrontations) | À CORRIGER |
| Légende « 1 résultats observés » | texte | À CORRIGER (accord : « 1 résultat observé ») |
| Cartes « Joueurs à surveiller » (3) | seul le nom est actif ; portrait, poste, note, remarque, carte entière : RIEN, alors que l'en-tête dit « Clic : fiche du joueur » | **BLOQUANT** : toute la carte active |
| Nom d'un joueur adverse (cartes, XV, tableau, banc, conseils) | si le joueur n'est ni dans l'effectif ni sur le marché (cas de tous les adversaires) : clic = XV du club adverse, **aucune mini-fiche au survol** ; si le club est indisponible : bouton grisé mais d'allure de nom | **BLOQUANT** (règle noms de joueurs : fiche + mini-fiche) |
| « Pas de signal robuste dans les observations disponibles → » | sous-page Conseils, qui dit seulement « pas encore de signal net » | À CORRIGER : flèche et lien trompeurs quand il n'y a aucun signal (texte seul, ou libellé « Voir les conseils du staff ») |
| Cases du XV probable (15) : anneau n°, poste, remarque, losange ◆ | seul le nom est actif (zone 131 × 28) ; le reste de la case, qui a l'allure d'une tuile : RIEN | À CORRIGER : case entière cliquable (l'anneau et le losange à l'intérieur) |
| « Tableau détaillé · remarques de Graham Penrose → » | sous-page XV | OK |
| Sous-page XV : lignes du tableau, banc, lien adjoint | noms comme ci-dessus ; en-têtes de colonnes non cliquables, sans flèche de tri | OK (non annoncés) ; AVIS : tri de colonnes attendu en densité FM |
| Sous-pages Repères / Conseils : lignes, « Adopter ce plan » | lignes → même action que ci-dessus ; bouton → action en place | OK |
| « ← Retour au dossier adverse » | retour de sous-page | OK |
| Onglet Consignes : tuiles de choix, « Consignes par zone et phases arrêtées → », « Mettre en pause » | agissent en place / Plan de jeu | OK |

## B. Petites fenêtres (règle n°2)

1. **BLOQUANT** : « Préparer la suite » ouvre `manager_planning.gd` (AcceptDialog).
2. **BLOQUANT** : « La reprise » ouvre `reprise_dialog.gd` (AcceptDialog).
3. `Briefing.open_all` (AcceptDialog « Avant le coup d'envoi ») n'est plus appelé depuis l'écran (remplacé par la sous-page Repères) : OK, mais le code mort est à supprimer pour éviter qu'un autre écran le rouvre.
4. Aucune autre fenêtre depuis cet écran : mini-fiche (survol), liens d'entités (écrans), sous-pages en place.

**Écran de remplacement proposé** (un seul dessin pour les deux) :
- « Préparer la suite » devient une sous-page du Calendrier : **Calendrier › Planning du manager** (les intentions manager_plan_*), plein écran, avec retour en une étape d'historique ; le lien de la Préparation et celui du Bureau y mènent.
- « La reprise » devient **Calendrier › La reprise** (même gabarit, visible seulement quand `reprise_view.relevant`), ou à défaut une section du Bureau en début de saison.
- Dans la Préparation, ces deux liens restent des liens texte + flèche vers ces écrans ; rien ne s'ouvre en fenêtre. Esc ramène à la Préparation selon la règle unique.

## C. Fidélité à la maquette (variante 1 + colonne adjoint de la variante 2)

Or : **aucun or visible** sur l'écran. `C.GOLD` est un alias de l'ivoire (`components.gd`), donc les survols et focus des noms (`Link.styled_button`) sont ivoire ; « Aller au jour de match » est bien ivoire plein. Les marques de l'écran n'utilisent que ivoire, V/N/D et couleur de club (déjà écartée si trop proche de l'or). Deux points à garder à l'œil :
- Barème des attributs : `ATTRIBUT_55` (#eadb55) est un jaune voisin de l'or de Continuer ; il colore « 55-64 au poste » et la colonne Niveau. Décision de Léo du 19/11, donc AVIS : à confirmer qu'il tolère ce jaune dans un écran où l'or est réservé.
- Le commentaire de code parle de « un seul ivoire plein » : exact sur le dossier, faux sur la sous-page Conseils (voir plus bas).

### BLOQUANT
- Aucune donnée inventée ou figée constatée (noms de clubs, de championnats, adjoint, journées, lieux : tous lus dans le modèle ; « dom. / ext. » déduit du côté réel). RAS.
- Voir A : cartes « Joueurs à surveiller » partiellement cliquables ; joueurs adverses sans mini-fiche ; deux fenêtres. Ce sont les seuls blocages.
- Risque de fusion : le diff `origin/main..HEAD` de `navigation_controller.gd` **supprime** la gestion de la sous-page « Charge individuelle » (`charge`, `charge_joueur`) et celle des sous-pages de Composition (`composition_page`). Si la branche n'est pas à jour de `main`, la PR retirerait ces fonctions des autres chantiers : rebaser, puis vérifier que le diff ne garde que `preparation_sub`.

### À CORRIGER
1. **Un seul ivoire plein** : sur la sous-page Conseils, « Aller au jour de match » (en-tête) et « Adopter ce plan » sont tous deux ivoire plein. Passer « Adopter ce plan » en lien, ou masquer l'ivoire d'en-tête dans les sous-pages.
2. **Bouton « Aller au jour de match »** : la maquette l'affiche verrouillé (cadenas) avec « S'ouvre la veille du match, ven. 20 nov. » quand le match n'est pas prêt ; le code l'active toujours dès qu'il y a une rencontre. Ajouter l'état verrouillé (jamais couleur seule : cadenas + texte).
3. **Menu « Plus ▾ »** de la maquette (secondaires regroupés) absent : « Préparer la suite », « Carnet de jeu », « La reprise » traînent dans la barre d'onglets. Décider : les liens restent (puis écrans de B) ou « Plus ▾ » ; un menu déroulant est autorisé, pas une fenêtre.
4. **Ligne « Dossier publié lun. 16/11 par ton adjoint · 8 matchs observés »** (droite de la barre d'onglets, maquette) absente. À ajouter si le dossier porte la date et le nombre de matchs observés ; sinon omettre (acceptable sans donnée).
5. **Forme récente** : la maquette montre deux lignes de repères (« Leur défaite », « Leur dernier », « Notre dernier ») et « Confrontations … Plus → ». Le code montre une liste de 4 résultats dont la zone est vide en début de saison (capture : un seul résultat, grand vide). Compacter le panneau quand il y a moins de 3 résultats et ajouter « Plus → » sur les confrontations.
6. **Pastilles V/N/D** : en maquette, pastille ovale + lettre ; code conforme. Mais cliquabilité à trancher (voir A).
7. **Mode dense 1280** : l'écran n'est plus lisible d'un coup d'œil (bande XV coupée par le pied, « agir : … » supprimé, note de pied tronquée « plan de jeu ou… », cartes joueurs sans condition). Prévoir un texte de pied court en dense ; vérifier le défilement du bas.
8. **Rayons 0** : `Link.styled_button` crée ses états survol/focus avec rayon 4 (`C.box(…, 4, 0)`) : coins arrondis sur tous les noms. Passer à 0 (ou utiliser le style lien de la charte en cours dans `components.gd`).
9. **Liens encadrés ou boutons de la coque** : « Tous les repères » et « Conseils détaillés » sont bien des liens texte ; l'icône loupe de « Tous les repères » est à retirer ou à rapprocher du texte.
10. **« Adopter le plan du staff »** : aucun retour visible après clic (voir A).
11. **Grammaire** : « 1 résultats observés ».
12. **Texte tronqué** signalé par `report.json` : « Demi d'ouverture » (case 10 du XV, 90 px) ; élargir la case ou abréger (« Dem. ouv. » est refusé : préférer deux lignes).

### AVIS
- La hiérarchie de la variante 1 est respectée : Danger puis Rapport de force à gauche, « À faire avant le match » à droite, puis forme + surveillés, puis XV. Le rapport de force est bien le premier regard.
- Rail en 1280 : le nom du club et la division sont barrés d'un trait (« d'accessi… 13e ») : défaut de coque, hors écran 11, à signaler à l'écran Coque.
- Le texte « Écart toujours écrit en mots » est utile mais long ; la mention « Clique un secteur pour agir » est la seule annonce de cliquabilité des lignes en dense : la conserver.
- Compteurs de losange ◆ « à surveiller » dans le XV : le sens n'est donné que dans l'en-tête de la sous-page ; ajouter la légende « ◆ à surveiller » sous la bande.
- Le jaune du barème des attributs (voir C) : à confirmer par Léo.
- La couleur de club des plaques et des barres passe par `club_trait` : correct, jamais or.
