# Revue d'accessibilité — maquettes en direction unique (DA3)

Date : 19/11/2026. Agent : `accessibility-specialist` (CCGS), phase 4 de `/team-ui`.
Critère : `design/accessibility-requirements.md` (palier Standard, exception de densité de Léo : corps 13 px, tableaux 12-13 px, jamais sous 12 px à 1920×1080 ; contrastes >= 4,5:1 ; couleur jamais seule ; focus visible ; cibles >= 24 px). Niveau de référence : WCAG 2.1 AA.
Objet : 19 fragments `da3\frag\*.html`, 3 propositions chacun, soit 57 écrans (1920×1080), jetons `da3\base.css`, captures `da3\apercus\`.

## Méthode et limites

- Script Playwright (Edge, 2000×1200, page montée comme `apercu.py`, `transform: none`) : pour chacun des 57 `.ecran`, 12 761 nœuds de texte visibles mesurés (taille calculée, graisse, couleur, opacité cumulée, rognage par `overflow`). Les textes SVG sont mesurés à la taille rendue (taille déclarée × échelle du viewBox).
- Contraste : capture de l'écran avec tout le texte rendu transparent, puis échantillon des pixels réels sous chaque boîte de texte ; le texte est composé avec son opacité puis comparé à chaque pixel. Valeurs retenues : médiane (fond dominant) et part de pixels sous 4,5:1 ; les cas suspects ont été revus sur capture agrandie (les rognures de boîte, anneaux de focus et pastilles donnent des « pires pixels » parasites, écartés après vérification).
- Revue visuelle de captures : V/N/D (agrandi 4× à 12×), couleur seule, focus, cibles (hauteurs mesurées par balisage), troncatures (`text-overflow`, `line-clamp`).
- Script : `scratchpad\a11y\mesure.py` (collecte), `an2.py`, `an3.py`, `an4.py`, `trunc.py` (analyses).

**NOT ASSESSED** (non vérifiable sur des maquettes statiques à 1920×1080) :
- E1 / E2 : rendu à 1280×720 et aux échelles 90 / 130 % (aucune coupure) ; T3 : taille du texte à 130 %.
- K1 / K3 / K8 : ordre de focus, pièges, focus après changement de page (les maquettes ne montrent qu'un focus par écran).
- D7 (mode daltonien), M1 à M4 (mouvement, flashs), S1 durée des sous-titres, S4 / S5. Simulations de daltonisme non lancées (pas d'outil local) : D2 et D5 jugés par la forme et la luminance relative des jetons, à confirmer par simulation sur le build.
- C5 sur « 3 décors » : un seul décor par écran.

## Verdict

**BLOQUANT : 2 constats à corriger avant de passer à l'implémentation** (gate BLOCKING au sens de l'agent). Le reste est mineur.

1. **N (Nul), pastille demi-pleine : lettre illisible ou contraste insuffisant dans 3 constructions sur 4** (D2, SC 1.4.3). Écrans 04, 12 (marginal), 16. Détail ci-dessous.
2. **Écran 14 (entracte), numéros de maillot sur pastilles club : 4,26:1** < 4,5:1 (SC 1.4.3), variantes 1, 2 et 3 (jusqu'à 2,3:1 en variante 3).

Points solides : aucun texte HTML sous 12 px sur les 57 écrans ; contraste >= 4,5:1 sur tous les textes courants de la coque et des tableaux (le plus faible : `--ivoire-3` sur `--panneau-2`, 4,53:1) ; focus ivoire 2 px présent et très contrasté (>= 5,5:1 contre fond) sur 55 écrans sur 57 ; statuts d'effectif, blessures, zones de classement, barres de condition : toujours mot ou icône en plus de la teinte ; V et D lisibles (lettre + forme) ; cibles de ligne et boutons >= 24 px.

## V / N / D : la pastille N demi-pleine est-elle lisible ?

Taille des pastilles : 22 × 16 px environ, lettre de 12 px. Quatre constructions de N coexistent (pas de composant unique) :

| Construction | Écrans | Mesure et constat | Gate |
|---|---|---|---|
| A. Moitié gauche `--n`, lettre en dégradé `--nuit` / `--n` coupé au milieu de la **lettre** (`.pv.n b`, `background-clip: text`) | 04 (v1 : 3 pastilles ; v3 : 1) | Le milieu du dégradé est calculé sur la boîte de la lettre (9,75 px), pas sur la pastille (22 px) : à 12× la lettre est tronquée, une partie `--n` sur remplissage `--n` (1,0:1), une partie `--nuit` sur fond sombre (1,0:1). Lecture « N » possible à cause de la forme seule. | **BLOQUANT** (lettre non lisible, D2 exige une lettre dans chaque pastille) |
| B. Anneau `--n` + remplissage `--n` à 42 %, lettre `--ivoire` (`.pv.n::before`) | 11, 12 | Médiane 6,8:1, lisible. Mais le remplissage est plein (plus de « demi » : D2 demande V plein / N demi / D vide) et la couleur du demi vaut pour un 12 px. Bord 2,1:1 au pire pixel (liseré), sans conséquence. | OK pour le contraste ; mineur pour la forme |
| C. Anneau `--n` + remplissage `--n` sur les 30 % du bas, lettre `--ivoire` | 16, 17, 18, 19 (légende et forme) | Médiane 14,5:1 (fond sombre en haut) mais le pied de la lettre (2 px) tombe sur `--n` : 2,1:1. Lisible dans la pratique, forme « demi » respectée. | Mineur |
| D. Demi-anneau mini + lettre `--n` à côté | 07, 08, 09 (forme des 5 derniers matchs) | Lettre `--n` sur `--panneau` : 7,7:1, lisible. Pastille 18 × 12 px. | OK |

**Correction (jetons existants)** : un seul composant « pastille N ». Anneau `--n` 2 px, remplissage de la **moitié gauche** en `--n` à 42 % d'opacité (rgba du jeton `--n`), lettre `--ivoire` entière : ivoire sur le remplissage ≈ 6,7:1, sur `--panneau` ≈ 15,8:1, et la forme « demi » est conservée. Supprimer la construction A (`background-clip: text`). V (lettre `--nuit` sur `--v`, 9,9:1) et D (lettre `--d` sur `--panneau`, 6,1:1 ; 5,3:1 sur le haut de photo en 12) sont conformes, y compris en niveaux de gris (plein / demi / anneau) ; en niveaux de gris V (L=0,46) et N (L=0,38) ont des luminances proches, donc la forme doit rester le discriminant (c'est le cas).

## Constats transversaux (touchent la plupart des écrans)

| ID | Constat | Valeur mesurée | Critère | Gate | Correction |
|---|---|---|---|---|---|
| G1 | Liens d'action isolés (« Classement complet → », « Vérifier les 23 → », « Voir le détail → », « Tout marquer comme lu », etc.) : zone cliquable | 17 à 19 px de haut (aucun < 24 px de large) sur 01-06, 10-12, 14-19 | K6, SC 2.5.8 (WCAG 2.2) | Mineur | Hauteur de zone 24 px minimale (padding vertical 3 px sur la hauteur de ligne 18 px), texte et position inchangés ; les liens en phrase sont exemptés |
| G2 | Champs, onglets de repli, puces de filtre et boutons secondaires : contour absent ou `--filet` | `--panneau-3` sur `--panneau` 1,23:1 ; `--filet` sur `--panneau` 1,55:1 (< 3:1) ; le champ « Rechercher… » est identifié par sa loupe et son texte | C3, SC 1.4.11 | Mineur (identifiable par icône / libellé, sinon bloquant) | Contour 1 px `--ivoire-3` (4,9:1 sur `--panneau`) sur champs, sélecteurs et puces ; `--filet` reste réservé aux filets décoratifs |
| G3 | Monogrammes SVG d'écusson (« NB », « AF », « MR »…) sous 12 px | 5,9 px (13-1, 15-1/2/3), 6,8 px (02-2, 16-1/2/3), 7,7 px (16), 10,2 px (02-3), 11,9 px (13-2/3, 14-x) | T1 (jamais sous 12 px) ; logotype exempté de SC 1.4.3 | Mineur : redondant avec le nom du club écrit à côté | Soit traiter le monogramme comme dessin d'écusson (image, `aria` non lu), soit remonter à >= 12 px ; ne jamais en faire le seul identifiant |
| G4 | Troncatures en « … » sur information décisive | voir par écran (10-1, 11-3, 16-1, 17-3, 02-1) | T5 | Mineur | Largeur de colonne ou infobulle ; jeton de police inchangé |
| G5 | `--ivoire-3` sur `--panneau-2` (zébrures, lignes « indisponible ») | 4,53:1 : conforme, **marge nulle** (10-1/2/3, texte 12-13 px). Sur `--panneau-3` il tomberait à 4,0:1 (la règle de la charte l'interdit déjà) | C1 | Conforme (conseil) | Pour tout texte d'information de 12 px sur zébrure, préférer `--ivoire-2` ; `--ivoire-3` seulement sur `--panneau` |
| G6 | Texte `--club-texte` sur `--panneau-3` (ligne choisie de la compétition) | 5,2:1 mesuré sur la zébrure ; calculé 4,4:1 sur `--panneau-3` | C1 | Mineur (à vérifier au build) | Sur ligne choisie, passer le nom du club en `--ivoire` (le marqueur club existe déjà par le liseré) |

## Constats par écran

Gate : **BLOQUANT** = échoue le palier ; **mineur** = écart sans perte d'information ; **conforme** = rien à signaler. Les valeurs mesurées sont celles du fragment (1920×1080, échelle 100 %).

### 01 Accueil
- v1-v3 : texte 12-13 px >= 12 px, contrastes >= 4,5:1, focus visible sur « Reprendre la carrière » (ivoire 2 px). Liens « Identités et packs » / « Crédits » : 18 px de haut (G1, mineur).
- Monogramme « AF » du logo de carrière : voir G3 (v1 : 22 px, v3 : 15 px, conforme).

### 02 Création du club
- v1 : paragraphe `cr-p` coupé par `line-clamp` (« 22 matchs par club en aller-retour, de s… ») : mineur (G4) ; « Lire la suite » 17 px de haut (G1).
- v2 : monogrammes d'écusson 6,8 px (13 initiales) ; v3 : 10,2 px (13) : mineur (G3).
- v2/v3 : coche « ✓ » en 12 px noire sur fond `--v` : lisible (médiane 18:1, un pire pixel parasite de 1,4:1 sur le bord de la pastille).
- Focus : visible dans les 3 variantes (carte, ligne, liste).

### 03 Chargement
- v1 : focus visible sur « Arrêter → ». Le fond fantôme (la page précédente à 5 % d'opacité : « Kieran Dangerfield », « Ailier »…) donne 1,0 à 1,8:1 : c'est un décor volontairement estompé, pas du texte d'information. **Conforme à condition qu'il soit marqué décoratif** (non focalisable, non lu) : à noter pour le programmeur.
- v2, v3 : **aucun focus dessiné** (K2, mineur : le bouton « Arrêter » n'est pas montré avec focus ; K2 demande une capture avec focus sur chaque écran).

### 04 Bureau
- v1 (3 pastilles) et v3 (1) : pastille N, construction A, **BLOQUANT** (voir V/N/D). Contraste mesuré faux-positif sur la lettre (couleur transparente + dégradé) mais lecture visuelle confirmée à l'agrandissement.
- v1-v3 : liens « Classement complet → », « Vérifier les 23 → », « Consulter le groupe → », « Suivre le conseil → » : 17-18 px (G1).
- Focus : bouton « Préparer le match » ivoire 2 px, 15,8:1 contre le fond.

### 05 Réception
- v1-v3 : contraste conforme ; texte 12 px `--ivoire-3` « Réponse C · indisponible » 4,9:1 (état désactivé aussi dit par le mot : conforme à C4). Liens « Annuler », « Tout marquer comme lu », « Ouvrir Formation → » 18 px (G1).
- Focus visible sur « Envoyer la réponse ».

### 06 Presse
- v1 : bandeau « Alder Fen XV · Saison 2026-27 · Semaine 11 » sans fond propre : pire pixel 3,5:1 sur le haut de photo (médiane 12,9:1), à voiler (C5, mineur) : `rgba(0,0,0,.6)` derrière, sans nouveau jeton.
- v1-v3 : liens 18 px (G1). Focus visible.

### 07 Effectif
- v1-v3 : texte >= 12 px, contrastes conformes ; statuts en mot (« Titulaire », « Remplaçant », « Hors groupe ») + puce pleine / anneau / tiret : conforme D1. Blessure : croix + « Blessé (grave) » ; suspension : « ! Suspendu » ; sélection : icône + « En sélection » : conforme D3.
- Chiffre filigrane du n° de maillot (104 à 140 px, `--ivoire-3`, 3,6 à 4,5:1) : décoratif (« Titulaire · n° 2 » est écrit à côté), non compté.
- v1 : forme des 5 derniers matchs en construction D : conforme.
- Focus : ligne choisie (anneau ivoire 2 px en retrait) conforme ; il est confondu avec la sélection (même ligne) : la distinction focus / sélection (K2) n'est donc pas démontrée sur cette capture (NOT ASSESSED).

### 08 Fiche joueur
- v1-v3 : conforme ; filigrane (« 2 », 120-190 px) décoratif ; V/N/D : construction D (conforme). Focus visible sur « Proposer une prolongation » (15,8:1).

### 09 Recrutement
- v1-v3 : conforme ; focus visible (carte de besoin, bouton, ligne).

### 10 Composition
- v1 : colonne « COND. » du banc : valeurs « 99 % », « 100 % » dans une cellule de 90 px pour un contenu de 102 px (ellipsis actif sur 10 cellules) et puce « 1RE L. » de 54 px pour un contenu de 72 px : **troncature d'information décisive** (G4, T5), mineur ; « B. Ollerensha… » dans le champ : nom coupé (même cause). v3 : « 11 · 14 · 15 · 100 % » coupé.
- v1-v3 : numéros de joueur sur ronds `--club` (8,3:1), conforme (le pire pixel de 4,26:1 est le liseré `--club-trait`).
- v2 : étiquette « Sens de l'attaque → » 12 px sur le trait du terrain : médiane 8,9:1, un recouvrement ponctuel à 1,9:1 (liseré) : mineur, voiler ou décaler.
- v2 : « ! 78 % » rouge `--d` 5,0:1 : conforme (icône + valeur + contour de barre).
- Cibles : liens 17-18 px (G1) ; case « Hors feuille seulement » 18 px (mineur, K6).
- Alternative au glisser-déposer : sélection au clic montrée par la liste des candidats : conforme K6.

### 11 Préparation
- v1, v3 : chiffres filigranes (« 8 », « 10 », « 14 », 72 px, `--panneau-3` sur fond, 1,13:1) : décoratifs, redondants avec « n° 8 » écrit, non comptés (à marquer décoratifs).
- v1-v3 : pastille N construction B (OK en contraste, forme à reprendre, voir V/N/D). Pastille D : OK.
- v3 : 4 noms de joueurs de la file « Leur XV probable » tronqués (« O. Thackray », « T. Wainwright » : 58 px pour 74 px) : mineur (G4).
- v1-v3 : 8 liens d'action 18 px (G1). Focus visible.

### 12 Avant-match
- v1-v3 : pastille N construction B ; pastille D sur photo, 5,3:1 médiane (conforme, 4,2:1 sur 25 % de ses pixels en v1 : mineur, à reposer sur voile).
- v1, v2 : « !78 » (condition d'un titulaire sous le seuil) s'écrit sans espace et se lit « 178 » : **mineur, risque de contresens** ; écrire « ! 78 % » comme en 10.
- v2 : diagramme de condition : valeur numérique + repère de seuil + contour rouge de la barre sous le seuil : conforme D6.
- Liens « Dossier adverse → », « Vérifier la feuille → » 18 px (G1). Focus visible sur « Coup d'envoi » (>= 5,6:1 contre la photo, 10,1 / 17,3 / 5,6 selon la variante).
- v1-v3 : texte posé sur photo (bandeau « DIVISION D'ACCESSION… », « Confrontations ») : médianes >= 4,9:1, à voiler pour tenir sur trois décors (C5).

### 13 Match direct
- v1-v3 : texte du match 16-17 px, score 40 à 48 px : conforme T2.
- v3 : **numéros de maillot en 3D** (`i.to`, 17 px ivoire) à 3,2:1 sur les maillots bleus clairs (5,7 à 8,3:1 sur les autres) : mineur (texte dans la scène, hors seuil de 4,5:1 sur 2 numéros sur 5 mesurés) ; utiliser `--adv` pour tous les maillots adverses (ivoire dessus 5,7:1).
- v3 : maillots distingués par la seule teinte (rouge `--club` / bleu `--adv`), pas de motif (D5) : **ADVISORY** (rouge sombre et bleu clair se distinguent par la luminance, hors confusion protan/deutan/tritan) ; ajouter un bandeau `--ivoire` sur la poitrine adverse si un mode daltonien est vérifié.
- Monogrammes d'écusson 5,9 et 11,9 px : G3.
- Focus : visible sur « Pause » / « Reprendre » (anneau sur photo 8,1 à 14,6:1).

### 14 Entracte
- v1, v2, v3 : **BLOQUANT** : numéros 1 à 15 sur les pastilles club en `--club-trait` : ivoire dessus 4,26:1 (v1 et v2 : 4,26:1 sur 15 pastilles ; v3 : jusqu'à 2,3:1 en médiane sur 11 pastilles de la variante 3 ; « ! blessé » 5,0 à 6,1:1 conforme ; la lettre « T » du bouton Équipe de la variante 3 mesure 1,4:1 : à revérifier au build, la boîte de la lettre déborde sur le fond de la puce). Correction : remplir les pastilles du club en `--club` (ivoire dessus 8,3:1) et garder `--club-trait` pour l'anneau.
- Pastilles adverses : anneau `--adv-trait` + numéro `--ivoire` sur fond sombre : conforme, et distinguables par la forme (plein / anneau) : D5 conforme.
- v1-v3 : texte 12,5 à 14,6 px dans les pastilles SVG (échelle du viewBox) : >= 12 px ; libellés « EN-BUT ALDER FEN » tournés : 12,5 px mesuré après rotation, conforme.
- v3 : liste d'options « Paramètres / Reprendre le match » désactivée `--ivoire-3` 4,9:1 : conforme (C4).
- Monogrammes 11,9 px : G3. Liens « Voir les statistiques → », « Remplacer le 7 → » 17-18 px (G1).
- Focus visible (bouton, option choisie).

### 15 Après-match
- v1-v3 : conforme (texte >= 12 px) ; monogramme « NB » du bandeau de score (SVG, 17 px déclarés) : 3,74:1 au pire pixel (4,26 à 5,7:1 en médiane) sur la plaque adverse, plus clair que `--adv` : **mineur** (monogramme exempté s'il est logotype) ; plaque en `--adv` : ivoire dessus 5,7:1.
- v2 : pastilles V / D (`ov v`, `ov d`) : lettre + forme ; conforme.
- Monogrammes 5,9 px : G3. Liens 18 px : G1.
- Focus visible sur « Ouvrir la conférence ».

### 16 Calendrier et classement
- v1-v3 : pastilles de forme V / N / D (`k-p`) : V et D conformes ; N construction C (mineur). Zones de classement : liseré + ▲ + libellé + légende visible (« 1er à 4e · Phases finales », « Pas de relégation automatique ») : **conforme D4** ; relégation sans ▼ ni libellé à vérifier sur la saison avec relégation.
- v1 : le nom « Meadowbridge Rovers » est tronqué (140 / 145 px) dans la cellule : mineur (G4).
- Monogrammes d'écusson 6,8 à 7,7 px devant chaque club (14 par écran) : G3, mineur (nom écrit à côté).
- Focus : ligne choisie et ligne « prochain », conformes. Liens 17-18 px (G1).

### 17 Finances
- v1-v3 : conforme. Icône « ! » 12 px : sa couleur `--ivoire` sur pastille (la mesure 1,0 est un pire pixel du bord, médiane 15,8:1). v3 : « Demi de mêlée » coupé (72 / 96 px) : mineur (G4). Liens 18 px (G1). Focus visible.

### 18 Club
- v1-v3 : conforme ; coches « ✓ » `--nuit` sur `--v` (9,9:1) et « ✕ » `--d` (6,1:1) ; liens 17-18 px (G1). Pastille N construction C dans la légende (mineur). Focus visible (zone, ligne choisie).

### 19 Formation
- v1-v3 : conforme ; icônes « ✓ ✕ ! » en 12 px toujours avec un mot (« Blessé · 1 sem. » 5,0:1) : D3 conforme. « ✓ » en `--ivoire-2` sur panneau : 8,2:1. Liens 18 px (G1). Focus visible (ligne choisie).

## Couleur jamais seule porteuse d'état

Vérifié sur capture : statuts d'effectif (mot + puce plein / anneau / tiret), blessure (icône croix + gravité en texte), suspension (« ! » + mot), classement (liseré + ▲ + libellé + légende), conditions et fatigue (valeur numérique + repère de seuil), V/N/D (lettre + forme, voir plus haut), entracte (disque plein pour nous, anneau pour eux + numéro), courbe de domination (« barres pleines : nous / barres vides : eux » + ▲ / ▼), rapport de force (barres rouge / ivoire avec valeur numérique et ▲ / ▼). **Aucun cas de couleur seule trouvé** ; seule réserve D5 sur les maillots du direct 3D (advisory) et le « !78 » ambigu de l'écran 12.

## Cibles souris (K6)

Boutons et onglets : >= 28 px de haut (boutons d'action 32-56 px, onglets >= 30 px, rail 34 px, lignes de tableau 24-26 px) : conformes. Seule exception : liens d'action isolés de 17 à 19 px (G1) et la case « Hors feuille seulement » de 18 px (écran 10).

## Focus visible (K2)

Contour `.focus` ivoire 2 px, décalage 2 px (ou -2 px en retrait sur les lignes), contraste >= 5,5:1 contre le fond (valeurs mesurées par échantillon du fond : 5,6 à 17,3:1). Présent sur 55 des 57 écrans. Manquant : 03-chargement v2 et v3. Distinct de la sélection (liseré incliné + `--panneau-3`) : oui, sauf là où focus et sélection coïncident sur la même ligne (07, 16, 17, 18, 19) : non démontrable sur maquette.

## Corrections à transmettre (ux-designer puis ui-programmer)

Bloquantes : (1) composant unique de pastille N conforme (voir V/N/D) ; (2) pastilles club de l'entracte en `--club`.
Mineures par ordre de gain : G1 (zone cliquable 24 px), G2 (contour 1 px `--ivoire-3` sur champs et puces), troncatures de 10, 11, 16, 17, « !78 » de 12, voile sous le bandeau de 06 et le texte sur photo de 12, maillots adverses en `--adv` (13), focus sur 03 v2 / v3, G3 (monogrammes).
