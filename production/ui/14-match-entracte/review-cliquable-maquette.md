# Relecture adverse, écran 14 Entracte (cliquabilité, fenêtres, maquette)

## Auto-relecture du lot 4 de la charte finale (20/11/2026)

**A. Cliquabilité** : inchangée par le lot ; `godot-match-entracte-da` contrôle que tout bouton visible agit.

**B. Petites fenêtres** : aucune ; listes déroulantes (exception) en carte 12.

**C. Fidélité à la charte**
- Corrigé : panneaux 18, cartes 12, cases/lignes choisies 6, puces en pilule ; plus de bandes alternées (filet) ; notre club au classement sur `SELECTION` ; titres droits ; comparaisons nous vert clair / adversaire doré (plus de couleur de club) ; jauges d'énergie en pilule ; carton rouge en rouge (seul usage) ; un seul aplat doré (ÉQUIPE, ou « Valider le choix » pendant un arrêt).
- À CORRIGER (préexistant) : ligne « Équipe… » du bas de Mon XV rognée à 1920 ; « Matthew BOOTHRO… » tronqué ; ÉQUIPE petit en 1280×720.


Relu : `match_between.gd`, `match_terrain_2d.gd`, `match_temps_forts.gd` (branche claude/da-entracte-20261120, HEAD 0ba5b8fb), captures `entracte-1920.png` / `entracte-1280.png`, maquette `14-match-entracte-1` (+ panneau d'arrêt de `-3`, colonne Plaquages de `-2`). Hors périmètre : bandeau du score (pastille du chrono, « REPRENDRE »). Lecture seule, aucun Godot lancé.

Réserve : les captures datent de 07:43, le dernier commit (légende de la domination en 1280) de 07:49. Le chevauchement « Alder Fen XV / + domine / – subit » visible sur `entracte-1280.png` serait donc corrigé, à reconfirmer sur une capture neuve.

## A. Cliquabilité

| Élément | Effet du clic (code) | Verdict |
| --- | --- | --- |
| Nom de joueur, Mon XV (19 px, lien ivoire souligné au survol) | `ouvrir_fiche(id)` : fiche complète en calque plein écran (un Control, pas une fenêtre) ; survol : `MiniFiche.lier` (calque, pas une fenêtre) | OK. Réserves : si `_app()` est introuvable ou `trouver()` vide, retour silencieux (RIEN) ; le nom a `FOCUS_NONE`, donc la touche « i » n'ouvre pas la mini-fiche au clavier (AVIS) |
| Nom de joueur, banc (16 et plus) | idem | OK, mêmes réserves |
| Fiche ouverte pendant le match : « ← Retour au match » / Échap / précédent-suivant / onglets | referme (`fermer_fiche`), le match reste en pause ; précédent et suivant restent dans la fiche ; onglets rouvrent la fiche | OK |
| Fiche ouverte : tout autre bouton (`_brancher_fiche`) | désactivé, infobulle « Disponible après le match. » | À CORRIGER léger : visibles mais grisés, sans dire pourquoi avant le survol ; mieux vaut les masquer ou mettre une phrase en tête de fiche |
| Ligne entière d'un titulaire (hors nom) | `joueur_choisi` : ouvre Équipe (calque `match_equipe`, pas une fenêtre) sur ce poste | OK sauf : (a) match fini, `ouvrir_equipe` ne fait rien (RIEN) alors que le curseur main reste ; (b) panneau d'arrêt avec choix en attente : ÉQUIPE, Réglages et la touche T sont bloqués (« une décision à la fois ») mais pas les lignes, ni « Remplacer le N », ni les lignes du banc : on contourne la règle |
| Ligne du banc (hors nom) | `tiroir_demande("Équipe")` : ouvre Équipe, sans poste ciblé ; infobulle « ouvrir la fenêtre Équipe » | OK ; mêmes réserves (a) et (b). Le mot « fenêtre » de l'infobulle est à remplacer |
| Noms du XV adverse | texte DOUX, non cliquable, sans mini-fiche (la ligne n'a qu'une infobulle) | AVIS : cohérent (aucune fiche du club) ; une mini-fiche adverse serait un plus |
| Ligne « Équipe » (total) | infobulle seule | OK, n'a pas l'air d'un lien |
| « XV adverse → » / « ← Mon XV » | bascule le tableau en place | OK |
| En-têtes ÉNERGIE / PLAQ. / NOTE / N° / JOUEUR | RIEN (libellés DOUX en capitales) | AVIS : ne ressemblent pas à des liens, mais un joueur de FM attend un tri ; non demandé par la maquette |
| Jauges d'énergie, valeurs, plaquages, notes | RIEN en propre, la ligne porte le clic (la cellule est `MOUSE_FILTER_IGNORE`, donc clic = ouvre Équipe) | OK |
| Pastilles du terrain (numéros 1 à 15, deux camps) | RIEN : le terrain n'a ni `gui_input`, ni infobulle, ni survol | À CORRIGER : ce sont des joueurs numérotés qui font écho à la liste. Au minimum survol = nom + mini-fiche pour les nôtres, clic = fiche ; pour les adverses, infobulle « n°, poste, nom » |
| « Alder Fen XV attaque → » (en-tête du terrain) | RIEN (pur texte, le commentaire du code l'assume) | À CORRIGER : la flèche « → » est le même signe que « Voir les statistiques → » et « XV adverse → », en texte atténué mais bien placé comme un lien à droite d'un titre. Retirer la flèche (le terrain dessine déjà le sens) ou la remplacer par un marqueur incliné |
| Ligne « 40′ (pictogramme) Mi-temps : … » sous l'en-tête | RIEN (infobulle = texte complet) | AVIS : ligne avec minute et pastille, l'allure d'une entrée de journal ; la rendre active vers Plus > Journal serait naturel (`tiroir_demande("Journal")`) |
| Chiffres clés : chaque ligne (Possession… Touches) | RIEN (infobulle « X : A · B ») | À CORRIGER léger : pas l'allure d'un lien, mais des chiffres que le joueur voudra creuser. Un clic sur la ligne vers Stats (même signal que le lien) ; sinon l'infobulle suffit |
| « Voir les statistiques → » | `tiroir_demande("Stats")` : volet Statistiques de la vue du match | OK. En 1280 ce lien est sous le pli du défilement (voir C) |
| Tuile Bonus (règle, états, dilemme) | RIEN en place (infobulles) | OK ; les 2 boutons de consigne appliquent une consigne et mettent le match en pause (actifs si match non fini) |
| Boutons de consigne Bonus, « Remplacer le N par X », « Appliquer ses consignes », actions « Pourquoi » | agissent (consigne, Équipe, navigation écran du levier) | OK côté effet ; À CORRIGER côté charte : boutons secondaires encadrés d'un filet complet (voir C) |
| Mot de Gabi (phrase, portrait, « GABI, TON ADJOINT ») | RIEN (infobulle = raisons complètes) | AVIS : la citation cite des joueurs (« N° 7 McCulloch ») en texte brut, sans lien ni mini-fiche ; règle des noms de joueurs non appliquée ici |
| Fil (texte du dernier fait, ex. « X marque un essai ») | RIEN | À CORRIGER léger : si le texte du moteur nomme un joueur de chez nous, le nom n'est ni lien ni mini-fiche (hors périmètre moteur : à tracer, pas à bloquer) |
| Domination : barres, repères « E · 13′ », triangles ▲▼, échelle 10′/20′ | RIEN (une seule infobulle générale pour tout le graphique) | À CORRIGER : les repères d'essais ont l'allure de marqueurs actifs. Au minimum infobulle par minute (survol d'une barre : « 13′ : +42, 7-0 ») ; clic sur un repère = journal à cette minute |
| « ÉQUIPE » (ivoire plein) + chip T | `tiroir_demande("Équipe")` | OK |
| « Réglages » (lien) | bascule le panneau Réglages dans la colonne de droite, en place, sans fenêtre ; relire pour revenir = « ← Chiffres clés » | OK |
| « Plus ▾ » | `MenuButton` : exception permise. Statistiques / Journal / Confier la fin / Autres matchs ouvrent ; les trois caméras ne montrent aucun effet en entracte 2D et le menu n'indique pas la caméra courante | À CORRIGER léger : « Vue TV / de dessus / contact » agissent sur la 3D masquée (`choisir_camera`), rien de visible en 2D ni de coche ; les griser ou les masquer pendant l'entracte, ou cocher le choix courant |
| Pied : raccourcis (Espace, Échap, T, ↑↓), « Vitesse : Éclair (Réglages) · … Plus ▾ » | RIEN (texte) ; touches dessinées en cartouche | AVIS : « (Réglages) » et « Plus ▾ » citent des commandes sans les porter ; les rendre cliquables (liens vers les deux) coûte presque rien |
| Panneau d'arrêt : options de joueur | enregistre le choix (`match_incident_choice`) ; la ligne est un bouton | À CORRIGER : nom, poste, énergie sans lien ni mini-fiche au survol, alors qu'on doit choisir qui entre ou sort |
| Panneau d'arrêt : « VALIDER LE CHOIX » / « REPRENDRE LE MATCH » / « Ouvrir l'équipe → » | valide / reprend / ouvre Équipe (désactivé tant que le choix est en attente) | OK ; voir C pour le second ivoire plein |
| « Confier la fin à l'adjoint » (panneau) | confirmation en place puis `delegate` | OK |
| Réglages : vitesses et niveaux de temps forts | choix en place (`horloge_choisie`, `niveau_choisi`) | OK |
| Multiplex (cartes des autres matchs), classement en direct | cartes et lignes : infobulle seule (`MOUSE_FILTER_PASS`), RIEN au clic | À CORRIGER : les cartes sont des tuiles de match avec score ; aucun clic ne mène nulle part (pas d'écran « match d'un autre club » ? à confirmer, sinon rendre non cliquables : pas de curseur, pas de survol). Clubs du classement : pas de lien vers la fiche du club |

## B. Petites fenêtres

Aucune `Window` / `AcceptDialog` / `ConfirmationDialog` / `PopupPanel` dans les trois fichiers : la fiche, la mini-fiche, Équipe, Stats et Journal sont des calques Control. Le seul `PopupMenu` est celui de « Plus ▾ » (exception permise). Réglages, Confier la fin, Autres matchs et arrêt sont des panneaux en place. Rien de BLOQUANT. À nettoyer : les infobulles écrivent encore « fenêtre Équipe » (lignes du XV, du banc, bouton « Remplacer »).

## C. Fidélité à la maquette, couleurs, 1280

### BLOQUANT

Aucun. Aucune donnée inventée ou figée repérée : noms de clubs, règle de bonus, règles de championnat viennent de `direct` et de `live.teams` (les noms « Alder Fen », « Top 14 » ne figurent que dans des commentaires).

### À CORRIGER

1. Série « nous » en couleur de club brute, pas en club-trait : barres de la domination, barres des chiffres clés et carré de la légende utilisent `couleurs[nous]` (par défaut `71322f`) sur fond `PANNEAU`, soit un contraste d'environ 1,5:1 ; sur la capture 1920 les barres rouge sombre se confondent presque avec le fond. L'adversaire, lui, passe bien par `Charte.club_trait` (filet clair). Appliquer `club_trait` aussi au remplissage de « nous » (barres, légende), la forme pleine/vide portant déjà le camp. Pastilles du terrain : remplissage brut mais liseré `club_trait`, acceptable.
2. Notes colorées (`_teinte_note`) : le chiffre est toujours écrit (la couleur n'est pas seule porteuse) et ce n'est pas un vert/rouge de série. Mais le barème (≥ 7,5 / 7 / 6,5 / 6) n'est écrit nulle part à l'écran, alors que la décision du 19/11 impose une légende à côté de toute couleur à barème ; il ne reprend pas les paliers de la fiche joueur (`BAREME_ATTRIBUTS`), et ses deux verts (`ATTRIBUT_75` 4fcb78 et `V` 6cc48a) sont quasi indiscernables : un palier mort. Mettre une légende de trois mots sous la colonne ou en infobulle de l'en-tête NOTE, et fusionner les deux verts.
3. Banc : à 1920 il n'est visible qu'à moitié (16, 17, début du 18) dans le défilement partagé avec les titulaires, à 1280 il n'est pas visible du tout ; or le remplacement est l'action principale de l'entracte (maquette : banc en entier sous le XV, « 7 joueurs · 7 changements possibles »). Donner au banc une zone fixe sous la liste (ou réduire la ligne à 28 px) ; la mention « changements possibles » manque quand `remplacementsRestants` est absent (acceptable, donnée absente).
4. Terrain sous-dimensionné : la maquette remplit toute la tuile ; ici le terrain (≈ 717 × 420 à 1920, 360 × 200 à 1280) flotte dans une tuile de ≈ 970 × 550, marges larges de chaque côté. Pastilles minuscules à 1280, le paquet autour du ballon est illisible. Agrandir le terrain à la largeur de la tuile.
5. 1280 : noms coupés à la lettre (« OLLERENSHA », « ATHERT », « DANGERFIELD »), sans points de suspension (cadre `clip_contents`, étiquette interne sans `TRIM_ELLIPSIS`). Un nom coupé sans signe ressemble à une erreur. Soit abréger (« B. Ollerenshaw »), soit ajouter « … ».
6. 1280 : « Voir les statistiques → », la tuile Bonus et la dernière ligne (« TOUCHES GAGNÉES ») sont sous le pli du défilement ; le lien vers les statistiques, seul accès à l'écran détaillé, doit rester fixe (en-tête du panneau, à droite de « CHIFFRES CLÉS ») ; barre de défilement qui rogne les valeurs de droite (« 46 % », « 2 »).
7. Un seul ivoire plein par écran (charte §7) : « ÉQUIPE » est plein en permanence ; en arrêt-décision « REPRENDRE LE MATCH » l'est aussi (ÉQUIPE est alors grisé, mais reste empilé dans la même barre), et dans Réglages chaque groupe de segments affiche un choix en ivoire plein (jusqu'à 3 pleins). Garder le plein pour l'action principale du moment et marquer les segments choisis par un filet épais et une coche.
8. Boutons secondaires encadrés d'un filet complet (`_habiller` : bordure sur 4 côtés) : « Remplacer le N par X », « Appliquer ses consignes », choix du Bonus, actions « Pourquoi », « Confier la fin », segments des Réglages, ligne retenue du panneau d'arrêt. Charte §3 : aucun cadre complet. Les convertir au style `style_bouton_lien` (déjà utilisé par `_lien`), avec flèche, sauf les segments qui sont un choix unique.
9. Domination : la maquette indique le marqueur et son score (« P · Atherton 3-0 », « E · Garnier 10-7 ») ; ici « E · 13′ » seul, le score n'apparaît que sur le dernier repère (`scores` ne couvre que les faits de `deroule`). Colonne de repères incohérente. Compléter (score, nom du marqueur : si nom, c'est un lien). Étiquettes « E · 8′ », « E · 19′ » écrites dans la zone des barres adverses (1920) : décaler sous l'échelle ; « E · 39′ 17-22 » touche le curseur de minute.
10. Menu Plus : caméras sans effet visible en 2D (voir A).
11. Panneau d'arrêt : options sans mini-fiche, ni lien (voir A).
12. Ligne du banc et ligne titulaire pendant un arrêt-décision : contournent le blocage d'Équipe (voir A).

### AVIS

- Pastilles du terrain : la différenciation nous/eux est portée par la forme (plein / anneau), bien.
- Gabi : bon contraste, bon ton ; le trait de club incliné est présent.
- « Mon XV » : colonnes alignées, énergie avec « ! » et « épuisé » en toutes lettres (jamais seulement la couleur).
- Constante `NOTE_DEPART = 6.5` dupliquée côté Godot depuis le moteur JS : à lire dans `direct` plutôt qu'en dur.
- Les infobulles de ligne (« Ligne : ouvrir la fenêtre Équipe … ») sont longues ; une phrase suffit.
- Pied : « Plus ▾ » en texte brut à droite : si Léo clique, rien ne se passe ; le rendre actif ou retirer le symbole ▾.

## Suivi des corrections (20/11, après-midi)

- A « Multiplex, classement en direct » : chaque ligne du classement et chaque club d'une carte du multiplex ouvrent la fiche du club dans une page du direct (main au survol, fond de survol ou sigle éclairé « → », Entrée au clavier). Corrigé.
- A « En-têtes N° / JOUEUR / ÉNERGIE / PLAQ. / NOTE » : triables (énergie la plus basse d'abord, plaquages et note les plus hauts d'abord, second clic = sens inverse, N° = ordre des postes) ; grisés et dits sur le XV adverse. Corrigé.
- Points laissés par le Match en direct (#1029) : ÉQUIPE en ivoire plein (plus d'or), puce « T » à côté, Réglages jamais en PopupPanel : panneau de la colonne de droite à l'entracte, menu déroulant (vitesse, temps forts cochés) pendant un temps fort 3D. En 3D, « Confier la fin » passe par le menu du match et « Autres matchs » est grisé « à l'entracte ».
- Page Équipe du match (`match_equipe.gd`) : plus d'or, angles droits, plus d'ombre ni de cadre complet, choix courants en filet épais + coche, un seul ivoire plein (« Valider et reprendre »), lien « ← Retour au direct » en tête ; plancher 12 px.
- B : aucune fenêtre nouvelle ; les seuls menus déroulants sont « Plus ▾ » et Réglages en 3D (exception de Léo).
- Restent (AVIS) : mini-fiche des adversaires (pas de fiche du club adverse côté joueurs), noms cités par Gabi en texte simple.


## Relecture adverse 20/11 après-midi

Lecture seule du code actuel (`match_between.gd`, `match_equipe.gd`, `match_temps_forts.gd`, `match_terrain_2d.gd`) ; aucun Godot lancé. Or : aucun écart (`OR` de l'entracte vaut `Charte.IVOIRE`, aucune teinte dorée dans les quatre fichiers). Rayons : tous à 0 sauf les disques du terrain (`_boite(rond=true)`, `_portrait(rond=true)`), forme ronde assumée.

### A. Cliquabilité (nouveautés ou points non couverts)

| Élément | Effet du clic (code) | Verdict |
| --- | --- | --- |
| Page Équipe : médaillon d'un joueur sur le terrain (nom, numéro, portrait) | `choisir_poste(slot)` : sélectionne le poste pour un remplacement ; infobulle texte seule ; aucune `MiniFiche`, aucune fiche (le fichier ne contient ni `MiniFiche` ni `ouvrir_fiche`) | BLOQUANT : nom de nos joueurs sans fiche complète ni mini-fiche |
| Page Équipe : tuile du banc (nom, poste, énergie) | `choisir_entrant(id)` ; infobulle seule | BLOQUANT : idem |
| Page Équipe : blocs « Fatigue » (portrait, nom, barre, « 62 → 40 % ») | RIEN (bloc `_h` en `MOUSE_FILTER_IGNORE`, infobulle seule) | BLOQUANT : nom + portrait + chiffre, aspect de lien, rien ne s'ouvre ; fiche + mini-fiche |
| Page Équipe : carte de conseil de Gabi, « Faire entrer X → », texte nommant sortant et entrant | applique le remplacement ; les noms du texte sont du texte brut | À CORRIGER : noms sans lien ni mini-fiche (les décider d'après Gabi est le moment où l'on veut la fiche) |
| Page Équipe : menus « Avec / Sans le ballon / Sur pénalité » (`OptionButton`) | menu déroulant (`PopupMenu` de l'`OptionButton`) | Exception permise (menu de choix) ; AVIS : popup non habillé dans le fichier, à vérifier (angles droits, sans ombre) |
| Pastilles du terrain 2D (`match_terrain_2d.gd`) | RIEN ; ni survol, ni clic (point déjà noté en interne, toujours vrai dans le code) | BLOQUANT tant que nos 15 joueurs numérotés ne portent pas mini-fiche au survol et fiche au clic |
| Panneau d'arrêt : options de joueur (`_style_option`, ligne 3128) | `MiniFiche.lier` présent : survol OK ; le clic choisit l'option, la fiche complète ne s'ouvre pas | À CORRIGER : clic = choix seulement ; ajouter « i » ou clic droit vers la fiche, ou accepter (clic = fiche impossible ici) |
| Multiplex : carte d'un match, ligne du classement | corrigés selon le suivi ; la carte « change » a un cadre vert complet de 3 px | voir C |
| Menu « Plus ▾ » (`MenuButton`) | menu déroulant permis ; caméras grisées en 2D, dites « en 3D seulement » | OK |
| « Réglages » en temps fort 3D | `PopupMenu.popup()` sous le lien (ligne 813) | Exception de Léo (menu Réglages) ; AVIS : popup posé à la main, vérifier qu'il se ferme au clic extérieur et à Échap |

### B. Petites fenêtres

Aucune `Window`, `AcceptDialog`, `ConfirmationDialog`, `PopupPanel` ni `FileDialog` dans les quatre fichiers (recherche faite). Seuls `PopupMenu` : « Plus ▾ » (match_between.gd:716), menu des réglages 3D (755), les trois `OptionButton` du plan de jeu (match_equipe.gd:1550) : tous des menus déroulants permis. `match_equipe.gd:61` nomme le calque « MatchTeamWindow » : simple `Control`, mais le nom trompe, à renommer. Rien de BLOQUANT.

### C. Fidélité, charte et maquette

#### BLOQUANT

1. Nos joueurs sans fiche ni mini-fiche dans toute la page Équipe : médaillons, banc, bloc Fatigue, conseil de Gabi (voir A). C'est le cœur de la règle de Léo sur les noms.
2. Pastilles du terrain 2D : nos joueurs numérotés sans survol ni clic (voir A).

#### À CORRIGER

1. Cadres complets (charte §3 : aucun) : tuile du banc `_boite(... C.LINE, ..., 1)` sur 4 côtés et filet épais 3 px ivoire quand choisie (match_equipe.gd:1112) ; `OptionButton` du plan de jeu (1557) ; segments « choisi / segment » (398) ; segments des réglages (match_between.gd:539) ; ligne retenue et focus du panneau d'arrêt (3189) ; carte « change » du multiplex, 3 px vert sur 4 côtés (2188) ; marque creuse de la légende adverse (1654). Passer à un filet unique (gauche ou bas) comme le fait déjà `_plat`, et marquer le choix par filet gauche épais + coche.
2. Le commentaire de `_boite` (« un filet sur les 4 côtés reste réservé aux commandes ») contredit l'art bible ; le corriger avec le code.
3. Deux `PopupMenu` (Plus, réglages) et les menus d'`OptionButton` n'ont aucun style posé dans ces fichiers : sans thème global, ils sortent du thème par défaut de Godot (fond gris, possible ombre). Les habiller (fond PANNEAU, rayon 0, sans ombre).
4. Panneau d'arrêt : clic sur le nom d'un joueur ne mène pas à la fiche (voir A).
5. Un second ivoire plein en bas de la page Équipe tant que le bouton principal « Valider et reprendre » coexiste avec le segment ou la tuile choisie en `C.SELECTED` plein : vérifier sur capture que le fond relevé ne se lit pas comme un deuxième bouton plein.
6. Nom du calque « MatchTeamWindow » (match_equipe.gd:61) à renommer en « MatchTeamPage ».

#### AVIS

- Fatigue : la teinte de l'énergie n'est portée que par le filet bas du portrait et la barre, le pourcentage est écrit, bien.
- Terrain : numéro de badge dessiné dans un cercle (disque admis).
- Les couleurs vert pelouse du terrain (`1d4631`, `214e37`, `53625e`) sont codées en dur dans `match_equipe.gd:774-785` ; les passer par la charte.
### Suivi de la relecture adverse du 20/11 après-midi
- BLOQUANTS page Équipe : noms des médaillons, du banc, des blocs Fatigue et du conseil de Gabi en liens. Survol : mini-fiche. Clic : fiche complète en page du direct (« ← Retour au direct », la page Équipe retrouvée dessous). Les clics sur médaillon et tuile gardent leur action, et le bloc Fatigue ouvre la fiche. Corrigé.
- BLOQUANT pastilles du terrain 2D : survol = mini-fiche (déjà branché via `pastille_survolee`) ; clic sur un des nôtres = fiche complète (« ← Retour au direct »), sa ligne garde le focus. Corrigé.
- 6 Panneau d'arrêt : « i » à droite de chaque option, vers la fiche complète ; le clic sur la ligne reste le choix. Corrigé.
- 7-8 Cadres : segments, options d'arrêt, carte « change » du multiplex, marque de la légende adverse, bouton éteint, tuiles et menus de la page Équipe : filet unique, choix = filet gauche épais + coche ; commentaire de `_boite` corrigé. Le test vérifie l'absence de style à quatre filets. Corrigé.
- 9 Menus déroulants (Plus, Réglages 3D, plan de jeu) : fond panneau, rayon 0, sans ombre. Corrigé.
- 10 Capture : le choix courant (onglet, crans) est sur fond sombre relevé + filet gauche + coche, jamais lu comme un 2e ivoire plein. Vérifié.
- 11 `MatchTeamWindow` → `MatchTeamPage`. 12 Pelouse via `Charte.PELOUSE*`. Corrigés.
