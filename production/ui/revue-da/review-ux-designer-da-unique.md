# Revue UX des maquettes en direction unique (DA3) : 19 écrans x 3 mises en page

> Auteur : ux-designer (CCGS), phase 4 de `/team-ui`, mode autonome, 19/11/2026.
> Entrées lues : les 57 captures 1920x1080 (`scratchpad\da3\apercus\NN-id-1|2|3.png`), les fiches `design/ux/01` à `19` (jusqu'au §6 pour chacune), `hud.md`, `interaction-patterns.md`, `da3\BRIEF.md`.
> Limites : revue sur capture. Je n'ai ni mesuré les corps de texte (11 px des étiquettes en capitales : à mesurer), ni vu le HTML, ni testé le clavier. Les écrans dont les trois mises en page montrent des états différents ne se comparent que partiellement (voir §4).
> Vocabulaire : **bloquant** = rompt une exigence ferme de la fiche ou une décision de Léo ; **mineur** = à corriger sans changer la mise en page. `L1`, `L2`, `L3` = mises en page 1, 2, 3.

---

## 1. Synthèse

| Écran | Meilleure mise en page pour la fiche | Emprunt à faire |
|---|---|---|
| 01 Accueil | L1 | pied de L3 (liens discrets) |
| 02 Création | L2 | panneau « Ton choix » de L1 |
| 03 Chargement | L1 | « arrêt prévu » et liste des jours de L2 |
| 04 Bureau | L1 | tableau des absents de L3 |
| 05 Réception | L1 | corriger la pastille de filtre ; sortie « Tout afficher » de L3 |
| 06 Presse | L2 | indicateurs de L2 ; « Ton image » avec seuils de L3 |
| 07 Effectif | L1 | « Équilibre par poste » et « Échéances » de L2 |
| 08 Fiche joueur | L1 | rang parmi les talonneurs de L2 |
| 09 Recrutement | L1 | « Ce que coûte l'offre » de L3 |
| 10 Composition | L3 | rien d'autre : c'est la plus complète |
| 11 Préparation | L1 | mots « contre toi » et double forme de L3 |
| 12 Avant-match | L1 | affiche en bandeau de L3 |
| 13 Direct | L1 | aucun |
| 14 Entracte | L1 | colonnes de L2 pour la liste du XV |
| 15 Après-match | L1 | classement de L2, phrase sur Échap de L3 |
| 16 Compétitions | L1 | panneau « Ta saison » de L2 |
| 17 Finances | L1 | bloc « Budget de transferts » de L3 |
| 18 Club | L1 | tableau « Ce qui a fait bouger la confiance » de L2 |
| 19 Formation | L1 | cartes « À décider » de L3 |

L1 gagne souvent parce qu'elle reprend le wireframe de la fiche. Les vraies raisons de préférer une autre mise en page sont dites écran par écran (02, 06, 10).

## 2. Constats transversaux

### 2.1 Échap et bouton Menu

- Le bouton « Menu » avec la pastille « Échap » est présent en haut à gauche de tous les écrans à coque (04 à 11, 16 à 19). Il tient la décision du 19/11.
- **Bloquant, coque (08, 11)** : la pastille « Échap » reste collée à « Menu » alors que, sur une fiche joueur, Échap fait « Retour » (étape 2 de la règle unique). La fiche 08 affiche d'ailleurs sa propre pastille « Retour à l'effectif [Échap] » : deux indications contraires sur le même écran. Correction : pastille de la coque dynamique, visible seulement quand rien ne se ferme et qu'il n'y a pas de retour ; sinon elle passe sur le bouton « Retour ».
- **Mineur, pied de page** : la ligne « Espace Suite · Échap Menu · F1 » que les fiches 04, 05 et 06 exigent n'existe que sur 04, 07 et 09. Absente de 05, 06, 08, 16, 17, 18, 19. Correction : la mettre dans la coque, pas dans chaque écran.
- **Match (13, 14)** : le pied « Échap Ferme la fenêtre, sinon pause » de 14-L1 et 14-L2 est conforme. Voir 13-L3 pour l'écart.
- **15** : Échap ne ferme pas l'écran (décision du 16/11). Seule 15-L3 le dit à l'écran. Il faut l'écrire aussi sur les deux autres.

### 2.2 Densité Football Manager

- Tenue sur les écrans de listes (07, 09, 16, 18 Staff, 19) : lignes de 24 px, 22 à 26 lignes visibles, chiffres alignés. Très bon.
- Trous gênants : Bureau L1 (colonne Gabi), Bureau L3 (bas des deux panneaux), Formation et Club (tiers bas vide), Avant-match L1 et L2 (bas des tuiles). Les trous dans les cartes de synthèse se corrigent en y remontant du contenu utile, pas en ajoutant des blocs.
- Étiquettes en capitales espacées (en-têtes de colonne, titres de cartes) : à mesurer à 1080p. Elles semblent proches de 11 px ; la fiche accepte 11 à 12 px, le brief interdit moins de 12 px. Ligne de conduite à trancher.

### 2.3 Motifs réutilisés

Bien tenus : pastilles V/N/D avec lettre et forme (04, 11, 12, 16, 15), barres face à face (10, 11, 14, 15), pastille de statut avec icône + mot (07, 19), bouton plein ivoire unique + Continuer en or, lien flèche pour le secondaire, étiquette « À corriger / Point fort » avec symbole.
À harmoniser : trois formes d'onglets (soulignés en capitales 16/17/18/19, onglets à chiffres 06, onglets à pastille 07) ; la même pastille de filtre (07 ivoire, 05 soulignée) ; « Voir ... → » en lien, mais « Remplacer le 7 → » (14) et « Promouvoir → » (19-L2) sont des actions principales traitées en lien.

### 2.4 Une chose principale, un seul bouton plein

Respecté sur les 57 captures : un seul bouton plein ivoire (ou or pour « Coup d'envoi », « Ouvrir la conférence de presse », « Reprendre la carrière ») en plus de Continuer. Exceptions notées : 14-L1 et 14-L3 (voir plus bas).

---

## 3. Cohérence des données entre écrans

Le brief fixe : mardi 17/11/2026, J9, Alder Fen XV 4e avec 25 pts, Northmere Blues 1er, match 24-21, trésorerie 3,54 M€, budget de transferts 420 k€ alloué / 265 k€ restant.

**Cohérent** : budget de transferts (265/420, 155 k€ engagés = Dangerfield 110 k€ + Amos 45 k€) sur 05, 09, 17, 18 et 02 ; trésorerie 3,54 M€ (09, 17) ; Alder 4e 25 pts (01, 04, 11, 12, 16) ; tout le déroulé du match 13 à 15 (3-7 à 27', 10-7 à la mi-temps, 15-7 puis 17-7 à 52', 17-14 à 63', 24-21 final, fil du score, 3 essais chacun) ; dates et échéances de courrier (19/11) entre 04, 05, 06.

**Incohérent. Tout ce qui suit est bloquant pour la recette tant que le jeu d'essai n'est pas unique** (un seul fichier de données de maquette pour les 19 écrans) :

| Donnée | Versions trouvées |
|---|---|
| Points de Northmere avant J9 | 31 (04 Bureau, 06 Presse « à six points ») ; 33 (16) ; 34 (11, 12). Après le match : 33 (15-L2), alors que 33 + 1 point de bonus défensif = 34 depuis 16 |
| Classement J8 (rangs 2 et 3) | 04 : Meadowbridge 3e, 27 pts, diff. +41 ; 16 : Meadowbridge 2e, 30 pts, diff. +61, Kingsey 3e, 27 pts ; 04 : Blackthorn 5e, 24 pts ; 16 : Greycliff 5e, 24 pts, Blackthorn 7e, 20 pts |
| Nuls au classement | Northmere 0 nul (15-L2) alors que sa forme montre un N (11, 12) ; Meadowbridge 0 nul (15-L2) alors que 06 donne 19-19 à J8 |
| Forme d'Alder (5 derniers) | 04, 06 : V V D V V ; 16 : V N V D V ; 11, 12 : D V V N V ; 08 (Jowett) : N V D V V |
| Forme de Northmere | 04-L3 : V N V V V ; 11, 12 : V V N V D ; 16 : V V D V V |
| Résultat J8 d'Alder | 06 et 05 : victoire 22-17 à Kingsey ; 16 et 18 : victoire 27-19 contre Trentwood à domicile (Kingsey = défaite 16-27 à J7) ; 08 : victoire 22-18 à Westmoor |
| Calendrier de saison d'Alder | 02 (J1 Kingsey, J4 Northmere à l'extérieur) ; 08 (J1 Kingsey dom., J2 Penmar ext.) ; 16 (J1 Hawthorn, J2 Meadowbridge). Trois calendriers. Et Northmere ne peut pas être joué en J4 à l'extérieur et en J9 à domicile dans un 12 clubs à 22 matchs |
| Programme J9 et résultats J8 des autres | 06 et 16 donnent des appariements et des scores différents (ex. Northmere 31-10 Westmoor en 06, 31-12 en 16) |
| XV de départ | 10 (Fairclough 1, Ollerenshaw 2, Atherton 3, Coates 4, Dangerfield 5, Jowett 8...) ; 07 (Fairclough 1, Jowett 2, Atherton 3, Bickerstaff 4, Gannon 5...) ; 14 (Rudd 1, Tasker 2, Fairclough 3, Ollerenshaw 4, Atherton 10, Smart 9...). Trois XV |
| Postes | Fairclough : pilier gauche (07, 10), centre (04, 05, 06), 2e ligne (17), pilier droit (14) ; Atherton : pilier droit (07, 10), demi de mêlée (04-L3), arrière (17), ouvreur (14) ; Jowett : talonneur (07, 08), 3e ligne (04-L3), ailier (17), numéro 8 (10, 14) ; Ollerenshaw : talonneur (07, 10), pilier (04-L3), 2e ligne (14) |
| Blessés et absents | 04 : Gannon (3 sem.), Ollerenshaw (10 j), Fairclough incertain ; 07 : Marland, Hargreave blessés, Pryce suspendu, Fetuao en sélection ; 10, 11 : Ackroyd blessé, Rimmer en sélection ; 18 : Smart, Fairclough, Marsh blessés, Bickerstaff suspendu. Effectifs « disponibles » : 31 (04), 36 (07, 18) ; blessés : 2 (04, 07), 3 (18) |
| Condition de Bickerstaff | 78 % (10, 11, 12), 91 % (07) |
| Confiance du conseil | 72/100 (04), 74/100 (18) |
| Objectif et zones du conseil | 04 : « 5 premiers, barrages d'accession » (zone 2e à 5e) ; 02 et 18 : « 4 premiers, phases finales » ; 16 : 1er à 4e en phases finales ; 16-L3 : le champion de la D2 joue un barrage contre le 13e de l'Élite |
| Fins de contrat | 6 (07, 09) ; 7 (17) avec d'autres noms |
| Salaire de Jowett | 1 450 €/sem. (07, 08) ; 4 100 €/sem. (17-L3) |
| Essais de Jowett | 2 (08) ; 9, meilleur marqueur de la division (16-L1) |
| Dernier duel Northmere | défaite 18-26 (11, 12, 16) ; défaite 19-27 (04-L3) |
| Semaine et lieux | « semaine 11 » (04, 06) ; « semaine 47 » (17). Stade 6 200 places (02) ; 8 400 places (18). Président : Martin Holloway (02), Margaret Holloway (05), Arthur Bellamy (18) |

Correction : un seul fichier de jeu d'essai (classement J8 complet à 12 clubs, 8 résultats d'Alder, forme dérivée du calendrier, XV titulaire, blessés, contrats) lu par les 19 écrans. Sans cela, la comparaison joueur « le Bureau dit une chose, l'Effectif en dit une autre » est la première chose qu'une recette trouvera.

---

## 4. Revue par écran

Légende des colonnes : 5 s = la chose principale est-elle la plus forte ; blocs = blocs et données de la fiche ; bouton = un seul bouton plein.

### 01 Accueil (`01-accueil.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Oui : bouton or « Reprendre la carrière » au-dessus d'une carte (4e, 25 pts, prochain match, sauvegarde) | Oui : « Nouvelle carrière » ivoire (état première fois) | Oui : bouton or en haut d'une liste de 4 lignes |
| Blocs | Complet, plus classement et prochain match (utile) | État « première fois » : carte « Une saison à écrire » conforme. **Mineur** : « Identités et packs » + « Jeu de base » est redevenu une ligne du menu principal (la fiche demande un lien discret) | Complet ; écusson, saison, J9, 4e, date de sauvegarde sur 1 ligne |
| Échap | n/a | n/a | n/a |
| Densité | Texte de carte 12-13 px, conforme | idem | idem |

Écarts : **mineur** L1 et L3, « Jeu de base » affiché à côté de « Identités et packs » (jargon de réalité). **Mineur** L1, pas de mention « Échap ne fait rien » (ok pour la fiche, qui n'impose rien d'affiché). **Mineur** L2, la « Visite guidée » est un bouton en bas, conforme à la fiche (première fois seulement).
Recommandation : **L1**. Elle donne la reprise en 1 clic avec le contexte (journée, rang, adversaire) et garde les secondaires dans la carte.

### 02 Création (`02-creation.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Grille de 12 cartes, club choisi cerclé + coche « Choisi » | Tableau triable de 12 clubs, ligne choisie cerclée + coche | Liste à gauche + héros du club choisi à droite |
| Blocs | Niveau, joueurs, budget, conseil par carte ; « Ton choix » ; Format et enjeux (4 lignes + « Lire la suite ») | Stade, places, niveau, joueurs, budget, masse salariale, attente du conseil, rang 25-26 ; « Ton choix » ; Gabi « Quel club choisir ? » ; « Premières journées » | Niveau, budget, masse salariale, effectif, saison passée, mot du président, Gabi ; **pas de texte « Format et enjeux »** (un lien seulement) |
| Bouton | « Continuer avec Alder Fen XV » ivoire, 1 seul | idem, dans le panneau de droite | idem, tout en bas à droite, loin de la liste |
| Échap | « ← Accueil [Échap] » en barre haute | idem | idem |

Écarts : **mineur** L1, « Format et enjeux » dépasse les 3 lignes puis coupe par « dernie… » avant « Lire la suite » (la fiche veut 3 lignes visibles). **Mineur** les trois, « Identités et packs · Jeu de base » reste dans la barre haute (la fiche retire « Jeu de base »). **Mineur** L3, zone centrale vide de 220 px. **Mineur** L2, le bouton principal est sous « Rivalités », à 500 px de la ligne choisie : le replacer sous la carte « Ton choix ».
Recommandation : **L2**. C'est la seule qui permet de comparer les 12 clubs d'un coup (budget, masse salariale, ce qu'attend le conseil), donc la seule qui lève « la peur de mal choisir » de la fiche. L1 est correcte mais cache le budget dans des cartes sans tri.

### 03 Chargement (`03-chargement.md`)

Les trois montrent trois états différents (Continuer long, Continuer jusqu'au match, création de carrière) : comparaison limitée.

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Phrase « Passage au jour suivant… » + dates 17 → 18 + barre 38 % | Anneau ovale 62 % très fort, mais la phrase est en second | Titre « Création de la carrière… » + barre segmentée 60 % |
| Blocs | État, progression « Étape 3 sur 8 », conseil de Gabi, « Échap : arrêter » **et** bouton « Arrêter → » en focus (état Long à 24 s) | État, jours 19 → 20, « Arrêt prévu : sam. 21 nov. », liste des jours, conseil, « Échap : arrêter » | État, étapes ✓/▸, fait du club « En coulisses » |
| Échap | Annoncé et bouton | Annoncé en gris discret, sans bouton | Rien d'annoncé : **correct**, la création n'est pas annulable |

Écarts : **mineur** L1, l'écran en dessous n'est pas le nouveau Bureau (liste « Aujourd'hui » avec colonnes Forme/Fraîcheur, rail sans écusson) : à remplacer par la capture du 04. **Mineur** L2, plein écran, alors que la fiche demande une superposition sur l'écran en cours ; pas de bouton « Arrêter » à 20 s ; « Échap : arrêter » en 12 px gris. **Mineur** L1, « Étape 3 sur 8 · entraînements de la semaine » pour un passage d'un seul jour : libellé à revoir.
Recommandation : **L1** (seule à montrer le cas Long avec « Arrêter » comme la fiche), en lui ajoutant de L2 « Arrêt prévu » et les jours, très utiles quand on joue jusqu'au match. L3 sert d'habillage pour la création, mais le plein écran photo y est conforme à la fiche.

### 04 Bureau (`04-bureau.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Prochain match en tête, bouton « Préparer le match » en focus | Gabi en grand à gauche (portrait 360 px) : le visage attire avant le match | Priorités en haut à gauche, match à droite |
| Blocs | 4 cartes + bandeau de 3 aperçus : conforme. Objectif du conseil dans la carte des priorités ; forme V/N/D avec lettre | Idem, mais le classement n'a ni J ni forme | Idem + tableau d'absents + tableau des 10 joueurs ; face-à-face de 6 lignes |
| Bouton | « Préparer le match » ivoire, « Vérifier les 23 » en lien | idem | idem |
| Échap/Menu | Menu + Échap en haut ; pied « Échap Menu » présent | idem | idem |

Écarts : **mineur** L1, colonne de Gabi : 230 px vides entre les notes et le portrait. **Mineur** L2, la forme et la colonne J manquent au classement (la fiche les demande) ; le portrait de Gabi domine. **Mineur** L3, le match n'est pas la première chose lue ; le panneau droit et le panneau gauche ont 150 px vides en bas ; la colonne « FORME » du tableau des joueurs porte un nombre (condition ?) : libellé ambigu.
Rappel données : Bureau annonce 31 disponibles, 2 blessés (Gannon, Ollerenshaw) et Northmere à 31 pts ; voir §3.
Recommandation : **L1**, en y remontant le tableau des absents de L3 dans la colonne vide de Gabi.

### 05 Réception (`05-reception.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Courrier prioritaire ouvert à droite (papier ivoire, titre et échéance forts) | Tableau de 13 lignes en haut, courrier en bas : le courrier ouvert est sous la ligne de flottaison visuelle | Courrier ouvert à droite, comme L1 |
| Blocs | Liste groupée par jour, filtres, réponses A/B/C (conséquences ▲▼=, B « Choisie », C indisponible avec raison écrite), « Envoyer la réponse B » + « Annuler » + « Rien ne part sans cette confirmation », Gabi, courrier suivant [Espace] | Idem, colonnes triables (Sujet, Expéditeur, Titre, Échéance, Reçu) | Idem + colonne de dossiers et de sujets avec compteurs |
| Bouton | « Envoyer la réponse B » (1 seul plein) | idem | idem |

Écarts : **mineur** L1, la pastille « À faire 3 » est active mais la liste affiche tous les courriers. **Mineur** L3, filtres en double (pastilles du haut et dossiers de gauche) et compteurs par sujet qui totalisent 15 pour « Tous 14 » (L2 en liste 13). **Mineur** les trois, pas de pied « Échap Menu » exigé par la fiche.
Points forts à garder : confirmation en deux temps, raison de l'indisponibilité visible, sortie « Tout afficher » en L3.
Recommandation : **L1**. C'est le motif maître-détail de la fiche, avec le courrier à traiter immédiatement lisible. Le tableau de L2 est une bonne vue « tout voir » à proposer en option.

### 06 Presse (`06-presse.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | La une du journal (très grand, ivoire) attire d'abord ; la conférence est à droite | **L'état de la conférence est en tête** (4 questions, 1 brouillon, 15 déclarations, 4 journalistes) avec le bouton | Colonne gauche : Ton image puis salle de presse ; la une au centre |
| Blocs | Indicateurs, onglets, journal, tableau de résultats et titres, « Ce qu'on va te demander », mémoire des échanges | Idem, tableaux de titres, résultats et programme | Idem + « Ton image » avec tendances et seuils, « Ce qu'on dit d'Alder Fen » |
| Bouton | « Préparer la conférence » ivoire | idem | idem |

Écarts : **mineur** L1, le bloc principal de la fiche (état de la conférence) passe après le journal. **Mineur** L1, L2, L3, l'onglet « Conférence » porte deux pastilles (« 4 » en blanc et « 2 » en gris) : la « 4 » est un compte de questions, la « 2 » la touche de raccourci ; à séparer. **Mineur** pas de pied de page.
Recommandation : **L2**. Elle met la conférence d'abord et garde les trois jauges avec mot et chiffre. Emprunter à L3 les phrases de seuil sous chaque jauge (« sous tension au-delà de 70 »).

### 07 Effectif (`07-effectif.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | 4 compteurs en haut ; tableau pleine hauteur ; fiche du joueur choisi à droite | Colonne de synthèse à gauche (compteurs, équilibre par poste, échéances) ; tableau ; barre du joueur choisi en bas | Bandeau avec photo ; deux tableaux (Avants, Arrières) côte à côte : les 40 joueurs sans défilement |
| Blocs | Compteurs, filtres, 24 lignes visibles, panneau du choisi avec une action principale « Ouvrir la fiche » | Idem + Équilibre par poste (total 40) et 6 échéances nominatives | Idem ; le panneau du choisi est une barre en bas |
| Bouton | « Ouvrir la fiche » ivoire | idem | idem |
| Échap | Pied « Échap menu » | idem | idem |

Écarts : **mineur** L3, le tri global (par niveau) est impossible quand le tableau est coupé en deux ; la fiche demande un tri sur tout l'effectif. **Mineur** L1, 24 lignes sur 40 : défilement (acceptable : c'est la fiche). **Mineur** les trois, la ligne choisie porte le focus mais la case « Comparer » n'apparaît qu'en L2.
Qualité d'ensemble : statuts avec icône + mot (✚ Blessé (grave), ⌂ En sélection, ! Suspendu), condition en barre + % + repère, fin de contrat avec sablier. Très bien.
Recommandation : **L1**. Le panneau de droite répond à « qui est sélectionné et dans quel état » sans quitter la liste. Y ajouter, de L2, le tableau « Équilibre par poste » et la liste « Échéances de la saison » en bas du panneau (la fiche cite « où sont les fins de contrat » dans ses 5 secondes).

### 08 Fiche joueur (`08-fiche-joueur.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Bandeau : photo, nom, verdict « Titulaire (n° 2) · 94 % · contrat 2027 », niveau/potentiel | Colonne gauche : photo, n°, verdict, niveau, dispo, contrat + bouton, dans l'ordre de la fiche | Bandeau mince + bande de 7 chiffres (Niveau, Potentiel, Condition, Fatigue, Satisfaction, Salaire, Fin de contrat) |
| Blocs | Dispo, points forts, contrat (+ « Proposer une prolongation » sous les données), postes, saison | Idem + saison détaillée (11 colonnes) + « Parmi les 24 talonneurs » | Idem, courbe de note |
| Bouton | 1 seul plein | idem | idem, mais **posé en bas de carte, à 400 px des données du contrat** |
| Échap | Pastille « Retour à l'effectif [Échap] » + pastille « Menu [Échap] » : contradictoire | idem | idem |

Écarts : **bloquant, coque** : voir §2.1 (deux « Échap » opposés). **Mineur** les trois, « ‹ Ollerenshaw 4/40 Fairclough › » : Jowett est 4e (après Stroud, avant Ollerenshaw), le précédent est faux. **Mineur** L3, pas de barre de condition ni de repère à 80 % (exigé par la fiche pour D6). **Mineur** L1, vide de 180 px dans la carte Postes.
Recommandation : **L1**. C'est le wireframe de la fiche, avec le bouton « Proposer une prolongation » collé aux données du contrat. L3 a le meilleur test des 5 secondes (bande de chiffres) : à reprendre seulement si le bouton rejoint la carte Contrat.

### 09 Recrutement (`09-recrutement.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Besoins P1/P2/P3 en cartes, budget de transferts en haut à droite, panneau de la piste | Colonne de gauche : budget, besoins, missions ; tableau pleine largeur | Bandeau avec budget + besoins compacts |
| Blocs | Budget 265 000 € / 420 000 € (155 000 € dépensés, trésorerie « à part »), 24 pistes, filtres, panneau avec « Approcher le joueur » en haut | Idem, détail de la piste dépliée sous la ligne | Idem + « Face à tes talonneurs » et « Ce que coûte l'offre » (barre dépensé / cette prime / reste, masse salariale sur 3 ans) |
| Bouton | « Approcher le joueur » ivoire | idem (dans le détail) | idem, **en bas de panneau, loin de l'offre** |

Écarts : **mineur** L3, le tableau perd la colonne salaire et 2 lignes ; le bouton est à 450 px du coût. **Mineur** L2, le détail déplié pousse les lignes suivantes et fait perdre le repère de lecture.
Le « Budget de transferts » distinct de la trésorerie est correctement traité sur les trois (décision de Léo).
Recommandation : **L1**. Y insérer de L3 la barre « Ce que coûte l'offre » sous le salaire demandé : c'est exactement la réponse à « puis-je me le payer » de la fiche.

### 10 Composition (`10-composition.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Ligne de validité en tête ; terrain à gauche ; impact en colonne à droite | Tableau de 23 lignes à gauche (poste, joueur, note, condition) ; terrain au centre | **Bande « Impact face à Northmere » en haut (6 barres)**, terrain grand, banc en bas |
| Blocs | Terrain, banc 8/8, impact, doublures, avertissements, candidats pour le n° 5 | Idem + panneau « Avertissements » et « Corriger → » | Idem + rappel explicite de la règle (« sans lui la première ligne tombe à 5/6 ») et tableau « Première ligne formée 6/6 » |
| Bouton | « Valider la feuille » ivoire | idem | idem |
| Choisir un joueur | Panneau de candidats trié par note, états grisés + raison | idem, avec recherche et filtres | idem |

Écarts : **mineur** L1, la liste « Doublures » en 16 cases de chiffres est la plus dure à lire (code sans mot). **Mineur** L2, terrain réduit : cartes sans la note au poste. **Mineur** les trois, le terrain place le n° 1 à droite et le 15 à gauche ; la fiche dit n° 1 en haut à gauche : à trancher avec la direction artistique (le sens d'attaque vers la droite justifie la mise en page).
Rappel données : le XV de ce écran ne correspond ni à celui de l'effectif (07) ni à celui du match (14), voir §3.
Recommandation : **L3**. Elle est seule à répondre aux trois questions de la fiche dans l'ordre (feuille valide ? poste sélectionné ? comparaison avec l'adversaire), avec la règle de la première ligne expliquée en mots.

### 11 Préparation (`11-preparation.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Phrase « Danger » en tête ; rapport de force ; « À faire avant le match » | Danger en haut à gauche ; forme ; rapport de force ; XV probable en tableau de 15 lignes | « À faire » en bandeau de 5 cartes **avant** le danger ; rapport de force avec mots « −3 contre toi » |
| Blocs | Rapport de force 6 secteurs, forme (V/N/D + 5 lignes), joueurs à surveiller (3 cartes avec photo), XV probable (15 vignettes), confrontation | Idem sans cartes « joueurs à surveiller » (réduites à des ◆ dans le tableau) | Idem + forme d'Alder **et** de Northmere + face à face |
| Bouton | « Aller au jour de match » **verrouillé** (cadenas, « S'ouvre la veille, ven. 20 nov. ») : raison écrite | idem | idem |

Écarts : **mineur** L2, « Joueurs à surveiller » n'est plus un bloc (exigé par la fiche). **Mineur** L3, ordre : l'état « À faire » passe avant la phrase du danger. **Mineur** L1, flèches ▼/▲ + chiffre : ajouter le mot (« contre toi ») comme L3.
Non traité : la partie B de la fiche (route Entraînement, onglet Semaine) n'a aucune maquette.
Recommandation : **L1**, qui respecte l'ordre danger, rapport, à faire, forme, surveillés. Emprunter à L3 les mots « contre toi / pour toi » dans la colonne centrale.

### 12 Avant-match (`12-avant-match.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Affiche centrée (noms, 15:00, confrontations, météo) ; bouton or en haut à droite avec focus | Affiche en bas à gauche ; bouton or en bas à droite | Affiche en bandeau télé bicolore ; bouton or en haut à droite |
| Blocs | 4 tuiles : feuille (15 barres **avec valeur** et repère 80 %), conditions (météo, vent, pelouse, arbitre et 4 tendances en mots), adversaire, mot de Gabi (3 clés) | Idem, conditions en panneau flottant | Idem condensé : **barres de condition sans valeurs**, tendances d'arbitre partielles |
| Bouton | « Coup d'envoi » seul plein ; « Déléguer le match → » en lien | idem | idem |
| Échap | Pied « Échap retour » ; pastille « Menu [Échap] » | idem | idem |

Écarts : **bloquant L3** : la tuile « Ta feuille » n'affiche aucune valeur de condition (la fiche 6.3 demande « 15 repères avec valeur » ; une longueur de barre ne suffit pas à D6). **Mineur** L1 et L2, bas des tuiles vide sur 130 px. **Mineur** L2, l'état de la feuille (« ! Feuille à vérifier ») est en petit en haut à droite, loin du bouton principal ; **mineur** données : Northmere à 34 pts (voir §3).
Recommandation : **L1**. Elle garde la hiérarchie de la fiche (bandeau d'état et bouton, affiche, quatre tuiles). Prendre le bandeau de noms bicolore de L3 si la direction artistique veut un habillage télé plus fort.

### 13 Match en direct (`hud.md`)

| | L1 | L2 | L3 (en pause) |
|---|---|---|---|
| 5 s | Horloge + score en pilules à gauche ; scène libre | Barre pleine largeur sombre (plus de surface de HUD) ; bandeau d'essai en bas à gauche conforme | Score centré, ligne « en pause » et ligne de possession empilées au centre |
| Boutons | ÉQUIPE (plein), Paramètres, Plus ▾, Pause (focus) | idem | ÉQUIPE, Paramètres, Plus ▾, **Reprendre [Espace]** + « **Échap Menu** » |
| Journal et possession | 2 lignes bas gauche, ligne de possession haut gauche | idem | idem |

Écarts : **bloquant L3** : « Échap Menu » en pause contredit la règle (en match : pause, « jamais menu carrière » ; fiche 14 et hud.md §10.6). Si c'est le menu du match, l'écrire « Échap Reprendre » ou le décrire comme menu du match ; si c'est le menu de carrière, le retirer. **Mineur** L3, le 5e élément permanent dépasse le budget de 8 éléments du hud.md. **Mineur** L2, la barre pleine largeur consomme plus de surface que le budget de 12 % (L1 reste en dessous).
Aucune mise en page ne montre le bandeau de carton, la fenêtre Équipe ni l'écran de fin de match.
Recommandation : **L1** : même contenu, moins de surface de HUD, zone centrale libre.

### 14 Entracte (`14-match-entracte.md`)

Les trois montrent deux états : mi-temps (L1, L2) et arrêt pour blessure (L3).

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Terrain 2D au centre, frise de domination en bas, carte de l'adjoint en pied | Terrain très grand, adjoint en tête de colonne droite | Le panneau de blessure et ses 3 choix (conseillé par le médecin) |
| Blocs | Mon XV (énergie, note), banc 4 + « 4 autres », chiffres clés en barres face à face, frise avec événements nommés | Idem, tableau du XV plus riche (poste, plaquages) ; **banc caché** (« dérouler ») | Domination, terrain, Gabi, XV, banc en texte, stats ; « Valider le choix » |
| Bouton | « Reprendre le match » en focus ; **« Remplacer le 7 → » traité en lien** | idem | « Valider le choix » ivoire seul ; **Équipe, Paramètres et Reprendre barrés avec la raison écrite** |
| Échap | Pied : « Échap Ferme la fenêtre, sinon pause » | idem | **Aucun pied** |

Écarts : **mineur** L1 et L2, l'action principale décidée par l'adjoint (« Remplacer le 7 ») est un lien de 13 px ; la fiche veut un bouton. **Mineur** L2, le banc est caché alors que la décision principale est un remplacement. **Mineur** L3, pas de rappel d'Échap pour une fenêtre bloquante ; les choix de blessure sont des lignes sans bouton radio explicite (le focus est un cadre). **Mineur** chronologie : à 45' Bickerstaff n'est plus blessé et Sowerby est encore sur le banc alors qu'à 38' le choix de l'entrer était déjà posé.
Recommandation : **L1**. Elle est le wireframe de la fiche, avec Mon XV et le banc visibles. L3 est le modèle du panneau d'arrêt (à garder tel quel avec un pied d'Échap).

### 15 Après-match (`15-apres-match.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | V VICTOIRE + 24-21 en bandeau sur photo, puis 3 raisons en lignes numérotées | Les 3 raisons en tête à droite ; le score est en bas à gauche, petit | Score centré, puis 3 raisons en colonnes |
| Blocs | Raisons (▲ POINT FORT / ▼ À CORRIGER, catégorie, texte entier, lien), voir plus, fil du score, Gabi | Idem + feuille de match, classement J9 avec zones et forme, meilleures notes | Idem + « Le match en chiffres » (6 mesures) |
| Bouton | « Ouvrir la conférence de presse » or, focus | idem | idem |
| Échap | Non dit | Non dit | « Échap ne quitte pas cet écran » écrit |

Écarts : **mineur** L2, l'issue et le score sont à 40 px en bas à gauche (la fiche : score final et issue en gros en premier). **Bloquant donnée (L2)** : classement après J9 : Northmere 33 pts, 7V 0N 2D ; à 33 avant (16) + 1 bonus = 34, et il lui manque un nul (voir §3). **Mineur** L1 et L2, ne disent pas « Échap ne quitte pas cet écran ».
Recommandation : **L1** : meilleure lecture (une raison par ligne, ordre de la plus décisive). Y ajouter le classement après la J9 de L2 (3 lignes autour d'Alder) et la phrase de L3 sur Échap.

### 16 Compétitions (`16-calendrier-classement.md`)

| | L1 | L2 | L3 |
|---|---|---|---|
| 5 s | Tableau (ligne du club cerclée, ▲ et barre), **prochain rendez-vous avec « Préparer le match » en haut à droite**, légende des zones | « Ta saison : 4e · 25 pts » + écarts −8 / −2 / +1 à gauche ; tableau ; prochain rendez-vous **en bas** | Autre compétition : « Ton club ne joue pas cette compétition » et menu des compétitions ouvert |
| Blocs | Tableau 12 lignes, légende, calendrier du club (6 prochains), J8 résultats, J9 programme, meilleurs marqueurs et réalisateurs | Idem + calendrier de 22 journées avec résultats V/N/D | Zones du championnat (1-2 demi-finale directe, 3-6 barrage, 13e barrage d'accession, 14e relégué), « Si la saison finissait ce soir », « Le lien avec ta division » |
| Bouton | « Préparer le match » ivoire | idem (en bas) | aucun |
| Onglets | 1 rangée (Classements, Calendrier, Rivalités) + Ctrl+Tab | idem | idem |

Écarts : **mineur** L2, les rendez-vous et le bouton passent sous le pli du tableau. **Mineur** L2, domicile/extérieur par lettres D/E (la fiche 04 impose le mot). **Bloquant donnée** : classement, zones, résultats J8 et programme J9 diffèrent de 04 et 06 (voir §3).
Les zones sont affichées avec symbole (▲ ◆ ▼) + barre + mot, jamais par la couleur seule : la décision n° 5 est tenue, y compris la mention « Pas de relégation automatique ».
Recommandation : **L1** pour les trois choses des 5 secondes dans le premier quart d'écran. Reprendre de L2 le panneau « Ta saison » et les écarts en points, et le menu de compétitions de L3.

### 17 Finances (`17-finances.md`)

Les trois montrent deux onglets (Synthèse pour L1 et L3, Trésorerie pour L2).

| | L1 | L2 (Trésorerie) | L3 |
|---|---|---|---|
| 5 s | Verdict à trois états (✓ / ! SOUS TENSION / ▲) + 3 tuiles : trésorerie, budget de transferts (barre), marge salariale | Verdict dans la colonne, courbe + tableau de 20 mouvements | Verdict + trésorerie + budget dans un bandeau |
| Blocs | Vigilances, échéances, « Où va l'argent », courbe 12 semaines, « Ajuster le budget → » | Idem sans « Où va l'argent » | Budget alloué/engagé/restant avec opérations, masse salariale par joueur, contrats au 30 juin ; **sans « Où va l'argent »** |
| Bouton | « Ajuster le budget » ivoire | aucun plein (« Exporter la saison → ») | « Ajuster le budget » ivoire |

Écarts : **mineur** L1, la courbe prend 40 % de la hauteur pour un bloc secondaire. **Mineur** L3, les répartitions de charges (secondaire 3 de la fiche) sont absentes. **Bloquant donnée** : 7 contrats au 30 juin (L1, L3) contre 6 fins de contrat en 07/09 ; salaire de Jowett 4 100 €/sem. (L3) contre 1 450 €/sem. (07, 08). **Mineur** : « semaine 47 » à côté de « semaine 11 » ailleurs.
Recommandation : **L1** (la hiérarchie de la fiche). Y intégrer le bloc « Budget de transferts » de L3 (alloué, engagé, restant, deux dernières opérations) : il explique à quoi sont passés les 155 k€.

### 18 Club (`18-club.md`)

L3 montre l'onglet Staff, pas la vue d'ensemble : une seule alternative réelle (L1 contre L2).

| | L1 | L2 | L3 (Staff) |
|---|---|---|---|
| 5 s | Confiance 74/100 SOLIDE + objectif de la saison en grande carte | **Trois cartes « À décider » en tête**, avec un bouton plein ; la confiance en 2e rang | Colonne « Le conseil » + « À décider » ; tableau de 26 postes de staff |
| Blocs | Conseil (barre, courbe J1-J8, objectif), À décider (3), vestiaire (moral, disponibles, leader, absents), installations (6 lignes) | Idem + **« Ce qui a fait bouger la confiance »** (J, confiance, résultat, cause) | Staff : rôle, nom, âge, note, contrat, salaire ; fiche du préparateur ; « Prolonger » (plein), « Libérer Rhys Ormerod » (rouge **avec croix et mot**) |
| Bouton | « Fixer un jalon » ivoire | « Fixer un jalon » ivoire | « Prolonger Rhys Ormerod » ivoire |

Écarts : **mineur** L2, la fiche place la confiance et l'objectif en premier ; L2 met les décisions devant. **Mineur** L1, 150 px vides en bas. **Bloquant donnée** : confiance 74 (18) contre 72 (04) ; objectif « 4 premiers » (02, 18) contre « 5 premiers » (04) ; absents et blessés différents (voir §3) ; stade 8 400 places contre 6 200 (02) ; président différent sur 02, 05, 18.
Pour le staff (L3) : la destruction (« Libérer ») est bien distincte (croix + libellé), à confirmer avec libellé précis et focus sur « Annuler » (interaction-patterns W1).
Recommandation : **L1**. Pour répondre à la peur de la fiche (« une confiance qui chute sans cause visible »), remplacer la mini-courbe par le tableau causal de L2.

### 19 Formation (`19-formation.md`)

L2 montre l'onglet Progression (fusion du Suivi des jeunes, décision de Léo) : conforme et lisible, mais non comparable.

| | L1 | L2 (Progression) | L3 |
|---|---|---|---|
| 5 s | En-tête « 60 espoirs · 2 pépites · 4 à décider · 2 places pro libres », tableau de 26 lignes triées « à décider d'abord » | Même en-tête ; Suivi des jeunes (Crabos 26, Espoirs 34), Passerelles (60, 6, 4), À décider, tableau de progression avec barres | Bandeau « La relève » avec 4 compteurs ; **cartes « À décider » à gauche** ; tableau de 25 lignes |
| Blocs | Tableau (Âge, Poste, Niv, Pot, Prog, Minutes, Contrat, Statut), panneau du jeune, « Promouvoir [P] », barre « À décider » en pied | Idem | Tableau **sans** Prog, Minutes, Contrat ; mêmes panneaux |
| Bouton | « Promouvoir » ivoire | « Promouvoir → » en lien | « Promouvoir » ivoire |

Écarts : **mineur** toutes, la fiche veut trois actions (Promouvoir, Garder, Libérer) ; les mocks n'en gardent qu'une et renvoient « Garder ou libérer » à la revue de juin. À confirmer avec le game-designer ; sinon bloquant. **Mineur** L3, trois colonnes de la fiche manquent au tableau. **Mineur** L2, « Promouvoir » est un lien alors que c'est l'action principale.
Recommandation : **L1** (la fiche : tableau principal, panneau, barre « À décider »). Prendre de L3 les cartes « À décider » avec leur raison écrite à la place de la barre d'une ligne.

---

## 5. États de la fiche non couverts par les maquettes

| Écran | États absents |
|---|---|
| 01 | Profil illisible, pack absent, erreur moteur (pas d'inventaire des boutons inactifs avec raison) |
| 02 | Étape 2 « Carrière », recherche sans résultat avec « Effacer la recherche », bouton inactif « Choisis un club » |
| 04 | Première semaine, jour de match, fin de saison, pas de match |
| 11 | Partie B (Entraînement) ; Préparation avec consignes |
| 12 | Feuille invalide (bouton grisé avec raison à côté) |
| 13 | Bandeau de carton, fenêtre Équipe |
| 14 | Pause tactique avec fenêtre Équipe |
| 17 | Onglets Salaires, Transferts, Budget, Classement ; verdict « Dans le rouge » |
| 18 | Vue d'ensemble en L3 ; onglets Direction, Infrastructures, Histoire |
| 19 | Onglets Passerelles, Encadrement ; liste U18 |

Chaque écran étant livré à l'état « nominal », la recette des états reste à faire.
