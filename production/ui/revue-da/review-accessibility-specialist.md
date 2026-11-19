# Revue accessibilité — maquettes DA (3 directions × 19 écrans)

Agent : accessibility-specialist (phase 4 de `/team-ui`), 19/11/2026, mode autonome.
Critère : palier **Standard** de `design/accessibility-requirements.md` (T1, C1 à C3, D1 à D6, K2, K6), WCAG 2.1 AA.
Objet : 57 écrans (19 × A, B, C) à 1280×720, jetons de `da2/base.css`.

## Méthode et limites

- Script Playwright (Edge) : pour chaque `.ecran`, tous les nœuds de texte visibles (≈ 8 900) : taille calculée, graisse, couleur, opacité cumulée. Le fond réel est lu **sur pixels** : la page est rendue avec le texte transparent, puis le contraste est calculé contre les pixels sous le texte (gère dégradés, photos, voiles). Seuil : 4,5:1, ou 3:1 si ≥ 24 px ou ≥ 18,66 px gras. Texte SVG (monogramme « AF » des écussons) exclu, hors mesure.
- Hauteur des cibles cliquables mesurée sur les liens, boutons, onglets, éléments de rail.
- Revue visuelle de 32 captures : 01-C, 02-A, 03-A, 04-A/B/C, 07-A/C, 08-A, 09-A, 10-A/C, 11-B, 12-A/C, 13-A/B/C, 14-A/B/C, 15-B, 16-A/B/C, 17-A/B, 18-A, 19-B. **Non vues** (verdict par mesure seulement) : 05, 06, et les autres combinaisons.
- Faux positifs écartés à la main : monogrammes SVG, écran grisé derrière la modale de 03, lignes en surbrillance de focus.
- **NOT ASSESSED** (statique, aucune interaction possible) : K1 parcours clavier, K3 ordre de focus et pièges, K8, K7, M1 à M6 (mouvement, flashs), S3 à S6, T3/E2 (rendu à 130 %), simulation de daltonisme (jugée à l'œil sur formes et légendes, pas sur simulateur), contraste de focus hors écrans 10 et 13-C.

## Verdict global

**CONCERNS, non conforme en l'état au palier Standard.** Le socle est bon : aucun texte sous 12 px hors ordinaux et une note, contraste courant conforme sur la grande majorité des 57 écrans, V/N/D toujours avec lettre, statuts toujours en mots. Cinq défauts BLOQUANTS à corriger avant adoption :

1. Exposants d'ordinaux (« 1re ligne », « 4e », « 1er ») à **10 à 11 px** : écrans 10, 11, 12, trois directions (T1).
2. Direction A variante sombre « encre » : `--club` #C4505D en **texte** sur #1F262B = **3,4:1** (écrans 07, 09, 17) (C1).
3. Direction A, chiffres du rail inactif **3,61:1** (écrans 16 à 19) (C1).
4. Direction B écran 16 : pastille **N** lettre claire sur moitié ambre = **≈ 1,6:1** (D2, C1).
5. Directions A et B écran 02 : le **rang** du club n'existe que dans un chiffre géant à **1,15 à 1,58:1** (C2).

Et un défaut transversal : le **focus visible (K2) n'est montré que sur 4 écrans sur 19** ; il n'est pas démontrable sur les autres.

Classement d'accessibilité : **C** (le moins de violations, formes V/N/D les plus distinctes, focus montré en 10 et 13) devant **B**, puis **A** (variante encre et décors à faible contraste). La réponse reste à Léo et à la DA ; les corrections ci-dessous ramènent A et B au niveau de C.

## 1. Constats transversaux (toutes directions)

| # | Constat | Critère | Gravité | Gate | Correction en jeton existant |
|---|---|---|---|---|---|
| G1 | Exposants d'ordinaux `.sup` : **10 px** (écrans 10, 11) et **11 px** (écran 12), directions A, B, C. Détail : 10 = 4 occurrences, 11 = 1, 12 = 2 | T1 (< 12 px), SC 1.4.4 | S3 | BLOQUANT | Écrire « 1re », « 4e » en plein corps 14 px sans exposant, ou `.sup{font-size:12px}` minimum. Sinon `font-variant-position` hors cadre : ne pas empiler 10 px |
| G2 | **Focus visible** démontré uniquement : 10 (A : cadre `--encre` 2 px ; B : cadre `--texte-1` + barre `--essai` ; C : cadre `--menthe` 2 px), 13-C (`outline:2px solid var(--menthe)`) | K2, SC 2.4.7 | S2 | NOT ASSESSED sur 15 écrans et 13-A/B | Ajouter un état focus par écran. A : `outline:2px solid var(--encre)` (encre sur papier ≈ 15:1) ; variante encre : `--encre` ; B : `--essai` #F4B740 sur `--fond` (≈ 11:1) ; C : `--menthe` (≈ 10:1). Distinct du « bouton principal » déjà cerclé (04, 12, 17) qui n'est **pas** un focus |
| G3 | Cibles **liens texte** `.lien` : hauteur **17 à 21 px** (4 à 6 par écran sur 04, 06 à 12, 14, 17 à 19) | K6 (≥ 24 px) | S3 | BLOQUANT | `min-height:24px; display:inline-flex; align-items:center` sur `.lien`, sans changer le visuel |
| G4 | Bouton **Continuer** (action fréquente) : **28 px** (04 à 15), **21 à 23 px** (16 à 19) | K6 (≥ 32 px actions fréquentes) | S3 | BLOQUANT | Hauteur 32 px (aujourd'hui 28 dans `.continuer`) ; harmoniser 16 à 19 sur la même valeur |
| G5 | Lettres **V/N/D** et pastilles en **13 px** (04 : 5, 06 : 1, 08 : 4 à 5, 12-C : 12, 16 : 51 par direction) ; en-têtes majuscules 13 px (tolérés) | T1 (tableaux ≥ 13) | S4 | ADVISORY | Conforme T1 (≥ 12 px, tableaux 13 px). À monter à 14 px si la place le permet |
| G6 | Chiffres-décor géants à faible contraste : 02-A/B (rang), 07-A `.fil` 1,36, 07-B `.geant` 1,73, 08-A 1,27, 08-B 2,68, 09-B 1,5, 19-A 1,3, 19-B 1,73 ; plusieurs sont **rognés** par le cadre | C2 (si porteur d'info) | S4 sauf 02 | ADVISORY (02 : voir §2) | Décoratif toléré **si** le numéro est redondant en texte lisible (maillot, poste) ; marquer `aria-hidden` dans la spec Godot |
| G7 | Camps du terrain 3D (13) : pions rouge contre blanc de **silhouette identique**, sans écusson ni bandeau | D5 | S3 | ADVISORY | Les deux couleurs diffèrent assez en luminosité pour les daltoniens ; ajouter un liseré ou bandeau de manche, ou un anneau ouvert/plein sous le pion (comme dans le bandeau de score) |
| G8 | Barres de condition 14 (mini-barres par joueur) : valeur chiffrée présente, **repère de seuil absent** ; 12 (15 barres du XV) : repère présent, **valeur par joueur absente** | D6 | S4 | ADVISORY | 14 : trait `--n`/`--d` à 80 % ; 12 : valeur au survol et en liste, déjà « n° 7 : 84 % » en dessous |
| G9 | Zones de classement 16 : montée / barrage / relégation ont liseré + libellé + légende (bon) ; la zone « maintien » n'est ni nommée ni légendée | D4 | S4 | ADVISORY | Ajouter « Maintien » dans la colonne Zone et la légende |
| G10 | Voix de commentateur à l'écran (13) : lignes du journal préfixées par la minute, **sans nom de locuteur** | S1 | S4 | ADVISORY | Préfixer « Commentateur » ou « Gabi » (spec Godot) ; non évaluable sur statique |

## 2. Violations par écran et direction

Légende : ✔ aucune violation mesurée ; BLQ = BLOQUANT ; MIN = mineur (ADVISORY).

### 01 Accueil
- **A** : MIN : légende « Fenbank Ground, un soir de novembre » (15 px) **4,3:1** au pire pixel sur la photo (pied de page). Correction : voile plus dense (`--nuit` à 70 % d'opacité) sous la légende, ou `--nuit-texte` pour la couleur.
- **B** : ✔.
- **C** : MIN : repères de terrain `.c-mark` 13 px ×4 (« 22 », « 10 », « 50 ») : décor, grisé ; pas d'information unique.

### 02 Création / choix du club
- **A** : **BLQ** : `.rgA` rang géant `--filet` #CFC8B8 sur carte #FBF9F4 = **1,58:1** (carte choisie : **1,38:1**), 84 px ; seul porteur du rang du club dans la carte. Correction : afficher « 1er » en `--encre-2` 14 px, garder le géant décoratif.
- **B** : **BLQ** : `.rg` blanc à 5 % d'opacité = **1,15:1**, 96 px, rogné (6 nœuds). Même correction, texte « 1er » en `--texte-2`.
- **C** : MIN : 13 px sur `.rg`, `.kbd` (« Ctrl F ») et « ✓ choisi » (8 occurrences). Le sélection reste lisible : « ✓ choisi » a la coche et le mot. Monter à 14 px.

### 03 Chargement / jour suivant
- **A** : le calque grisé derrière la modale a un faible contraste (non évalué : inerte). Modale : ✔ (titre, barre avec « 38 % », étape « 2 sur 5 »). MIN : bouton « … » en 18 px, contraste insuffisant n'est pas relevé en A ; voir C.
- **B** : ✔.
- **C** : MIN : « … » du bouton Continuer (placeholder de chargement) **1,9:1**, 18 px. Correction : `color: var(--craie)` sur fond `--menthe`/`--poteau`. MIN : 13 px sur `.lb` ×3 et kbd « Échap ».
- Toutes directions : Échap/arrêt visible dans le texte (M3 conforme sur le visuel).

### 04 Bureau
- **A** : MIN : V/N/D 13 px ×5 ; liens 19 à 21 px ×6 (G3) ; « Continuer » 28 px (G4). Contraste ✔.
- **B** : mêmes constats ; ✔ contraste.
- **C** : mêmes constats ; ✔ contraste. Texte sur la photo d'en-tête et la bande « Le bureau » : ✔ (voile).
- Couleur seule : V/N/D à lettre dans les trois ; barres avec valeur et repère (D6 conforme).

### 05 Réception
- **A, B, C** : ✔ texte et contraste. Non vérifié visuellement (mesure seule).

### 06 Presse
- **A, B, C** : MIN : V 13 px ×1 ; liens 21 px (G3). Contraste ✔.

### 07 Effectif
- **A (variante encre)** : **BLQ** : `--club` #C4505D en texte sur #1F262B = **3,4:1** (badge « 4 » du rail), **2,97:1** (« 3 » sur ligne active), **3,84:1** (« 01 / », 16 px) et **3,4:1** (« 02 / », 18 px). Correction : texte en `--or-vieilli` #D2A85C (≈ 7:1) ou `--encre`, `--club` gardé pour le liseré/aplat. MIN : `.fil` « 2 » 1,36:1 (décor, voir G6) ; liens 20 à 22 px.
- **B** : MIN : `.geant` « 2 » 1,73:1, rogné (décor). Pastilles de statut : mots et icônes, ✔ D1.
- **C** : ✔. Lignes titulaire/remplaçant distinguées par forme (cadre plein / pointillé) : bon exemple D1.
- Couleur seule : condition 76 % en ambre mais valeur chiffrée ; « Blessé grave 15/12 » avec ✚ et mot : conforme D3.

### 08 Fiche joueur
- **A** : **BLQ** : « (plus bas = mieux) » à **11,7 px** (`.small`) ; sous le plancher de 12 px de T1. Correction : 14 px. MIN : `.geant` « 2 » 1,27:1 rogné ; liens 20 à 21 px ×5 ; V/N/D 13 px. Pastille « Fin de contrat » : mot présent (✔).
- **B** : MIN : `.geant num` 2,68:1 rogné (décor) ; V/N/D 13 px.
- **C** : MIN : V/N/D 13 px, liens 18 à 21 px.
- Condition : valeur 88 % et repère 80 % présents (D6 ✔) dans les trois.

### 09 Recrutement
- **A (encre)** : **BLQ** : `--club` en texte **3,4:1** (« Priorité 1 · urgent » 14 px, badge « 4 » du rail), **2,97:1** (« 6 »), **3,4:1** (« 04 / » 18 px). Même correction que 07-A.
- **B** : MIN : `.geant` « 9 » 1,5:1 rogné (décor).
- **C** : ✔.
- Liens 20 à 21 px dans les trois (G3).

### 10 Composition
- **A, B, C** : **BLQ** : exposant « re » (« 1re ligne ») **10 px** ×4 (G1). MIN : 15 libellés dépassent leur boîte (noms de joueurs) mais **aucun n'est tronqué visuellement** à 1280 ; à revérifier à 130 % (T3). Focus visible ✔ (voir G2) ; l'état « choisi » (cadre jaune + mot) est distinct du focus.
- Alternative au glisser-déposer : footer « Espace Prendre / poser, Entrée Choisir » (K6 ✔ côté intention).
- Couleur seule : forme du joueur (ligne), condition avec % (D1, D6 ✔).

### 11 Préparation
- **A, B, C** : **BLQ** : exposant « ers » (« 1ers ») **10 px** (G1). MIN : liens 19 à 21 px ×6 (G3).
- **B** : forme adverse en formes distinctes (parallélogramme V, losange N, triangle D) + lettre : **meilleur exemple D2**. Rapport de force : valeurs chiffrées en regard de chaque barre ✔.
- **A, C** : forme adverse à pastilles lettrées ✔ (couleur non seule).

### 12 Avant-match
- **A, B** : **BLQ** : exposants « e », « er » **11 px** (G1). MIN : liens 19 à 20 px ×4 (G3).
- **C** : **BLQ** : même exposant 11 px ; MIN : V/N/D 13 px ×12 ; bilan « Confrontations : 2 V · 1 N · 3 D » 14 px sur fond de bandeau, contraste médian conforme (**4,07:1 au pire pixel**, photo) : voile plus dense recommandé (`--fond` 75 %).
- G8 : barres des 15 titulaires sans valeur par joueur.

### 13 Match en direct
- **A, B, C** : texte rare (13 à 16 nœuds), tous ≥ 14 px, aucun défaut de contraste mesuré ; le score est grand, les bandeaux sur voile. MIN (G7) : camps du terrain à silhouette identique (rouge/blanc). MIN (G10) : pas de nom de locuteur.
- Bandeau « Essai » (B) : texte + forme + valeur (« +5 ») ; carton jaune (C) : icône + texte + chrono ✔ S3.
- **C** : focus de « Reprendre » montré (✔ K2). **A et B** : pas de focus montré (NOT ASSESSED).
- Pause : présente dans les trois (✔ K7 sur le visuel).

### 14 Entracte
- **A** : MIN : « ⚠ épuisé » `--n` #8A5A0E sur ligne teintée **4,44:1** (14 px), 0,06 sous le seuil. Correction : `--encre` pour le mot, garder l'icône ⚠. Camps du terrain : plein contre creux (✔ D5) mais **pas de légende** (C en a une).
- **B** : MIN : lien 16 px de haut (« clic : changer »). Camps : plein rouge contre contour bleu ✔.
- **C** : ✔. Légende « ● nous ○ eux » ✔ : **meilleur exemple D5**.
- Toutes : G8 (barres sans repère). Joueur épuisé : icône + mot + % (D1/D6 ✔).

### 15 Après-match
- **A, B, C** : ✔ texte et contraste. B : états « Point fort ▲ » et « À corriger ▼ » en forme + mot + couleur (✔ D1) ; « V Victoire » avec lettre.

### 16 Calendrier / classement
- **A** : **BLQ** : chiffres du rail inactif (`.i`) **3,61:1** à 14 px ×8 (cf. G3 ci-dessous, §3). MIN : V/N/D 13 px ×51 ; « À jouer → » 18 px de haut ; zone sans « maintien » (G9). Formes : V carré plein, N rond, D rond contour : ✔ D2 avec lettre.
- **B** : **BLQ** : pastille N `.fm .N` = **dégradé 50/50 ambre/transparent**, lettre `--texte-1` : sur la moitié ambre **≈ 1,6:1** (mesure au pire pixel 1,6), 13 px. Correction : `.N{background:var(--n); border:2px solid var(--n); color:var(--fond)}` (plein ambre, lettre sombre ≈ 9:1) en gardant la forme en **losange** ou rond pour la distinguer de V. MIN : D rouge `--d` sur ligne surlignée **4,27:1** (13 px) : lettre en `--texte-1`, bordure `--d`. MIN : formes V, N, D toutes **carrées** : seule la lettre les différencie.
- **C** : ✔ contraste. **Meilleur exemple D2** : V plein, N rond, D carré pointillé, plus légende textuelle « V victoire (plein) · N nul (rond) · D défaite (pointillé) ». Zones : lignes « LIGNE DE MONTÉE/BARRAGES/RELÉGATION » avec trait + mot (✔ D4).
- **A, B, C** : « Continuer » 21 à 23 px (G4).

### 17 Finances
- **A (encre pour le bloc graphique)** : **BLQ** : chiffres du rail `.i` **3,61:1** (cf. rail 16 à 19) ; « 04 / » en `--club` **3,84:1** (19 px). MIN : « ! » 13 px ×3 (icône). Graphique : entrées pleines vs sorties hachurées ✔ D1 (forme + légende). Pastille « Sous tension » : mot + icône ✔.
- **B** : ✔ contraste. « Marge courante −14,5 k€ » : signe + couleur ✔.
- **C** : MIN : « ! » 13 px ×2.

### 18 Club
- **A** : **BLQ** : chiffres du rail 3,61:1 ×8. Jauge de confiance : « ✓ Solide » + 94 + repères 40/70 ✔ (couleur non seule). Installations : barre + « 2/10 » ✔.
- **B** : ✔. **C** : ✔ contraste ; liens 18 px.

### 19 Formation
- **A** : **BLQ** : chiffres du rail 3,61:1 ×8 ; MIN : `.wm` « 15 » filigrane 1,3:1, rogné (décor).
- **B** : MIN : « ✚ Blessé 1 sem. » `--d` #EF5B52 sur ligne surlignée **4,27:1** (14 px) : mot en `--texte-1`, icône ✚ en `--d`. MIN : `.nb` « 15 » 1,73:1 rogné (décor) ; blessure : icône + mot + durée ✔ D3, gravité « léger » dans le panneau de détail seulement.
- **C** : ✔. Statuts : mot toujours (FORMATION, FIN DE CONTRAT, BLESSÉ).

## 3. Chiffres du rail inactif, direction A (écrans 16 à 19)

Les chiffres 1 à 9 du rail latéral (`.rail li i`) sont en `--encre-2` #545D62 atténué par opacité : **3,61:1** effectif sur la carte #FBF9F4, 14 px, 8 occurrences par écran. Correction : retirer l'opacité (`--encre-2` plein ≈ 6,5:1 sur `--carte`) ou utiliser `--encre`. Le rail des écrans 04 à 15 n'est pas touché (chiffres lisibles).

## 4. Synthèse chiffrée (sur les nœuds de texte hors SVG)

| Direction | Écrans avec ≥ 1 défaut BLOQUANT | Nœuds < 12 px | Nœuds de contraste < seuil (médian) |
|---|---|---|---|
| A | 02, 07, 08, 09, 10, 11, 12, 16, 17, 18, 19 (11/19) | 8 (sup ×7, note ×1) | ≈ 70 (dont ≈ 55 chiffres de rail et décors) |
| B | 02, 10, 11, 12, 16 (5/19) | 7 (sup) | ≈ 15 (dont décors) |
| C | 10, 11, 12 (3/19) | 7 (sup) | ≈ 1 |

Hors pondération : le focus (K2) reste à démontrer sur 15 écrans pour chaque direction.

## 5. Ordre de correction recommandé

1. Exposants d'ordinaux : 7 occurrences, correction mécanique (G1).
2. A, variante encre : remplacer `--club` par `--or-vieilli` ou `--encre` pour **tout texte** ; chiffres du rail sans opacité.
3. B : pastille N du 16.
4. A et B : « rang » de l'écran 02 en texte lisible.
5. Focus : ajouter l'état `--encre` / `--essai` / `--menthe` au gabarit de chaque écran avant toute implémentation (K2).
6. `.lien` à 24 px, « Continuer » à 32 px.
7. Ajouter à la liste de tests Godot : mesure T1/C1 sur capture, et à 130 % les écrans 07, 10, 16 (risque de troncature, T3 non vérifié).

## 6. Hors périmètre de cette revue

- Lecteur d'écran, remappage, mode daltonien (D7), réglages : non maquettés.
- Les captures n'ont pas été comparées sous simulation de daltonisme ; les verdicts D2 à D5 reposent sur la présence de lettre, de forme et de légende.
