# Art Bible : Rugby Legacy 27

> **Status**: Draft (mode autonome, rigueur `minimal` : listes de contraintes)
> **Owned By**: art-director
> **Last Updated**: 2026-11-19
> **Art Director Sign-Off (AD-ART-BIBLE)**: CONCERNS (accepted) 2026-11-19 — §8 budgets absents ; §7 tailles sous T1 à faire valider ; §5 atlas de Gabi opaque et portraits joueurs à produire

AD-ART-BIBLE: CONCERNS
- §8 : aucun budget de performance (frame, draw calls, mémoire) ni plateforme dans `project.yaml` ni `technical-preferences.md` : la tenue des standards ne peut pas être vérifiée ; arbitrage 2560/1920 des illustrations ouvert.
- §7 : corps 13 px et en-têtes 12 px sous l'exigence T1 (14 px) ; décision de Léo pour le corps, 12 px (au lieu de 11) à valider ; `accessibility-requirements.md` T1/E1/E2 à réécrire en conséquence ; `tnum` de DM Sans et fichiers italiques de Barlow Condensed à vérifier avant production.
- §5 : atlas de Gabi opaque (fond `#232228`, 1,15:1 contre `panneau`) : un rectangle se verra ; export avec transparence requis. Portraits joueurs actuels = vignettes provisoires (~2,8 Ko) : pas de source de production définie.
- Cohérence vérifiée : palette ↔ humeurs (un seul jeu de jetons, variation par part d'image), formes ↔ énoncé (10° et ovale mesurés), contrastes texte ≥ 4,5:1 sur toutes les paires autorisées, secours daltonisme nommés pour chaque paire à risque. Contradiction corrigée avant signature : l'or servait aussi au focus clavier (focus passé en `ivoire`).

Sources : décisions de Léo du 19/11/2026 (une seule DA tirée du logo ; densité Football Manager), `design/game-brief.md`, `design/player-journey.md`, `design/accessibility-requirements.md`, `docs/direction-artistique-20261108.md`, `production/ui/revue-da/` (options A/B/C abandonnées comme système, relectures), logo et icône `native/godot/branding/`, illustrations `native/godot/art/immersive08/`, atlas de Gabi (anthracite v5).
Les décisions de Léo priment sur les documents antérieurs ; chaque écart est signalé « Écart ».

---

## 1. Visual Identity Statement

**Règle unique : chaque écran est une page du logo : ivoire sur noir chaud, l'or seulement pour l'héritage et pour faire avancer le temps, l'élan à 10° sur ce qui bouge, jamais sur ce qu'on lit.**

Piliers servis (le brief n'a pas de piliers : on s'ancre sur son pitch et sa ligne « ce qu'ils ressentent ») : P1 « tout est sous contrôle » (lire, comparer, décider vite) ; P2 « le match reste incertain » (tension du jour de match) ; P3 « un club qui a une histoire » (héritage, saisons qui s'empilent).

Principes :
- **Une seule langue, un seul curseur.** Les états de jeu ne changent ni de palette, ni de polices, ni de formes ; ils ne font varier que la **part d'image** (0 % au tableau, plein cadre au tunnel) et la **taille du plus grand titre**. Test : si un écran semble demander un autre style, on augmente ou on baisse la part d'image, on n'ajoute pas de couleur. (P1, P2)
- **La donnée est droite, l'identité est penchée.** Inclinaison de 10° (mesurée sur le logo) pour titres, marqueurs de sélection, bords d'action et habillage du match ; tableaux, chiffres, texte courant restent droits. Test : si un élément porte une valeur à lire, il est droit ; s'il dit « nous », « ici » ou « vas-y », il peut pencher. (P1)
- **L'or se mérite.** L'or du « 27 » marque ce qui fait l'héritage (trophée, record, logo) et l'unique action qui fait avancer le temps (Continuer) ; jamais un statut, une alerte, un focus, une sélection ni une décoration. Test : en cas de doute, ivoire. (P3)

## 2. Mood & Atmosphere

Même palette, mêmes polices partout ; la lumière vient des illustrations, l'interface reste noir chaud / ivoire. Ce qui distingue les états d'un coup d'œil : part d'image, taille du titre maximal, quantité d'or.

| État | Émotion cible | Lumière (dans les illustrations) | Adjectifs | Énergie | Élément porteur | Part d'image / titre max / or |
|---|---|---|---|---|---|---|
| Semaine (bureau, réception, effectif, finances, club) | maîtrise tranquille | fin de journée, lampe chaude unique, contraste moyen | posé, studieux, chaleureux, ordonné | mesurée | tableaux pleine largeur ; bandeau d'illustration du bureau voilé ≤ 160 px | ≤ 15 % / 28 px / 1 bouton |
| Préparation (composition, plan, entraînement, dossier adverse) | concentration, anticipation | lumière froide de salle d'analyse, contraste haut, sans photo au centre | précis, tracé, tendu, silencieux | focalisée | terrain tracé ivoire 1 px sur `panneau` | 0-10 % / 28 px / 1 bouton |
| Jour de match (avant-match, tunnel) | montée d'adrénaline | nuit, projecteurs sodium chauds, contre-jour, contraste très haut | électrique, humide, solennel, bruyant | montante | illustration tunnel plein cadre, affiche des deux clubs en 64 px incliné | 100 % / 64 px / affiche + 1 bouton |
| Direct (3D, entracte 2D) | tension, lecture rapide | celle du stade 3D ; habillage opaque, aucun effet lumineux | vif, net, immédiat | haute | bandeau de score incliné haut-gauche, plaques couleur des deux clubs | 3D plein cadre / score 40 px / 0 (sauf trophée) |
| Après-match | verdict, compréhension | vestiaire, lumière chaude basse, contraste moyen | apaisé, franc, lucide | retombante | pastille ovale V/N/D 48 px + score ; trois leviers en liste | 30 % (bandeau vestiaire) / 48 px / 1 bouton |
| Fin de saison | héritage, fierté ou regret | trophée/stade vide, lumière dorée rasante | solennel, nostalgique, ample | contemplative | ovale tracé or autour du bilan | 40 % / 48 px / or autorisé sur titres et trophées |

- Interdits d'humeur : aucun changement de fond (clair/sombre) entre états ; aucune teinte d'état (pas de rouge de défaite plein écran, pas de vert de victoire).
- Son (mood seulement) : semaine feutrée ; jour de match foule et pluie ; après-match vestiaire. Choix audio hors de ce document.

## 3. Shape Language

Deux formes viennent du logo ; tout le reste est rectiligne et sobre.

**A. L'inclinaison (lettres du logo, 10° mesurés sur les fûts de R et L)**
- Titres d'écran et de section : Barlow Condensed italique (vraie italique, voir §7).
- Bord d'action : bouton principal et bandeaux du match en parallélogramme à droite (bord droit incliné 10° ; décalage = hauteur × 0,176, soit 6 px pour 32 px).
- Marqueur de sélection : filet vertical 3 px incliné 10° à gauche de la ligne choisie.
- Onglet actif : soulignement 3 px aux extrémités coupées à 10°.
- Mouvement : les entrées glissent le long de l'axe incliné (§7).
- Jamais : texte de tableau incliné, colonnes inclinées, écran entier en biais.

**B. L'ovale (ballon tracé en virgules qui s'affinent, grand axe ~40°)**
- Pastille de résultat V/N/D : ovale (rapport 1,5:1, grand axe horizontal), lettre droite au centre.
- Pastilles de joueur sur terrain : ovale ; nous = plein, adversaire = anneau 2 px.
- Ovale tracé (deux virgules qui s'affinent, sans fermer) : médaillon de Gabi (`ivoire-2`), progression de Continuer (`or-vif`, c'est Continuer), couronne des temps d'héritage (trophée, bilan, `or`). Max 1 ovale tracé visible dans le contenu, en plus du médaillon de la barre haute.
- Jamais : cercle parfait (sauf boutons radio système), pastille ronde de filtre, numéro de maillot dans un rond.

**C. Le reste : surfaces et filets**
- Séparation par **paliers de fond** (`fond` → `panneau` → `panneau-2`) et par filets horizontaux 1 px `filet`. **Aucun cadre complet** (seule exception : contour de focus clavier).
- Rayons : 0 partout ; 2 px pour champs de saisie seulement. Aucune ombre portée, aucun dégradé décoratif, aucun verre.
- Hiérarchie : héros = un seul élément par écran (affiche, score, ou bouton principal) ; secondaire = tableaux ivoire ; recul = étiquettes `ivoire-2`, filets.

**Silhouettes (3D et portraits)** : rugbyman lisible en vignette 48 px par la carrure, le maillot à couleur de club et le numéro dans le dos ; poste lu par la carrure (avants massifs, arrières élancés), jamais par un accessoire.

## 4. Color System

### 4.1 Mesures sur le logo (pixels lus, moyenne par zone)

| Zone | Hex mesuré |
|---|---|
| Fond | `#000000` |
| « RUGBY LEGACY » et « CLUB MANAGER » | `#F6EEDC` |
| « 27 » | `#E9C062` |
| Ovale et monogramme (logo) | `#F1C970` |
| Ovale (icône) | `#ECB95B` |
| Pull de Gabi (atlas v5, moyenne) | `#71322F` |
| Fond de l'atlas de Gabi | `#232228` (opaque, sans alpha) |

### 4.2 Jetons

| Jeton | Hex | Rôle |
|---|---|---|
| `nuit` | `#000000` | noir du logo : écran titre, plein cadre, sous la 3D. Jamais un panneau. |
| `fond` | `#0E0D0B` | fond de la coque (noir chaud) |
| `panneau` | `#171512` | surfaces de contenu, rail, barre haute |
| `panneau-2` | `#201D19` | ligne zébrée, survol |
| `panneau-3` | `#2B2721` | ligne choisie, champ de saisie, onglet actif |
| `filet` | `#3D372E` | filets 1 px, grille de graphe (non textuel) |
| `ivoire` | `#F6EEDC` | texte principal, tracés actifs, marqueur de sélection (logo) |
| `ivoire-2` | `#BDB4A2` | texte secondaire, en-têtes de colonnes, étiquettes |
| `ivoire-3` | `#8C8474` | désactivé, filigrane ; jamais sur `panneau-3` |
| `or` | `#E9C062` | « 27 » : l'unique action qui fait avancer (aplat, texte `nuit`), héritage (trophée, record, titre de fin de saison) ; rien d'autre |
| `or-vif` | `#F1C970` | ovale du logo : survol/pression du bouton `or`, ovale tracé |
| `club` | variable (défaut `#71322F`, le pull de Gabi) | plaque d'identité (écusson, bandeau de score) avec texte `ivoire` |
| `club-trait` | dérivé (défaut `#B5524A`) | ligne du club au classement, pastilles « nous », liseré de rail ; ≥ 3:1 sur `panneau` |
| `club-texte` | dérivé (défaut `#D0756C`) | nom du club en texte coloré ; ≥ 4,5:1 sur `panneau-3` |
| `v` | `#6CC48A` | victoire, « apte / disponible » ; rien d'autre |
| `n` | `#ADA597` | nul (neutre) |
| `d` | `#EE6F5F` | défaite, blessure, alerte, refus ; toujours avec lettre ou pictogramme |
| `papier` / `encre` / `encre-2` / `or-encre` | `#F6EEDC` / `#14120F` / `#5A5244` / `#7D5B10` | logo inversé : **un seul usage**, le document ouvert (lettre du courrier, contrat, page du carnet de Gabi, une du journal) ; jamais un tableau ; max 1 par écran |
| `v-papier` / `d-papier` | `#2B6A43` / `#A3342C` | V/D sur `papier` |

- Couleur de club : `club-trait` et `club-texte` sont calculés en montant la luminosité de la vraie couleur jusqu'au seuil ; un club jaune/or est poussé vers `ivoire` + liseré (jamais confondu avec `or`) ; un club blanc devient `ivoire`, un club noir passe par sa seconde couleur.
- Adversaire : sa couleur de club suit les mêmes règles, toujours en **anneau** ; si les deux clubs sont trop proches (écart de luminance < 1,5:1), l'adversaire passe en anneau `ivoire`.
- Graphes : série « nous » `club-trait`, comparaison `ivoire-2` en tirets, grille `filet` ; jamais `v`/`d` pour une série.
- Écart : `n` neutre au lieu de l'ambre du brief : l'ambre se confondait avec `or` (même famille, luminances 0,38 / 0,56) ; un nul n'est ni bon ni mauvais.
- Écart : la base ivoire claire du « Carnet du club » (2026-11-08) devient l'exception `papier` ; la base devient le noir chaud du logo (décision de Léo).

### 4.3 Contrastes calculés (WCAG 2.x)

| Paire | Ratio | Usage permis |
|---|---|---|
| `ivoire` / `fond`, `panneau`, `panneau-2`, `panneau-3` | 16,82 / 15,78 / 14,53 / 12,85 | tout texte |
| `ivoire-2` / `fond`, `panneau`, `panneau-2`, `panneau-3` | 9,45 / 8,86 / 8,16 / 7,22 | tout texte |
| `ivoire-3` / `fond`, `panneau` | 5,24 / 4,92 | filigrane, désactivé |
| `ivoire-3` / `panneau-3` | **4,01** | interdit |
| `or` / `fond`, `panneau`, `panneau-3` | 11,27 / 10,57 / 8,61 | titres et chiffres d'héritage |
| `nuit` sur `or` / `or-vif` (bouton) | 12,18 / 13,33 | texte du bouton `or` (et `nuit` sur `ivoire` : 18,18 pour le bouton `ivoire`) |
| `ivoire` sur `club` défaut | 8,27 | plaque d'identité |
| `club-trait` / `panneau`, `panneau-3` | 3,71 / 3,02 | marqueur non textuel (≥ 3:1) |
| `club-texte` / `panneau`, `panneau-2`, `panneau-3` | 5,59 / 5,15 / 4,55 | texte |
| `club` défaut brut / `panneau` | **1,91** | jamais seul : d'où `club-trait` |
| `v` / `panneau`, `panneau-3` | 8,59 / 7,00 | texte, pastille |
| `n` / `panneau`, `panneau-3` | 7,47 / 6,08 | texte, pastille |
| `d` / `panneau`, `panneau-3` | 6,14 / 5,00 | texte, pastille |
| `encre` / `encre-2` / `or-encre` / `v-papier` / `d-papier` sur `papier` | 16,19 / 6,67 / 5,39 / 5,60 / 5,89 | texte sur document |
| `filet` / `panneau` | 1,55 | décoratif uniquement, jamais seul porteur de sens |
| `or` / `ivoire` | **1,49** | jamais l'un sur l'autre |

### 4.4 Daltonisme : paires à risque et secours

- `v` / `d` (luminances proches, rapport 1,40) : lettre V/N/D dans chaque pastille + forme : V ovale plein, N ovale demi-plein, D ovale vide (anneau). Mode daltonien des réglages : `v` → `#5AA9E6` (bleu ; 7,16:1 sur `panneau`, 5,83:1 sur `panneau-3`), `d` inchangé (pas d'orange : il se confondrait avec `or`) ; l'écart bleu/corail tient en protanopie et deutéranopie, la luminance reste proche (1,17:1), donc lettres et formes restent obligatoires.
- `n` / `ivoire-2` : N toujours lettré, jamais une couleur seule.
- `club-trait` rouge / `d` : le club ne porte jamais de message d'alerte ; `d` toujours avec « ! », croix ou lettre D.
- Club jaune / `or` : règle de dérivation ci-dessus.
- Nous / adversaire (terrain, 3D) : plein / anneau ; en 3D, numéro et bandeau d'équipe au-dessus du porteur.
- Zones de classement : liseré gauche + pictogramme (▲ montée, ◆ barrage, ▼ relégation) + légende visible.
- Barres (forme, fatigue, moral, confiance) : remplissage `ivoire-2`, valeur chiffrée à côté, seuils en traits `ivoire-3` ; pas de vert/rouge.

## 5. Character Design Direction

- **Gabi (le seul personnage récurrent)** : ancien coach bourru, pull bordeaux `#71322F`, chemise ivoire, carnet de cuir, cheveux gris ; 16 expressions (atlas v5) validées. Rien à redessiner.
  - Toujours sur fond sombre, cadrage buste, regard vers le contenu (il est placé du côté opposé au texte qu'il commente).
  - Médaillon barre haute : visage dans l'ovale tracé `ivoire-2` 40 px, touche F1 écrite à côté.
  - Dans le corps (écrans de décision seulement : bureau, réception, préparation, avant-match, entracte, après-match, calendrier, finances) : buste 160-200 px, bulle = bloc `panneau-2` + filet gauche incliné `club-trait`, texte `ivoire` 13 px.
  - Atlas actuel opaque sur `#232228` (froid) : écart visible de 1,15:1 contre `panneau`. Exiger un export avec transparence.
  - Mouvement réduit : expression fixe, pas de balancement.
- **Joueurs (portraits 2D)** : buste, légère contre-plongée, lumière chaude latérale, fond `panneau-2` uni. Vignette rectangulaire au bord droit incliné 10° ; numéro de maillot géant en Barlow Condensed ExtraBold italique `ivoire-3` derrière (filigrane, ≤ 20 % de la vignette). Pas de détourage obligatoire tant que l'atlas ne le permet pas. Pas de photo studio grise.
- **Joueurs (3D, match)** : réalisme stylisé, carrures différenciées par poste, maillot couleur club unie + numéro dos ; pas de visage détaillé (caméra tv : 1 joueur ≈ 60-120 px de haut à 1080p). Lisibilité par silhouette, couleur de maillot et numéro.
- **Distinguer d'un coup d'œil** : nous / adversaire par plein/anneau en 2D, par maillot + bandeau en 3D (clubs proches : l'adversaire change de jeu de maillots) ; staff et dirigeants : seulement en nom + fonction, pas de portrait générique.
- Poses : naturelles, jamais héroïques figées ; émotion portée par le visage (Gabi) ou l'action (3D).

## 6. Environment Design Language

- **Lieux** : bureau du manager, vestiaire, tunnel, salle d'analyse, salle de presse, centre médical, stades par niveau (nationale, élite, Pacifique, Japon, finale). Architecture : rugby de club, béton, tôle, tribunes couvertes, bois du vestiaire ; le niveau de division se lit à la taille de la tribune et au nombre de projecteurs.
- **Texture** : illustrations peintes photoréalistes (existantes), soirée/nuit, une source chaude dominante (lampe, projecteur sodium) contre ombres profondes. Étalonnage commun à appliquer : ombres ramenées vers le noir chaud `fond` (retirer la dominante vert-noir actuelle), hautes lumières vers `or-vif`/`ivoire`, saturation des verts −20 %.
- **Densité** : les illustrations ne sont jamais derrière un tableau. Semaine : bandeau ≤ 160 px voilé ; préparation : aucune ; jour de match : plein cadre ; après-match : bandeau 30 % ; titre et fin de saison : plein cadre.
- **Voile** : dégradé `fond` 0 → 85 % du côté du texte ; contraste mesuré au pire pixel (≥ 4,5:1).
- **Récit sans texte** : météo du match (variantes tunnel pluie, vent, chaleur, sec, neutre) ; niveau du stade selon division ; vestiaire rangé ou en désordre selon résultat (piste future, pas de nouvel asset exigé).
- **Terrain de tactique** : jamais de pelouse verte ; lignes `ivoire` 1 px (ligne d'essai, 22 m, 10 m, médiane), pointillés 4-4 `ivoire-3` pour 5 m et 15 m, sur `panneau` ; proportions réelles (100 × 70 m, en-buts compris).

## 7. UI/HUD Visual Direction

### 7.1 Vue art

**Coque unique (16 écrans de gestion ; titre, chargement et match en sortent)**, mesures à 1920×1080, échelle 100 % :
- Rail gauche 232 px `panneau` : écusson + nom du club en tête (liseré `club-trait` 3 px incliné), entrées numérotées 1 à 9 (Bureau, Réception, Effectif, Tactique, Entraînement, Recrutement, Club, Finances, Compétitions, puis Formation), sous-menu déplié seulement dans la section active ; en pied : Réglages, Sauvegarder.
- Barre haute 48 px `panneau` : à gauche bouton **Menu** visible (☰ + « Menu » + touche « Échap » écrite) ; fil d'Ariane ; à droite recherche (Ctrl+K), date, médaillon Gabi (F1), **Continuer** (bouton `or`, bord droit incliné, « Espace » écrit, dit ce qui bloque s'il est bloqué).
- **Menu pause** (Échap ou bouton Menu) : panneau central 480 px sur voile `nuit` 70 % : Reprendre, Sauvegarder, Charger, Réglages, Retour à l'accueil, Quitter. Même menu en match (Échap = pause + menu).
- Zone de contenu : grille 12 colonnes, gouttière 16 px, marges 24 px, pas de 4 px. Lignes de tableau 24 px, actions fréquentes ≥ 32 px.
- Match (direct) : bandeau de score haut-gauche (plaques `club` des deux clubs, score `ivoire` 40 px, temps, phase), bord droit incliné ; journal en bas-gauche 16 px sur `panneau` 85 % ; tiers inférieur pour l'événement (une bannière à la fois, couleur du club qui marque). Habillage télé mais même jetons et mêmes polices.

**Typographie** (OFL, déjà dans le jeu) :
- **Barlow Condensed** : titres, en-têtes, chiffres d'affiche. Ajouter les fichiers italiques réels (SemiBold Italic, Bold Italic, ExtraBold Italic) de la même famille : la pente native (~10-12°) colle à celle du logo (10° mesurés) ; fausse italique par cisaillement interdite.
- **DM Sans** : texte courant et cellules de tableau, chiffres tabulaires (`tnum`) obligatoires dans les tableaux (présence de `tnum` dans `DMSans.ttf` à vérifier ; repli : Barlow non condensé, OFL).
- Pas de troisième famille. (Fraunces et IBM Plex Mono des options A/C abandonnées.)

**Échelle dense à 1920×1080 (100 %)** :

| Niveau | Police | Taille / interligne | Casse |
|---|---|---|---|
| Affiche (tunnel, fin de saison) | BC ExtraBold Italic | 64 / 1,0 | capitales |
| Score direct, résultat après-match | BC ExtraBold Italic | 40-48 / 1,0 | — |
| Titre d'écran | BC ExtraBold Italic | 28 / 1,1 | capitales |
| Titre de section | BC Bold Italic | 18 / 1,2 | capitales |
| Nom d'entité (joueur, club en tête de fiche) | BC SemiBold | 15 / 1,2 | casse normale |
| Corps | DM Sans Regular | 13 / 18 px | normale |
| Cellule de tableau | DM Sans Regular (chiffres `tnum`, alignés à droite) | 13 (12 pour colonnes secondaires) / ligne 24 px | normale |
| En-tête de colonne, étiquette, rubrique | BC SemiBold, `ivoire-2` | 12, interlettrage +8 % | capitales |
| Journal du match, sous-titres | DM Sans Medium | 16 / 22 | normale |

- Graisse pour hiérarchiser avant la taille ; jamais plus de 4 mots en capitales.
- **Échelle d'interface** (réglage) : 90 / 100 / 115 / 130 %. Défaut 100 % ; 130 % proposé à 1280×720. **Plancher absolu : aucun texte rendu sous 12 px réels** (taille calculée = max(12, taille × facteur d'écran × échelle)) ; 90 % n'est proposé que si la fenêtre fait ≥ 2560 px de large. Les écrans se recomposent (moins de colonnes) plutôt que de tronquer.

**Iconographie** : pictogrammes originaux au trait 1,5 px sur grille 16/20 px, extrémités coupées à 10°, `ivoire-2` au repos, `ivoire` actif ; toujours accompagnés d'un mot ; aucun pictogramme de bibliothèque hétérogène ; flèches ▲▼ pour les tendances ; ballon = ovale.

**Boutons** (trois, pas plus) :
- `or` plein, texte `nuit`, bord droit incliné : l'action qui fait avancer le temps. Dans la coque, c'est **Continuer** et lui seul ; hors coque (titre, avant-match, après-match), « Reprendre », « Lancer le match », « Continuer ».
- `ivoire` plein, texte `nuit` (18,18:1), bord droit incliné : l'action principale de l'écran (« Valider la composition », « Proposer le contrat ») ; max 1 par écran.
- Texte `ivoire` + flèche, souligné au survol : toutes les autres actions.

**États** : survol `panneau-2` ; choisi `panneau-3` + marqueur incliné `ivoire` 3 px ; focus clavier contour 2 px `ivoire` décalé 2 px, coins nets (seul contour du jeu, visible seulement au clavier ; ≥ 12,85:1 sur tous les fonds sombres ; sur un bouton `ivoire` plein, le décalage de 2 px laisse le fond entre bouton et contour) ; désactivé `ivoire-3` + forme (barré ou cadenas).

**Mouvement** :
- Entrée d'écran : glissement de 12 px le long de l'axe incliné + fondu, 160 ms, ease-out ; cascade 30 ms par bloc, max 6 blocs.
- Sélection : marqueur qui glisse 100 ms ; tableaux sans animation.
- Continuer : ovale tracé qui se remplit pendant le calcul.
- Essai : bannière du club qui marque glisse dans le tiers inférieur, 600 ms au total, puis retour à l'état de base ; aucun flash.
- Mouvement réduit : fondus 100 ms, rien ne glisse ; « Transitions : Aucune » = instantané.
- Jamais : rebond, élastique, parallaxe permanente, clignotement > 3/s.

**Interdits** : cadres complets ; ombres, dégradés de relief, verre, biseaux ; rayons > 2 px ; plus d'un aplat `or` par écran ; `or` pour un statut ou une alerte ; vert hors V/disponible ; rouge hors D/alerte/blessure ; texte incliné dans les données ; `nuit` comme panneau ; page à fond clair (hors document `papier`) ; grain de papier, textures ; texte incrusté dans une image ; pastille ronde (hors bouton radio) ; icône sans mot ; style « copie de FM » (gris-bleu, dégradés, onglets arrondis) ; mentions « fictif » / « IA ».

### 7.2 Vue UX

- **Interactions** : la densité FM sert la semaine (comparer, trier) : tableaux 24 px, tri et filtre au clavier. L'inclinaison n'est que sur marqueurs et titres, donc sans coût de lecture.
- **Lisibilité au direct** : score, temps, phase lisibles en < 2 s (40 px, opaque) ; journal 16 px, relisible (défilement arrêtable).
- **Plancher accessibilité** : contrastes ≥ 4,5:1 sur toutes les paires de texte (§4.3) ; ≥ 3:1 pour focus et marqueurs ; couleur jamais seule (§4.4) ; focus distinct du survol et de la sélection ; Échap + bouton Menu visible ; cibles ≥ 24 px.
- **Retour** : Continuer dit ce qui bloque ; chaque refus dit quoi faire ; sauvegarde visible.
- **Conflit 1 (tranché par Léo, à garder en tête)** : `accessibility-requirements.md` T1 exige 14 px de corps à 1920 ; Léo a choisi 13 px (densité FM). Compensation retenue : plancher 12 px réels, réglage d'échelle, contrastes élevés. Coût : en dessous de T1 au défaut ; T1 et E1 à réécrire.
- **Conflit 2** : en-têtes à 11 px voulus par Léo contre T1 « aucune étiquette < 12 px ». Retenu : 12 px (capitales condensées à 11 px illisibles sur dalle 1080p). À valider par Léo.
- **Conflit 3** : Échap = Retour (K4) et Échap = menu pause. Retenu : Échap ferme d'abord ce qui est ouvert (fenêtre, sous-page), puis ouvre le menu quand il n'y a plus rien à fermer ; le bouton Menu reste l'accès direct.
- **Conflit 4** : 90 % d'échelle descend sous T1 à 1920 ; réservé aux fenêtres ≥ 2560 px.

## 8. Asset Standards

### 8.1 Vue art

- Nommage : `[categorie]_[nom]_[variante]_[taille].[ext]` (ex. `ui_ico_effectif_20.svg`, `env_tunnel_pluie_2560.png`, `char_gabi_rire_512.png`, `brand_logo_ivoire_1774.png`).
- Formats : icônes SVG (trait, couleurs `ivoire`/`ivoire-2` remplacées à l'exécution) ; illustrations PNG sources 2560 × 1440 (plein cadre) et 2560 × 480 (bandeaux) ; portraits PNG avec transparence 512 × 512 (affichés ≤ 256) ; Gabi PNG avec transparence par expression 512 × 640 ; logo en PNG transparent + version vectorielle à obtenir.
- Paliers : plein cadre 2560 ; bandeau 2560 × 480 ; vignette 512 ; icône 16/20/24.
- Couleur : sRGB, pas de profil exotique ; étalonnage commun §6 appliqué à la source, pas dans le jeu.
- Polices : TTF OFL, licence jointe, mêmes familles (§7).
- 3D : réutiliser l'existant ; nouvelle pièce = même réalisme stylisé, maillots par couleur de club (pas de texture de marque).

### 8.2 Vue technique

- Moteur : Godot 4.7, rendu GL Compatibility (`project.yaml`).
- **Aucun budget de performance défini** : `project.yaml` n'a pas de bloc `performance`, `.claude/docs/technical-preferences.md` laisse Frame Budget, Draw Calls, Memory Ceiling et plateformes à `[TO BE CONFIGURED]`. Pas de limite de polygones, de mémoire texture ni de matériaux à citer.
- Effets d'interface (voile, inclinaison, ovale tracé) : réalisables en `StyleBox`/polygones 2D et `TextureRect` ; shaders 2D à garder compatibles GL Compatibility. Non vérifié dans `docs/engine-reference/godot/`.
- Polices : défaut d'import `hinting` changé en 4.7 (`breaking-changes.md`) : vérifier la netteté à 12-13 px. MSDF, `FontVariation` et `tnum` : NOT SOURCEABLE, non couverts par `docs/engine-reference/godot/`, à tester.
- Illustrations actuelles : ~2 Mo PNG chacune (≈ 30 fichiers dans `immersive08/`) ; à 2560 × 1440 RGBA non compressé, ≈ 14 Mo en mémoire vidéo par image.
- **Arbitrage ouvert (non tranché)** : idéal art = sources 2560 × 1440 pour la netteté en 1440p ; prudence technique = 1920 × 1080 en compression VRAM pour la mémoire et le temps de démarrage (déjà signalé lent). Sans budget fixé, les deux sont consignés ; défaut proposé : 2560 pour ≤ 3 illustrations chargées à la fois, sinon 1920, au cas par cas.

## 9. Reference Direction

| Référence | Prendre précisément | Éviter |
|---|---|---|
| Le logo Rugby Legacy 27 (source) | les trois couleurs mesurées, l'inclinaison de 10°, l'ovale en virgules, les capitales espacées de « CLUB MANAGER » pour les étiquettes | le reproduire en décor (filigrane géant, motif répété) |
| Football Manager (FM24 tableaux, OOTP pour comparaison) | densité : vrais tableaux triables, lignes 24 px, beaucoup de colonnes, panneau de détail à droite | son habillage (gris-bleu, dégradés, onglets arrondis, cartes FM26 qui remplacent les tableaux) |
| Habillage Six Nations 2025 et scorebug moderne | score et horloge protégés et dominants ; une seule bannière liée au temps ; retour à l'état de base ; portraits en légère contre-plongée | couleurs et marques du tournoi ; dégradés et reliefs |
| Persona 5 | palette restreinte (noir, clair, une couleur), l'inclinaison comme signature, zones d'écran fixes par type d'information | texte décoratif illisible, compositions qui bougent sans arrêt |
| Disco Elysium | l'illustration peinte porte l'ambiance, l'interface reste sobre à côté | texte trop petit, colonne de texte sans hiérarchie |
