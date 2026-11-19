# Exigences d'accessibilité — Rugby Legacy 27

Décisions de Léo du 19/11/2026 intégrées : densité « Football Manager » (échelle dense, plancher 14 px supprimé, échelle d'interface obligatoire 90/100/115/130 %) ; Échap ouvre le menu pause sur un écran principal, avec bouton « Menu » visible en plus.

Statut : engagé (ux-designer, 19/11/2026, mode autonome, rigueur minimale).
Entrée de plateforme : PC, souris/clavier, pas de manette prévue, Godot 4.7.
Écrans : 19 écrans de la carrière Monde (voir `design/player-journey.md`).

## 1. Palier engagé : Standard

**Palier : Standard.** Raison : jeu de management dense en texte et en tableaux, joué longtemps en séance ; la lisibilité et la navigation clavier sont le cœur du plaisir, et ce palier est tenable sans refonte moteur. Le palier « Complet » (lecteur d'écran, remappage intégral, multiples modes) est hors cap tant qu'on consolide. « Basique » est insuffisant : les constats ci-dessous (texte 9 px réels, états en couleur) sont déjà sous le bar.

**Palier Standard conservé, avec une exception de densité décidée par Léo (19/11/2026)** : le jeu adopte la densité d'un Football Manager (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px à 1920×1080), donc sous les 14 px que le palier Standard recommande d'ordinaire. L'écart est compensé par trois garde-fous obligatoires : réglage d'échelle d'interface (90/100/115/130 %), contrastes toujours ≥ 4,5:1, couleur jamais seule porteuse d'information.

Les exigences ci-dessous sont **obligatoires** pour le palier. Une exigence marquée « Pas encore » est un écart à corriger avant la sortie, pas un choix.

## 2. Constats sur l'existant (captures 1920)

| Constat | Sévérité | Exigence liée |
|---|---|---|
| Corps de texte 12 px au calque 2560×1440 : 9 px réels à 1920×1080, 6 px à 1280×720 | Bloquant | T1 |
| Étiquettes secondaires (bureau : « PROCHAIN MATCH », « LE GROUPE », pied de page) très petites et grises | Haute | T1, C1 |
| Texte de statut en vert/jaune (« Hors groupe », « Titulaire ») : mot présent, donc non dépendant de la couleur seule | OK | D1 |
| Barres de condition vertes avec pourcentage | OK | D1 |
| Forme V/N/D, blessures, zones de classement : à vérifier couleur seule | À vérifier | D2 à D4 |
| Pied de page des raccourcis gris sombre sur fond sombre | Haute | C1 |
| Direct 3D : maillots orange contre blanc, score en grand ; journal en bas, petit | Moyenne | T2, D5 |

## 3. Exigences

Chaque exigence a un critère vérifiable. Mesure par capture à 1920×1080 sauf mention.

### 3.1 Texte (T)

| ID | Exigence | Critère de réussite |
|---|---|---|
| T1 | **Échelle dense (décision de Léo, 19/11/2026), à 1920×1080 et échelle d'interface 100 %** : corps **~13 px** (≈ 17 px au calque 2560) ; tableaux **12-13 px** ; en-têtes et étiquettes en **capitales 11-12 px** ; **jamais sous 11 px** réels. Le plancher de 14 px est supprimé : la compensation est l'échelle d'interface (E2), les contrastes (C1) et la règle couleur-jamais-seule (D). | Audit automatique : aucun `font_size` effectif < 11 px à 1920 ; corps ≥ 13 px ; tableaux ≥ 12 px ; en-têtes ≥ 11 px |
| T2 | Texte du match (journal, score, bandeau) : **16 px** minimum à 1920, score ≥ 36 px | Mesure capture |
| T3 | Réglage « Taille du texte » dans les réglages : 100 %, 115 %, 130 % (échelle de tout le texte seul, en plus de l'échelle d'interface E2, sans troncature des boutons) | Aucun texte coupé à 130 % sur les écrans ; Pas encore |
| T4 | Police sans empattement lisible, hauteur d'x suffisante ; pas de texte justifié ; interlignage ≥ 1,3 en paragraphe | Revue visuelle |
| T5 | Troncature (« … ») jamais sur une info décisive (nom, poste, montant) ; infobulle ou largeur de colonne ajustable | Revue des tableaux |

### 3.2 Contraste (C)

| ID | Exigence | Critère |
|---|---|---|
| C1 | Texte courant : contraste ≥ **4,5:1** contre son fond réel (y compris sur dégradé ou image : mesurer au pire pixel) | Outil de contraste sur captures |
| C2 | Grands textes (≥ 24 px, ou ≥ 19 px gras) : ≥ **3:1** | idem |
| C3 | Éléments d'interface (contours de bouton, champ, curseur, focus, icônes porteuses de sens) : ≥ **3:1** contre le fond adjacent | idem |
| C4 | Texte désactivé exempté du seuil mais jamais seul porteur d'information ; état désactivé aussi signalé par forme (barré ou icône) | Revue |
| C5 | Texte posé sur image (bureau, intro, tunnel, HUD 3D) : voile ou aplat derrière, contraste garanti quel que soit le décor | Test sur 3 décors clairs/sombres |

Palette « Carnet du club » (ivoire / bordeaux / anthracite) : tout couple de la charte doit être validé en C1 à C3 avant adoption ; la direction artistique me fournit la liste des jetons de couleur.

### 3.3 Couleur jamais seule porteuse d'état (D)

| ID | Exigence | Critère |
|---|---|---|
| D1 | Statuts d'effectif (titulaire, remplaçant, hors groupe, blessé, suspendu) : toujours un mot ou une icône, la couleur n'est qu'un renfort | Capture en niveaux de gris : tout reste distinguable |
| D2 | Forme **V/N/D** : lettre ou symbole dans chaque pastille, pas seulement vert/gris/rouge ; forme distincte (V plein, N demi, D vide ou croix) | Capture en niveaux de gris et simulation de deutéranopie |
| D3 | Blessures : icône spécifique plus gravité en texte (« léger », « grave ») ; pas seulement rouge | idem |
| D4 | Zones de classement (promotion, barrage, maintien, relégation) : liseré + libellé ou icône en plus de la teinte ; légende toujours visible | idem |
| D5 | Équipes dans le direct 3D : maillots distinguables hors couleur (écusson, bandeau, motif de manche) quand deux couleurs sont confondables ; pastilles de l'entracte avec symbole ou contour distinct (forme) | Simulation protanopie/deutéranopie/tritanopie |
| D6 | Barres de condition, fatigue, moral : valeur numérique à côté, seuil marqué par un repère visible | Revue |
| D7 | Réglages : **mode daltonien** (protanopie, deutéranopie, tritanopie) qui remplace la paire vert/rouge par une paire à fort écart de luminosité (par ex. bleu/orange) sur tout le jeu, y compris pastilles de terrain ; Pas encore | Capture avec simulateur |

### 3.4 Clavier et focus (K)

Le jeu est PC : souris **et** clavier doivent suffire séparément pour tout jouer (pas de manette prévue).

| ID | Exigence | Critère |
|---|---|---|
| K1 | Tout élément interactif atteignable au clavier (Tab / Maj+Tab, flèches dans les listes et tableaux, Entrée/Espace pour activer, Échap : ferme la fenêtre, sinon retour d'une fiche, sinon menu pause) | Parcours des 19 écrans sans souris |
| K2 | **Focus visible** : contour ≥ 2 px, contraste ≥ 3:1 contre fond et contre l'élément, jamais supprimé ; distinct du survol et de la sélection | Capture de chaque écran avec un focus |
| K3 | Ordre de focus logique (gauche→droite, haut→bas, barre latérale avant contenu) ; pas de piège : Échap sort de toute fenêtre/mode | Test sur les modales et l'entracte |
| K4 | Raccourcis existants maintenus et documentés dans l'écran Réglages : Espace = Suite/Continuer, 1 à 9 = menus, Échap = fenêtre / retour / menu pause (règle unique, `interaction-patterns.md`), Ctrl+F / Ctrl+K = Recherche, F1 = Aide | Liste affichée et vérifiée |
| K5 | **Remappage** des raccourcis : Pas requis au palier Standard ; en revanche aucun raccourci ne doit nécessiter deux mains éloignées ni une touche mort/composée ; aucun raccourci à une lettre qui s'active pendant la saisie dans un champ | Revue |
| K6 | Cibles souris ≥ 24×24 px à 1920 (boutons, onglets, lignes de tableau : 24-26 px comme Football Manager, décision de Léo) ; boutons d'action fréquente ≥ 28 px de haut ; aucune action n'exige un glisser-déposer sans alternative au clic (composition : sélectionner puis cliquer le poste) | Mesure ; revue |
| K7 | Pas de limite de temps sur une décision de gestion ; pause toujours disponible pendant le match | Revue |
| K8 | Après un changement de page, le focus arrive sur l'élément principal (titre ou première action), pas sur le vide | Test |

### 3.5 Mouvement, animation, flashs (M)

| ID | Exigence | Critère |
|---|---|---|
| M1 | Réglage « Mouvement réduit » (existant) : doit couvrir **toutes** les animations d'interface (transitions de page, fondus, balancements, parallaxe de l'intro, chargement) ; remplacé par des changements instantanés ou fondus de 100 ms | Audit : liste des tweens couverts ; Pas encore vérifié |
| M2 | Réglage « Transitions » : trois valeurs (Normales, Rapides ×2, Aucune) ; applique à toutes les transitions de la coque et du match (tunnel passable d'une touche) | Vérifié par 3 réglages |
| M3 | Intro et tunnel passables (Échap/Espace) dès la première seconde ; jamais obligatoires | Test |
| M4 | **Aucun flash** > 3 par seconde ; aucun flash rouge plein écran ; effets de but et de score en fondu doux ; avertissement d'épilepsie photosensible au premier lancement | Mesure par images ; Pas encore |
| M5 | Animation du visage de Gabi : jamais seule porteuse d'info ; désactivable par « Mouvement réduit » (image fixe) | Revue |
| M6 | Défilement automatique (journal de match, courrier) : arrêtable ; pas de contenu qui disparaît seul sans possibilité de le relire | Test |

### 3.6 Son, voix et sous-titres (S)

| ID | Exigence | Critère |
|---|---|---|
| S1 | **Sous-titres / texte pour toute voix de Gabi** (et toute voix de commentateur) : activés par défaut, désactivables ; nom du locuteur ; ≥ 16 px à 1920 ; fond ≥ 70 % d'opacité ou contour ; au plus 2 lignes de 40 caractères visibles ; durée ≥ durée audio + 0,5 s | Capture ; mesure |
| S2 | Le texte de Gabi reste **toujours consultable dans l'interface** (panneau « Ta semaine, vue par Gabi » et historique du journal), sans écouter l'audio | Vérifié |
| S3 | Aucune information importante uniquement sonore (sifflet, essai, blessure) : toujours un équivalent visuel (texte dans le journal, icône) | Revue |
| S4 | Volumes séparés : Général, Musique, Effets, Voix, Ambiance stade ; chacun de 0 à 100 % | Réglages |
| S5 | Sourdine hors fenêtre (option) et bouton muet rapide | Test |
| S6 | Mention des événements sonores importants du match dans le journal textuel (« sifflet de la mi-temps ») | Revue |

### 3.7 Écran, résolution, échelle (E)

| ID | Exigence | Critère |
|---|---|---|
| E1 | Lisible dès 1280×720 : à cette taille, T1 s'applique **avec l'échelle d'interface à 115 % ou 130 % proposée par défaut** ; aucune troncature d'info décisive | Captures 1280×720 |
| E2 | **Réglage obligatoire** « Échelle de l'interface » dans les Paramètres : **90 / 100 / 115 / 130 %** (met à l'échelle texte, lignes et cibles ensemble), en plus de la taille du texte (T3). Elle compense la densité de T1 ; défaut 100 % | Pas encore ; test à 90 et 130 % sur tous les écrans sans coupure |
| E5 | **Coque** : bouton « Menu » (ou logo/écusson du club en haut du rail) toujours visible, ouvre le menu pause : l'accès à la pause ne dépend pas d'Échap seul | Revue |
| E3 | Plein écran / fenêtré, redimensionnement libre, ultra-large sans étirement ni contenu coupé | Captures 21:9 et 16:10 |
| E4 | Aucune obligation de lire le texte dans une image : les libellés ne sont pas incrustés dans des textures | Revue |

### 3.8 Difficulté et compréhension (G)

| ID | Exigence | Critère |
|---|---|---|
| G1 | Niveau de difficulté / aide de gestion réglable en cours de carrière sans pénalité (Léger, Normal, Exigeant) | Déjà décidé côté game design ; vérifier l'accès |
| G2 | Vocabulaire du rugby expliqué à la demande (infobulle ou lexique) ; Gabi explique, sans bloquer | Revue |
| G3 | Chaque erreur ou refus dit quoi faire (« Corrige le poste de talonneur pour valider ») | Revue des messages |
| G4 | Sauvegarde automatique visible ; erreur d'écriture toujours affichée | Existant ; ne pas régresser |

## 4. Matrice par fonctionnalité

| Fonctionnalité | T | C | D | K | M | S | E |
|---|---|---|---|---|---|---|---|
| Bureau (04) | T1 | C1,C5 | D6 | K1,K2,K8 | M1 | S2 | E1 |
| Réception / Presse (05, 06) | T1 | C1 | — | K1,K2 | M6 | S2 | E1 |
| Effectif / Fiche (07, 08) | T1,T5 | C1,C3 | D1,D3,D6 | K1,K2,K6 | M1 | — | E1 |
| Recrutement / Finances (09, 17) | T1,T5 | C1,C3 | D6 | K1,K2 | — | — | E1 |
| Composition + plan (10) | T1 | C3 | D1 | K1,K6 (alternative au glisser-déposer) | — | — | E1 |
| Préparation (11) | T1 | C1 | D2 | K1,K2 | — | — | E1 |
| Avant-match / Direct (12, 13) | T2 | C5 | D5 | K7 | M2,M3,M4 | S1,S3,S6 | E3 |
| Entracte (14) | T1,T2 | C3 | D5 | K1,K6 | M1 | S1,S2 | E1 |
| Après-match (15) | T1 | C1 | D6 | K1 | M1 | — | E1 |
| Calendrier + classement (16) | T1 | C1 | D2,D4 | K1,K2 | — | — | E1 |
| Club / Formation (18, 19) | T1 | C1 | D6 | K1,K2 | — | — | E1 |
| Titre / Création / Chargement (01 à 03) | T1 | C5 | D1 | K1,K2 | M1,M3,M5 | S2 | E1 |

## 5. Réglages à exposer (écran Réglages)

Taille du texte ; **échelle de l'interface (90/100/115/130 %, obligatoire)** ; mode daltonien ; mouvement réduit ; vitesse des transitions ; sous-titres (activés par défaut) ; volumes séparés ; avertissement photosensible ; liste des raccourcis (lecture seule).

## 6. Hors périmètre (assumé)

- Lecteur d'écran complet : hors palier Standard ; à rouvrir si la bibliothèque d'accessibilité de Godot 4.7 (AccessKit) est stabilisée sur ces contrôles.
- Manette : pas prévue ; si ajoutée plus tard, reprendre K1 à K8 avec cible de focus à la manette.
- Remappage complet : voir K5.

## 7. Vérification et suite

- Audit à lancer : `/ux-review` par écran, comparé aux ID ci-dessus.
- Test automatique à ajouter par un programmeur : balayage des `font_size` effectifs (T1), parcours du focus clavier (K1), simulations de daltonisme sur captures (D2 à D5, D7).
- Défauts connus à traiter en premier : T1, C1 (pied de page), M1 (couverture), M4 (flashs), D2 (forme V/N/D).
- Décision de Léo (19/11/2026), résolue : densité « Football Manager » (corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px à 1080p), au lieu du plancher de 14 px ; compensée par l'échelle d'interface obligatoire (E2), C1 et D.
- Direction artistique : liste des jetons de couleur à fournir pour validation de contraste (C1 à C3).
