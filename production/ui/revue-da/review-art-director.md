# Revue DA des maquettes A/B/C : 19 écrans (phase 4 `/team-ui`)

> Agent `art-director` (CCGS), 19/11/2026. Référence : `visual-identity-options.md` (jetons §1, interdits, recommandation §5).
> Objet : 57 captures 1280×720 (`scratchpad/da2/apercus/NN-id-1|2|3.png`) et les 19 avis `<aside class="avis">`.
> Méthode : chaque capture regardée ; défauts relevés à l'œil (aucune mesure de pixel ni de contraste, donc les tailles de texte sont estimées).
> Verdict global : **CONCERNS**. Les directions tiennent écran par écran, mais trois défauts touchent tout le lot et rendent la comparaison faussée tant qu'ils ne sont pas corrigés : une coque différente selon les écrans, des marqueurs V/N/D différents en A, et des cadres complets en A.

Légende : **[B]** bloquant (trahit un interdit ou casse la cohérence ; à corriger avant de montrer à Léo) ; **[m]** mineur.

---

## 0. Défauts transversaux (valent pour plusieurs écrans)

| # | Défaut | Où | Gravité | Correction |
|---|---|---|---|---|
| T1 | **Trois coques différentes.** 04 à 09 : nom du club et division en tête du rail, Réception en 1 et Bureau en 2, Formation et Sélections sans numéro, Réglages et Sauvegarder en bas, recherche à gauche. 10 à 12 : rail étroit, sous-menu Tactique (Composition, Préparation, Plan de jeu, Match), plus de Formation ni de Sauvegarder. 16 à 19 : logo du jeu en tête, Bureau en 1 et Réception en 2, « Préparation » à la place de « Tactique », recherche et avatar de Gabi à droite, « Continuer » en lien souligné. 06 ajoute en plus « Presse » au rail. Ce problème touche A, B et C. | toutes | **[B]** | Une seule coque pour les 16 écrans de gestion : rail 248 px (à 2560), écusson et nom du club en tête, ordre Bureau 1 · Réception 2 · Effectif 3 · Tactique 4 (sous-menu déplié seulement quand on y est) · Entraînement · Recrutement · Club · Finances · Compétitions · Formation, puis Réglages et Sauvegarder en pied. Barre haute : fil d'Ariane, recherche, date, Gabi, Continuer. Seuls 13, 14 et 15 (le match) sortent de la coque. |
| T2 | **A : cadres complets.** Ligne sélectionnée encadrée (02, 07, 09, 10, 16, 19), boutons pleins `club` doublés d'un contour d'encre de 2 px (04, 05, 06, 08, 12, 15, 18, 19), « Continuer » encadré (04 à 10), étiquettes « À FAIRE » encadrées (05), onglet actif encadré (08), bascule U21/U18 (19), encart « Sous tension » (17). | A | **[B]** | Ligne choisie : `club` 8 % + filet gauche 3 px, rien d'autre. Bouton plein : aplat `club` sans contour ; le focus clavier se montre par un soulignement de 2 px `encre` sous le bouton, et non par un cadre au repos. Continuer : lien souligné avec flèche (déjà fait en 16 à 19). Étiquettes : texte `club` en petites capitales, sans cadre. |
| T3 | **A : quatre façons d'écrire V/N/D.** Pastilles rondes pleines (04, 08, 12), carrés pleins + rond cerclé + carré pointillé (11), carré plein pour V et ronds vides pour N et D (16). En B et C, le marquage est aussi différent d'un écran à l'autre (carré, losange, triangle en 11-B ; carré dans les autres). | A surtout, B, C | **[B]** | Une seule pastille par direction, posée dans les jetons : A = rond plein 999 px + lettre ; B = carré plein + lettre ; C = V plein / N rond / D pointillé (la règle de 16-C est bonne, l'étendre). La forme daltonienne (carré, rond, triangle) reste une option des réglages, pas une variante par écran. |
| T4 | **A : le vert sort de V/N/D.** Jauge de confiance verte (18), « +620,0 k€ » en vert géant (17), attributs forts en vert et faibles en rouge (08), « Conférence ouverte » en vert (06). Le §5 dit « le vert redevient uniquement victoire / disponible ». | A | **[B]** (17, 18) / [m] | Jauge et argent en `encre` ; tendance par ▲ ▼ en `encre-2` ; seul un vrai V ou « Disponible » prend `v`. Attributs : chiffre en `encre`, signe + / – en tête de ligne (déjà présent). |
| T5 | **A : `or-vieilli` sous 16 px ou hors de son rôle.** Pastille « Fin de contrat » (08), étoiles de suivi (09), « ! 2 avertissements » (10), « juin 2027 · fin de saison » (07, 08), encart « Sous tension » (17). | A | [m] (B en 17) | `or-vieilli` réservé aux distinctions ≥ 16 px. Une fin de contrat ou un avertissement passe en `n` + sablier ; l'alerte « Sous tension » en `club` avec « ! », sans cadre. |
| T6 | **A : pastilles à 999 px hors V/N/D.** Filtres de l'effectif (07), « Marché des joueurs » (09), « Fin de contrat » (08), numéros de maillot ronds (07). | A | [m] | Filtres en onglets soulignés ; numéros de maillot en Barlow Condensed nu, sans pastille. |
| T7 | **A : portraits hors règle.** Tous les visages sont des photos studio sur fond gris, carrées et en pleine couleur ; on ne voit ni détourage, ni sépia 10 %, ni cadrage poitrine. Le filigrane du numéro est en Barlow en 08 et en Fraunces en 19. | A | [m] | Appliquer la règle du §1-A partout (détourage sur `carte`, sépia 10 %, numéro géant en `filet` derrière, toujours en Barlow Condensed). Tant que l'atlas ne permet pas de détourer : vignette carrée, sépia, filet `club` en pied. |
| T8 | **A variante « encre » sans jeton `club`.** En 07 et 09, le bordeaux est éclairci en rose saumon pour tenir sur `nuit`, mais aucun jeton n'est défini, et l'ambre des fins de contrat en fait une deuxième couleur forte. | A encre | [m] | Ajouter `club-encre` (bordeaux éclairci jusqu'à ≥ 4,5:1 sur `#1F262B`) et limiter `n` aux vrais nuls ; « fin de contrat » en `encre-2` + sablier. |
| T9 | **Gabi présent un écran sur deux.** En A, il apparaît dans le corps en 04, 06, 12, 14, 15, 16 et 18, et manque en 05, 07, 08, 09, 10, 11, 17 et 19. En B et C, la répartition est différente. | toutes | [m] | Gabi toujours visible dans la barre haute (visage + F1). Dans le corps, uniquement sur les écrans de décision : 04, 05, 11, 12, 14, 15, 16, 17. Même forme partout : en A, une note en marge à filet `club` ; en B, un médaillon cerclé `essai` ; en C, un duotone. |
| T10 | **Données qui changent d'une maquette à l'autre.** Le XV de l'entracte (14 : Bickerstaff n° 1, Smart n° 2 alors qu'il est blessé, Fairclough n° 7) contredit la composition (10 : Fairclough n° 1). L'effectif affiche 38/41 aptes et le club 38/40 disponibles. Le recrutement compte 6 pistes en A et 7 en B et C. | 09, 10, 14, 18 | [m] | Un seul jeu de données pour les trois directions : sinon Léo compare des contenus, pas des styles. |
| T11 | **B : la couleur `essai` sert à tout.** On la trouve sur le bouton « Remplacer le 7 » (14), la zone « Montée » et l'étiquette « Prochain rendez-vous » (16), la bannière « Danger » (11), « Sous tension » (17), « Fin de contrat » (08, 09), et les triangles d'alerte (11, 17, 18). Elle ne marque plus le moment fort. | B | **[B]** sur 14 et 16 (écrans où B est retenu) | `essai` uniquement pour l'essai, le record et la bannière unique. Bouton d'action = `club`. Montée et barrages = filet latéral `data` + ▲ / ◆ (spec §1-B). Alertes = `d` + pictogramme. |
| T12 | **Double date** (« Samedi 21 novembre 2026 » en barre haute et dans la ligne d'état). | 12 (A, B, C) | [m] | Garder la date en barre haute seulement. |

---

## 1. Par écran et par direction

### 01 Accueil
- **A** : [m] Le bouton « Reprendre la carrière » a un contour d'encre (T2). [m] La colonne droite reste vide entre « Identités et packs » et le pied, sur environ 90 px : remonter Gabi (citation d'accueil) dans ce vide. [m] Gabi est réduit à « Gabi · ? (F1) » à 14 px, trop discret pour la porte d'entrée.
- **B** : [m] La photo est voilée au point de disparaître (voile > 50 % : on ne voit plus le stade). [m] Le contour blanc de « Reprendre » s'ajoute au parallélogramme : deux signatures pour un seul bouton.
- **C** : [m] Les repères de terrain lus de gauche à droite sont « 22 · 10 · 50 · 10 », avec des écarts inégaux ; la grille-terrain est fausse (il manque le second 22, et le 10 tombe avant le 50). [m] La moitié basse gauche est vide, à part une flèche décorative qui ne dit rien.
- **Avis** : il est conforme à §5 (A).

### 02 Création de carrière
- **A** : [B] La tuile choisie a un cadre noir complet + un fond bordeaux + une pastille « ✓ Choisi » + un filet gauche : quatre signaux pour un seul état. Ne garder que le fond `club` 8 % et le filet gauche. [m] Gabi est absent du corps alors que C l'a (citation sur le budget) : à reprendre en A, sous la fiche.
- **B** : [m] Les noms longs passent sur deux lignes en capitales (« MEADOWBRIDGE ROVERS ») ; c'est l'argument même de l'avis.
- **C** : [m] Le chiffre « joueurs » en chasse fixe est espacé à l'excès (« 52  joueurs »). Sinon, c'est propre.
- **Avis** : [m] il propose d'emprunter à B « le rang en filigrane », alors que la maquette A l'a déjà (1 à 6 en `filet`). Remplacer cet emprunt par la citation de Gabi prise à C.

### 03 Chargement
- **A** : [m] Le glyphe « H » au bout de la barre (des poteaux, sans doute) se lit comme la lettre H : le retirer, ou le dessiner comme un vrai poteau en filet. [m] La touche « Échap » est encadrée ; on peut la tolérer comme touche de clavier, mais il faut le même style partout (en 05, « Espace » l'est aussi).
- **B** : bon. [m] Le médaillon de Gabi déborde du panneau d'un côté seulement.
- **C** : [m] Les dates « MAR 17.11 / MER 18.11 » sont en cadres complets ; le petit terrain n'a pas ses lignes de 10 m.
- **Avis** : il est conforme (A, terrain de C, B pour l'entrée en match). Je valide cette règle.

### 04 Bureau
- **A** : [B] « Préparer le match » a un contour, et « Continuer » est encadré (T2). [m] Les quatre notes de Gabi forment quatre petites cartes empilées : réunir en une seule colonne séparée par des filets (c'est le « tout est un cadre » qu'on corrige). [m] La rubrique « 03 / Le groupe » est dans une surface `carte`, alors que « 01 / À décider » est sur le papier : deux traitements pour des rubriques de même rang.
- **B** : c'est la démonstration du risque §1-B : quatre accents (club, adversaire, `essai`, `data`) sur un écran de semaine. Il n'est pas retenu, et c'est bien ainsi.
- **C** : [m] Les étiquettes de colonnes « 22 / 10 / milieu → leur 22 » sont décoratives et sans ordre réel. [m] La flèche du bloc « Prochain match » ne porte aucune information.
- **Avis** : il est conforme. L'emprunt « J-4 » de B est bon, à poser en Barlow Condensed dans l'affiche `nuit`.

### 05 Réception
- **A** : [B] Les étiquettes « À FAIRE · AVANT LE 19/11 » sont encadrées, et « À FAIRE · RÉPONDS AVANT LE JEUDI 19/11 » a 6 mots en capitales (limite : 4). [B] « Envoyer la réponse » a un contour (T2). [m] La boîte n'a ni Gabi ni son visage, alors que la réponse « conseil de Gabi » est l'élément clé.
- **B** : [m] Les étiquettes `essai` « À FAIRE » pleines sont mêlées à l'« URGENT » rouge : deux couleurs d'alerte pour deux niveaux, c'est acceptable en B.
- **C** : [m] Les trois réponses sont des cartes encadrées (« pas de cartes » en C). [m] « Indisponible » en `brique` se confond avec « Urgent ».
- **Avis** : il est conforme. L'emprunt « étiquettes pleines de B » contredit la règle « un seul bouton plein » de A. Je préfère : texte `club` en gras + ● devant, sans aplat.

### 06 Presse
- **A** : [m] Dans le bandeau `nuit`, la photo ne se voit que sur 100 px au bord droit (un demi-visage) : soit l'élargir en fond voilé, soit la retirer. [m] « Conférence ouverte » est en vert (T4). [m] La colonne droite a un vide entre Gabi et « Mémoire des échanges ». [m] « Presse » est ajouté au rail (T1).
- **B** : [m] Le titre de une en capitales sur 7 mots est lourd (B l'autorise, mais c'est moins lisible qu'en A).
- **C** : bon.
- **Avis** : il est conforme. [m] Il annonce « un seul bandeau sombre derrière la photo », mais la photo est presque absente de la maquette.

### 07 Effectif
- **A encre** : [B] La ligne choisie a un cadre blanc complet (T2). [m] Les filtres sont des pastilles rondes, et les numéros de maillot sont dans des ronds blancs (T6). [m] Le jeton `club` rose n'est pas défini (T8), et l'ambre se répète sur 4 lignes. [m] Le pied du panneau joueur (« Prolonger / Comparer ») est coupé à 720.
- **B** : [m] La pastille « BLESSÉ DANS LE XV » est rouge vif, à côté de l'aplat club rouge du panneau joueur : rouge `club` et `d` côte à côte, sauvés par la lettre et la croix.
- **C** : c'est le meilleur des trois en lecture. Portraits en duotone et couleur à la sélection seulement (règle tenue), regroupement par ligne, numéros pointillés pour les remplaçants.
- **Avis** : il est conforme (A encre + regroupement de C). Je le valide, en ajoutant le numéro pointillé des remplaçants pris à C.

### 08 Fiche joueur
- **A** : [B] Le portrait est une photo studio grise sans traitement (T7), sur l'écran même dont l'avis dit « un visage chaud ». [B] L'onglet actif « Vue d'ensemble » est encadré en noir. [m] « Fin de contrat » est en pastille `or-vieilli` d'environ 13 px (T5, T6). [m] Les attributs sont en vert et rouge (T4). [m] Le schéma de poste est dans un cadre complet.
- **B** : [B] La plaque `essai` « FIN DE CONTRAT » à côté du bandeau club fait deux bannières, et utilise `essai` pour un statut (T11). [m] La colonne « Disponibilité » a 80 px de vide au-dessus du lien.
- **C** : bon. Le duotone et le schéma de poste en tracé sont la meilleure fiche ; [m] le « n° 02 · talonneur » en `poteau` détourne la couleur de sélection.
- **Avis** : il est conforme (A). L'emprunt du schéma de C est juste.

### 09 Recrutement
- **A encre** : [B] La tuile « Priorité 1 » a un cadre blanc complet, et la ligne choisie aussi (T2). [m] La pastille ronde « Marché des joueurs » est cerclée de rouge (T6). [m] Les étoiles `or-vieilli` font environ 14 px (T5). [m] Il y a un vide sous le tableau, et 6 pistes contre 7 ailleurs (T10).
- **B** : [m] Le fond du portrait de la piste est en `adversaire` bleu : le bleu veut dire « camp adverse », pas « cible ».
- **C** : bon ; « ▲ rapport » est une idée nette.
- **Avis** : il est conforme (A encre).

### 10 Composition
- **A (+ composant C)** : [B] Le « tableau noir » n'est pas un terrain : 15 boîtes encadrées sur un fond `nuit`, sans ligne de touche, de 22 ni de 10 m. C'est un cadre de cartes, pas le composant C promis. Il faut tracer le terrain (lignes `craie` 2 px, pointillés de 5 m) et y poser des pastilles numérotées, comme en 14. [B] La ligne de candidat choisie est encadrée (T2). [m] Accents simultanés : `club`, `poteau` (« choisi »), ambre (avertissements), rouge (79 %), vert (« Feuille valide »). Le cadre jaune « choisi » importé de C ne doit être que le focus. [m] La coque est différente (T1).
- **B, C** : [m] Ils partagent le même faux terrain en boîtes ; même correction.
- **Avis** : [m] « le terrain à la craie » décrit ce que la maquette ne montre pas. L'avis est juste sur le fond, la maquette est à refaire.

### 11 Préparation
- **A (+ composant C)** : [B] Les V/N/D de « Leur forme » sont des carrés, un rond cerclé et un carré pointillé, différents de 04 et 12 (T3). [m] Le rapport de force sur `nuit` est un graphique en barres, pas un tableau noir. C'est acceptable, mais l'avis parle de « tableau noir ». [m] Couleurs : `club`, bleu adverse, vert ▲, rouge ▼, ambre « ! ». Garder le bleu adverse (il est justifié), et passer ▲ ▼ en `encre`. [m] Les trois portraits adverses sont en couleur studio (T7).
- **B** : [m] Le bandeau « Danger » est `essai` et les triangles d'alerte aussi : une bannière et trois rappels de la même couleur (T11).
- **C** : bon.
- **Avis** : il est conforme. [m] Il « garde la bannière Danger pour l'avant-match », mais l'avis 12 ne la reprend pas : l'idée se perd entre les deux écrans. À reporter dans 12-B.

### 12 Avant-match
- **B (retenu)** : [B] L'écran reste dans la coque de gestion (rail, « Tactique › Match »). Le §2 fait de l'avant-match le point fort de B (« générique, compositions ») : il doit sortir du rail, en plein écran, avec le tunnel en fond et les deux XV. [B] « EN DIRECT DE » avant le coup d'envoi est un faux sens : écrire « Ce soir à » ou « Coup d'envoi ». [m] Les quatre liserés de panneau (rouge, cyan, bleu, jaune) sont de la couleur décorative sans sens. Il faut un seul liseré `club` sur « Ta feuille » et rien sur les autres. [m] La barre du n° 7 en `essai` est un avertissement (T11). [m] Il y a deux boutons à fond plein (« Feuille validée » vert et « Coup d'envoi »).
- **A** : c'est la version la plus aboutie des trois sur cet écran (affiche `nuit`, quatre rubriques). [m] « Coup d'envoi » a un contour (T2).
- **C** : [m] Les écussons en aplat bordeaux et bleu contredisent « club en trait seulement ».
- **Avis** : il est conforme à §5 (B). Mais la maquette B est la plus faible des trois sur cet écran : l'avis retient B sur le principe, sans dire qu'il faut la refaire.

### 13 Match en direct
- **B (retenu)** : c'est le meilleur HUD. Score et horloge protégés, une seule bannière « ESSAI +5 » dans le tiers inférieur, journal court. [m] La plaque `adversaire` est bleue alors que Northmere joue en blanc sur le terrain. Il faut prendre la couleur du maillot (plafonnée) ou un liseré neutre, pour que la plaque désigne vraiment l'équipe qu'on voit. [m] La spec dit que l'horloge s'efface pendant la bannière ; la maquette la garde (c'est un état statique, mais il faut le préciser au programmeur).
- **A** : il est hors registre (§2), comme prévu. Ses plaques papier sur la 3D jurent.
- **C** : bon état « pause ». [m] Le minuteur d'exclusion de C (« 10:00 ») est une idée à reprendre en B.
- **Avis** : il est conforme. J'ajoute l'emprunt du minuteur d'exclusion.

### 14 Entracte
- **B (retenu)** : [B] « Remplacer le 7 » en `essai` (T11) : le bouton doit être `club`. L'avis justifie ce jaune par « l'unique appel à l'action », ce qui contredit le jeton. [m] Le XV listé contredit la composition (T10). [m] La colonne droite a un vide sous « Voir toutes les stats ». [m] « ÉQUIPE » a un contour rouge en plus de son aplat.
- **A** : bon ; il est hors registre, mais c'est le plus lisible.
- **C** : bon ; la flèche d'action tracée est l'emprunt à faire.
- **Avis** : il est conforme (B + terrain de C), sauf la justification du jaune.

### 15 Après-match
- **B (retenu)** : [m] Il manque la photo ou l'illustration (le §1-B prévoit un plein cadre) et les « temps forts ». L'écran est trois bandeaux et un bouton, avec un vide entre 560 et 600. [m] « Ouvrir la conférence de presse » a un aplat + un contour blanc. [m] Les chiffres clés sont noyés dans le texte en `data` : l'avis a raison de vouloir le gros chiffre de C.
- **A** : [B] « OUVRIR LA CONFÉRENCE DE PRESSE » fait 5 mots en capitales, et le bouton a un contour. [m] Il y a un vide entre 560 et 640.
- **C** : c'est la meilleure des trois versions sur le fond (gros chiffre + phrase). [m] Les boutons « Voir la… » sont encadrés.
- **Avis** : il est conforme à §5 (B + C).

### 16 Calendrier / classement
- **B (retenu)** : [B] La montée est en `essai`, les barrages en `data`, et l'étiquette « Prochain rendez-vous » est aussi en `essai` : la spec veut montée et barrages en filet `data` (▲ / ◆) et `essai` réservé à la bannière (T11). [m] Le photo de l'affiche est voilée au point d'être illisible. [m] Il y a un vide sous Gabi. [m] La coque est différente (T1).
- **A** : [B] La ligne du club a un cadre bordeaux complet, et les V/N/D sont dans une troisième variante (T2, T3). Sinon l'écran est très lisible.
- **C** : c'est la meilleure maquette de l'écran : les lignes de montée, de barrage et de relégation tracées comme des lignes de terrain sont la seule idée vraiment rugby du lot. À emprunter en B (filets pleins, pointillés, avec un mot sur la ligne).
- **Avis** : il est conforme à §5 (B). Je change l'emprunt : prendre les **lignes de zone de C**, pas seulement la phrase de A (que B a déjà, dans la bulle de Gabi).

### 17 Finances
- **A** : [B] « Sous tension » est dans un cadre complet `or-vieilli` (T2, T5), et « +620,0 k€ » est en vert géant (T4). [m] Gabi est absent (C l'a, avec la bonne phrase). [m] L'avis parle du « grand livre à l'encre comme bloc sombre », alors que le bloc sombre est la courbe du solde. §5 met le grand livre en A encre : c'est l'onglet « Grand livre » qui doit être sombre, pas la synthèse.
- **B** : c'est l'illustration du « trop criard » : `essai` sur une alerte, vert et rouge géants.
- **C** : bon. La flèche annotée sur la courbe est l'emprunt juste, déjà cité par l'avis.
- **Avis** : il est conforme (A), avec la nuance sur le bloc sombre.

### 18 Club
- **A** : [B] La jauge de confiance est vert vif (T4) : il faut la passer en `encre` sur `nuit` (texte `nuit-texte`), avec les repères 40 / 70 en filet. [m] Le bloc `nuit` est à moitié vide (de 480 à 590) et la photo du stade ne s'y voit presque pas : soit remonter Gabi et l'objectif, soit voiler moins. [m] Bouton à contour (T2). [m] 38/40 contre 38/41 (T10).
- **B** : [m] Vide en pied. Il n'est pas retenu.
- **C** : [m] La jauge-terrain (menacé / fragile / solide) est en cadre complet ; vide sous Gabi.
- **Avis** : il est conforme (A). Il dit « la jauge garde chiffre, mot et repères » : c'est vrai, mais elle est verte.

### 19 Formation
- **A** : [B] Ligne choisie encadrée, et contour sur « Promouvoir » (T2). [m] Le portrait est studio (T7) ; le filigrane « 15 » est en Fraunces alors que celui de 08 est en Barlow. [m] Il y a un vide sous le tableau, et Gabi est absent. [m] La bascule U21/U18 est encadrée.
- **B** : [m] Les noms en capitales dans un tableau de 10 lignes ralentissent la lecture.
- **C** : bon. La courbe de progression du joueur choisi est un plus à emprunter en A.
- **Avis** : il est conforme (A). J'ajoute l'emprunt de la courbe de progression de C.

---

## 2. Classement

**Les 3 meilleurs** (direction retenue) :
1. **04 Bureau, A** : la hiérarchie v6 est tenue (une affiche `nuit`, un bouton, Gabi en marge, trois décisions numérotées). Il reste à enlever les contours.
2. **13 Match en direct, B** : HUD mince, une seule bannière, score dominant. C'est exactement le §1-B.
3. **01 Accueil, A** : une photo, une colonne, un bouton. C'est la porte d'entrée la plus calme et la plus chaude.
(Mention hors direction retenue : **16-C**, pour les lignes de zone tracées.)

**Les 3 plus faibles** (direction retenue) :
1. **10 Composition, A** : le « tableau noir » est un tas de cartes encadrées sans terrain, avec cinq accents.
2. **12 Avant-match, B** : il reste dans le rail, affiche « En direct » avant le coup d'envoi et des liserés multicolores sans sens ; c'est le point fort de B, rendu en écran de gestion.
3. **18 Club, A** : la jauge est verte, le bloc sombre à moitié vide et la photo invisible.

---

## 3. Recommandation finale consolidée

| # | Écran | Direction retenue | Emprunts (précis) | À refaire avant Léo |
|---|---|---|---|---|
| 01 | Accueil | **A** | B : plaque de carrière à filet gauche `club` (déjà là) | Bouton sans contour ; Gabi remonté dans le vide de la colonne |
| 02 | Création | **A** | C : citation de Gabi sous la fiche ; B : rien (le filigrane est déjà en A) | Tuile choisie sans cadre |
| 03 | Chargement | **A** ; **B** pour « Préparation du coup d'envoi » et « Simulation » | C : petit terrain-barre avec 22 / 10 / 50 tracés | Retirer le « H » |
| 04 | Bureau | **A** | B : « J-4 » en gros chiffres dans l'affiche | Contours ; notes de Gabi en une colonne |
| 05 | Réception | **A** | C : ▲ ▼ devant les effets ; pas d'étiquettes pleines | Étiquettes sans cadre, ≤ 4 mots en capitales |
| 06 | Presse | **A** | B : score de notre match en plaque `club` dans les résultats | Photo du bandeau visible ou retirée |
| 07 | Effectif | **A encre** | C : regroupement par ligne, chiffres alignés, n° pointillé des remplaçants | Jeton `club-encre` ; filtres soulignés |
| 08 | Fiche joueur | **A** | B : numéro géant en filigrane ; C : schéma de poste tracé | Portrait traité ; onglet sans cadre ; attributs sans vert |
| 09 | Recrutement | **A encre** | C : « ▲ rapport » | Tuile prioritaire sans cadre ; étoiles ≥ 16 px ou en `encre` |
| 10 | Composition | **A + composant C** | C : vrai terrain à la craie (lignes, pastilles numérotées comme 14), chiffres alignés, jaune = focus seul | **Refaire le terrain** |
| 11 | Préparation | **A + composant C** | C : six secteurs communs avec 10 ; bleu adverse conservé | V/N/D unifiés ; ▲ ▼ en `encre` |
| 12 | Avant-match | **B, plein écran** | A : numéros de rubrique dans les tuiles ; B (depuis 11) : bannière « Danger » unique | **Sortir du rail**, retirer « En direct de », un seul liseré |
| 13 | Match en direct | **B** | C : plein / anneau à côté des noms, minuteur d'exclusion | Plaque adverse à la couleur du maillot |
| 14 | Entracte | **B** | C : terrain tracé + flèche de l'action | Bouton d'action en `club`, pas en `essai` |
| 15 | Après-match | **B** | C : gros chiffre clé par raison | Ajouter photo voilée et temps forts ; bouton sans contour |
| 16 | Calendrier, classement, rivalités | **B** | **C : lignes de montée, barrage et relégation tracées** ; A : phrase-chapeau | Montée et barrages en `data`, plus de `essai` |
| 17 | Finances | **A** (onglet Grand livre en A encre) | C : flèche annotée sur la courbe ; C : Gabi | « Sous tension » sans cadre ni or ; montants en `encre` |
| 18 | Club | **A** | C : flèche de tendance | Jauge en `encre` ; bloc sombre recomposé |
| 19 | Formation | **A** | C : courbe de progression ; ▲ ▼ | Contours ; filigrane en Barlow |

Le §5 n'a pas de maquette pour **Plan de jeu**, **Entraînement**, **Grand livre**, **Rivalités** et **Calendrier** (seul l'onglet Classements est montré) : ces écrans ne sont pas évalués ici.

## 4. Ordre de correction conseillé

1. **T1** : une seule coque (sans elle, la comparaison des 16 écrans de gestion est biaisée).
2. **T2 + T3** : contours et V/N/D en A (deux règles à corriger dans la feuille de style commune ; elles corrigent 14 écrans).
3. **T11** : `essai` remis à sa place en B (concerne 12, 14 et 16).
4. Refaire **10-A** (terrain) et **12-B** (plein écran).
5. Puis seulement montrer à Léo, une maquette par écran dans la direction retenue, A/B/C en annexe.
