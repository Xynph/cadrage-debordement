# Art Bible : Rugby Legacy 27

> **Status**: Draft (mode autonome, rigueur `minimal` : listes de contraintes)
> **Owned By**: art-director
> **Last Updated**: 2026-11-20
> **Art Director Sign-Off (AD-ART-BIBLE)**: CONCERNS (accepted) 2026-11-20 — la charte finale de la graphiste (adoptée par Léo le 20/11) remplace la v19/11 (noir chaud / ivoire / or réservé à Continuer / 10°) ; contrastes recalculés ; §8 budgets toujours absents, §7 corps 13 px sous T1 (14 px), atlas de Gabi opaque

AD-ART-BIBLE: CONCERNS
- §8 : aucun budget de performance (frame, draw calls, mémoire) ni plateforme dans `project.yaml` ni `technical-preferences.md` ; arbitrage 2560/1920 des illustrations ouvert.
- §7 : corps 13 px sous T1 (14 px), choix de Léo (densité FM) ; `accessibility-requirements.md` T1/E1/E2 à réécrire ; `tnum` de DM Sans à vérifier.
- §5 : atlas de Gabi opaque (fond `#232228`) : un rectangle se verra sur `panneau` ; export avec transparence requis.
- Tranché par Léo le 20/11 sur comparatifs : pastilles à coins de 6 px (comme la graphiste), lignes de tableau serrées 26 px (densité FM), menu pause en fenêtre (seule exception à « pas de fenêtre »). Reste à valider : compteur doré du menu non compté comme « aplat principal ».
- Cohérence vérifiée : une seule règle, un seul nuancier (`charte.gd`), contrastes texte ≥ 4,5:1 sur toutes les paires autorisées, couleur jamais seule.

Sources : décisions de Léo du 20/11/2026 (adoption de la charte finale de la graphiste, deux exceptions) et du 19/11/2026 (densité Football Manager, barème des attributs) ; **charte de la graphiste « Rugby Legacy 27 »** (README, `tokens.css`, fiches composants, logos, symboles, icônes ; lue le 20/11/2026) ; jetons Godot `native/godot/ui/charte.gd` (source de vérité des valeurs et noms) ; `design/game-brief.md`, `design/player-journey.md`, `design/accessibility-requirements.md` ; logo, symbole et icônes `native/godot/branding/` ; illustrations `native/godot/art/immersive08/` ; atlas de Gabi (anthracite v5).
Les décisions de Léo priment sur la charte de la graphiste et sur les documents antérieurs ; chaque écart est signalé « Écart ».

---

## 1. Visual Identity Statement

**Règle unique : un aplat ardoise, des panneaux presque noirs aux angles larges, la crème qui porte l'information, un seul doré qui agit : le doré dit « fais ça », le vert clair dit « tout va bien », jamais deux couleurs pour un même sens.**

Piliers servis (le brief n'a pas de piliers : on s'ancre sur son pitch) : P1 « tout est sous contrôle » (lire, comparer, décider vite) ; P2 « le match reste incertain » (tension du jour de match) ; P3 « un club qui a une histoire » (héritage, saisons).

Principes :
- **Sombre et posé.** Pas de blanc pur ni de noir pur à l'écran (hors `nuit`, écran titre). Le fond est l'ardoise, avec une photo d'ambiance très voilée par écran (16 %, choix de Léo du 20/11/2026). (P1)
- **La crème porte l'information** (texte, titres, chiffres) ; le gris-vert la nuance ; les surfaces ne la portent jamais. (P1)
- **Trois couleurs, trois rôles.** Doré = agir et attirer l'œil ; vert clair = bon état et notre équipe ; vert franc = surface rugby (jauge, écusson « nous », terrain). Test : en cas de doute, crème. (P1, P3)
- **Une couleur n'est jamais seule** : tout état porte un mot ou un pictogramme.
- **Droit et arrondi.** Titres et marqueurs droits (fin de l'inclinaison 10° ; `INCLINAISON_DEGRES = 0`) ; panneaux rayon 18, boutons, onglets et champs en pilule ; pastilles à 6 px.
- **Une seule langue.** Les états de jeu ne changent ni palette, ni polices, ni formes ; ils ne varient que par la **part d'image** (0 % au tableau, plein cadre au tunnel) et la **taille du plus grand titre**. (P2)

## 2. Mood & Atmosphere

Même palette, mêmes polices partout ; la lumière vient des illustrations (plein cadre ou bandeau de page vitrine), et d'une photo d'ambiance très voilée sur l'ardoise derrière l'interface. Ce qui distingue les états : part d'image, titre maximal, quantité de doré.

| État | Émotion cible | Lumière (dans les illustrations) | Énergie | Élément porteur | Part d'image / titre max / aplat doré |
|---|---|---|---|---|---|
| Semaine (bureau, réception, effectif, finances, club) | maîtrise tranquille | fin de journée, lampe chaude unique | mesurée | tableaux pleine largeur sur panneaux ; en-tête compact sans photo | 0 % / 28 px / 1 |
| Préparation (composition, plan, entraînement, dossier adverse) | concentration | lumière froide de salle d'analyse | focalisée | terrain en bandes `pelouse` sur `panneau` | 0 % / 28 px / 1 |
| Jour de match (avant-match, tunnel) | adrénaline | nuit, projecteurs sodium, contre-jour | montante | illustration tunnel plein cadre sous voile sombre, affiche des deux clubs 64 px | 100 % / 64 px / 1 |
| Direct (3D, entracte 2D) | tension, lecture rapide | celle du stade 3D | haute | bandeau de score haut-gauche, panneaux `panneau` 90 % | 3D plein cadre / score 40 px / 0 |
| Après-match | verdict, compréhension | vestiaire, lumière chaude basse | retombante | pastille V/N/D + score ; trois leviers en liste | bandeau 30 % (page vitrine) / 48 px / 1 |
| Fin de saison | héritage, fierté ou regret | trophée/stade vide, lumière dorée rasante | contemplative | bilan sur panneau, trophée | 40 % / 48 px / 1 |

- Interdits d'humeur : aucun changement de fond (clair/sombre) entre états ; aucune teinte d'état plein écran (pas de rouge de défaite, pas de vert de victoire).
- Son (mood seulement) : semaine feutrée ; jour de match foule et pluie ; après-match vestiaire. Choix audio hors de ce document.

## 3. Shape Language

- **Panneau** : `panneau` rayon 18, **sans bordure** ; il se détache du fond par sa clarté et son ombre. Carte dans un panneau : rayon 12.
- **Ombre portée** sur panneaux, cartes et tuiles : noir 50 %, sans décalage, étendue 4 px (choix de Léo du 20/11/2026, d'après la graphiste qui proposait 10 px). Jamais sur pilules, boutons, champs, pastilles ni lignes. Jetons `OMBRE_COULEUR`, `OMBRE_TAILLE`, `OMBRE_DECALAGE`, posés par `Charte.ombrer()` ; un panneau qui rogne son contenu confie son ombre à `Charte.ombre_derriere()`.
- **Pilule** (`RAYON_PILULE`) : boutons, onglets, champs, jauges (rail et remplissage).
- **Rayon 6** (`RAYON_PETIT`) : pastilles d'état, cases, vignettes, ligne sélectionnée.
- **Séparation** : filet 1 px `filet` à l'intérieur d'un panneau ; entre panneaux, 16 px de fond visible. Contour 1 px `filet` seulement pour bouton secondaire et champ ; seul autre contour : anneau de focus.
- **Droit partout** : titres, marqueurs, bandeaux du match, soulignements ; aucun bord incliné, aucun texte penché, aucune italique (anciens noms `*_ITALIQUE` = coupes droites).
- **Ovale du logo** : réservé au symbole (logo, icône, chargement) ; la pastille V/N/D est une pilule ; pastilles de joueur sur terrain : disque plein (nous) / anneau 2 px (adversaire) ; pas de cercle parfait ailleurs.
- **Hiérarchie** : héros = un élément par écran (affiche, score ou bouton principal) ; secondaire = tableaux crème ; recul = étiquettes `ivoire-3`, filets.
- Aucun dégradé décoratif, aucun verre ; ombre portée sur panneaux, cartes et tuiles : noir 50 %, sans décalage, étendue 4 px (choix de Léo du 20/11/2026, d'après la graphiste qui proposait 10 px). Jamais sur pilules, boutons, champs, pastilles ni lignes. Dégradé admis seulement pour le voile sombre sous un texte posé sur une illustration.
- **Silhouettes (3D et portraits)** : rugbyman lisible en vignette 48 px par la carrure, le maillot de club et le numéro dans le dos ; poste lu par la carrure, jamais par un accessoire.

## 4. Color System

### 4.1 Nuancier (7 teintes, source : `charte.gd`)

| Jeton Godot | Hex | Rôle |
|---|---|---|
| `FOND` (`ARDOISE`) | `#202d2d` | fond de l'écran : aplat, derrière tout |
| `PANNEAU` (`NOIR_PANNEAU`) | `#0b1517` | panneaux, tableaux, barre latérale |
| `IVOIRE` (`CREME`) | `#f2ecdc` | texte principal, titres, chiffres ; onglet et menu actifs (aplat) |
| `IVOIRE_2` (`GRIS_VERT`) | `#abb7b1` | texte secondaire, valeurs, icônes au repos |
| `VERT_FRANC` | `#32644b` | **surface** : jauge, écusson « nous », terrain, bouton secondaire plein ; jamais en texte ni trait fin |
| `OR` (`DORE`) | `#d7aa5a` | voir 4.2 |
| `VERT_CLAIR` | `#b6d6b6` | bon état, chiffres favorables, notre équipe ; jamais en paragraphe |

Hors nuancier : `NUIT` `#000000` (écran titre plein cadre, jamais un panneau) ; `OR_VIF` `#e2bc77` (survol/pression du bouton doré).

### 4.2 Nuances (nuancier posé en transparence sur `PANNEAU`, figées en opaque)

| Jeton | Hex | Tirée de | Rôle |
|---|---|---|---|
| `PANNEAU_2` | `#192223` | crème 6 % | survol |
| `PANNEAU_3` | `#222a2b` | crème 10 % | choisi, champ, rail de jauge |
| `FILET` | `#272f2f` | crème 12 % | séparations, contour des boutons secondaires et des champs |
| `IVOIRE_3` | `#96968d` | crème 60 % | texte faible : en-têtes de colonnes, légendes ; jamais sous 12 px |
| `SELECTION` | `#1d392e` | vert franc 45 % | ligne de tableau sélectionnée |
| `VOILE_DORE` | `#2c2d22` | doré 16 % | fond de pastille « à traiter », avec texte doré |
| `VOILE_VERT` | `#252f2c` | vert clair 14 % | fond de pastille de bon état, avec texte vert clair |

Aucune huitième teinte : toute nouvelle nuance se tire du nuancier par transparence.

### 4.3 Qui fait quoi

- **Doré** : action principale (**un seul aplat doré par écran** : Continuer, ou le bouton principal d'une page sans Continuer), attention (toujours avec un mot ou un pictogramme : « Blessé », « Fin de contrat », « À traiter »), surtitres, focus clavier (anneau 2 px décalé de 2 px), colonne triée, l'adversaire dans une comparaison.
- **Vert clair** : bon état (disponible, en forme), chiffres favorables, notre équipe.
- **Crème** : texte principal ; **aplat crème** = onglet actif et entrée de menu active (texte `PANNEAU`). Un deuxième aplat clair (crème ou vert clair) hors onglet/menu volerait la vedette au doré.
- **Gris-vert** : secondaire, neutre (« Prêté », « Remplaçant »), icônes au repos.
- **Rouge** (`ROUGE` `#d9534a`) : hors nuancier, réservé aux cartons rouges et aux vraies erreurs (échec de sauvegarde, connexion). Blessure, fin de contrat, conférence obligatoire : doré + mot + pictogramme. Les cartons jaune/rouge du match sont des objets du rugby, pas des états d'interface.
- **Couleurs de club** (`CLUB`, `CLUB_TRAIT`, `CLUB_TEXTE`) : seulement sur écusson, maillot et liseré (liseré 4 px en tête de fiche club, pastille 12 px devant le nom dans un classement) ; jamais sur bouton, texte, jauge ni fond de panneau. Les deux camps d'un match restent vert clair (nous) et doré (adversaire) quelles que soient les couleurs des clubs. Club trop sombre : contour crème 12 %. Club jaune/or : dérivé poussé vers la crème (jamais confondu avec le doré). `CLUB_TRAIT` ≥ 3:1 sur `PANNEAU`, `CLUB_TEXTE` ≥ 4,5:1 sur `PANNEAU_3`.
  - Exception (Léo, 20/11/2026) : les bandeaux d'équipe de l'Avant-match restent en aplat aux couleurs des clubs, pour l'immersion.
  - Exception (Léo, 20/11/2026) : la bannière d'essai du match est en aplat à la couleur du club qui marque. Le bandeau du score reste sobre.
- **Papier** (`PAPIER` = crème, `ENCRE` `#0b1517`, `ENCRE_2` `#4d5853`, `OR_ENCRE` `#7d5b10`, `V_PAPIER` `#32644b`, `D_PAPIER` `#8a5a12`) : un seul document ouvert par écran (lettre, contrat, carnet, une de journal) ; jamais un tableau.
- **Terrain** : `PELOUSE` `#1d4631` / `PELOUSE_2` `#214e37` en bandes à plat, liseré `PELOUSE_BORD` `#53625e`.
- **Barème des attributs** (fiche joueur, mini-fiche ; décision de Léo du 19/11, **inchangé**) : six paliers `ATTRIBUT_0` à `ATTRIBUT_85`, chiffre toujours écrit, légende avec chaque grille. Seule exception à « couleur du nuancier » et à « rouge hors nuancier » dans une grille d'attributs.
- **Graphes** : nous `VERT_CLAIR`, adversaire `OR`, séries suivantes crème puis gris-vert ; 4 séries au plus ; axes et quadrillage `FILET`, étiquettes `IVOIRE_3`, valeurs en Barlow Condensed ; pas de camembert.
- **Logo** : version principale crème + « 27 » doré, transparente, sur `FOND`/`PANNEAU` ; symbole doré ou crème en coin d'écran, chargement, icône ; jamais recoloré, ombré ni posé sur photo chargée sans voile.
- Écart : le doré n'est plus réservé à Continuer ni à l'héritage ; il porte aussi attention, surtitres, focus et adversaire (charte de la graphiste). Écart : `n` neutre et `v`/`d` verts/corail du 19/11 supprimés (`V` = vert clair, `N` = gris-vert, `D` = doré).

### 4.4 Contrastes calculés (WCAG 2.x)

Calculés à la main avec la formule WCAG 2.x sur les hex ci-dessus (aucun interpréteur disponible dans cette session) ; les six valeurs de la charte de la graphiste sont retrouvées à ±0,1.

| Paire | Ratio | Usage permis |
|---|---|---|
| crème / `PANNEAU`, `PANNEAU_3`, `FOND` | 15,71 / 12,42 / 12,07 | tout texte |
| gris-vert / `PANNEAU`, `PANNEAU_3`, `FOND` | 8,95 / 7,07 / 6,9 | tout texte |
| `IVOIRE_3` (texte faible) / `PANNEAU`, `PANNEAU_3` | 6,21 / 4,91 | en-têtes, légendes ≥ 12 px |
| doré / `PANNEAU`, `PANNEAU_3`, `FOND` | 8,63 / 6,83 / 6,64 | texte, surtitre, focus |
| `PANNEAU` sur doré (bouton principal) | 8,63 | texte du bouton doré |
| `PANNEAU` sur crème (onglet, menu actifs) | 15,71 | texte de l'onglet actif |
| vert clair / `PANNEAU`, `VOILE_VERT` | 11,72 / 8,73 | texte, chiffre favorable |
| doré / `VOILE_DORE`, `SELECTION` | 6,50 / 5,84 | pastille « à traiter », ligne choisie |
| crème / `VERT_FRANC`, `SELECTION` | 5,83 / 10,6 | bouton secondaire plein, ligne choisie |
| vert clair / `VERT_FRANC` | 4,35 | gros texte seulement (≥ 18 px) |
| doré / `VERT_FRANC` | 3,20 | icône ou titre seulement |
| `VERT_FRANC` / `PANNEAU` | 2,7 | surface seulement : jamais texte ni trait fin |
| `ROUGE` / `PANNEAU` | 4,66 | texte d'erreur ; toujours avec mot |
| `V_DALTONIEN` `#5aa9e6` / `PANNEAU` | 7,28 | mode daltonien |
| `FILET` / `PANNEAU` | ~1,3 | décoratif, jamais porteur de sens |
| doré / crème, vert clair / crème | 1,2 / 1,3 | **jamais l'un sur l'autre** |

### 4.5 Daltonisme : paires à risque et secours

- **Doré / vert clair** (luminances proches, rapport 1,32 ; seule paire de rôles opposés) : toujours doublés d'un mot ou d'un pictogramme (« Disponible » / « Blessé », ✓ / ⚠) ; en comparaison, nous à gauche, adversaire à droite ; sur terrain et en 3D, nous = plein / adversaire = anneau (numéro et bandeau d'équipe au-dessus du porteur).
- **Mode daltonien** (réglages) : favorable passe de `VERT_CLAIR` à `V_DALTONIEN` ; doré inchangé ; mots et pictogrammes restent obligatoires (la luminance reste proche).
- **Gris-vert / crème** : un neutre est toujours lettré, jamais une couleur seule.
- **Résultat V/N/D** : lettre dans chaque pastille + forme (V pilule pleine vert clair, N demi-pleine, D contour doré).
- **Barème des attributs** : chiffre écrit + légende ; palier lisible sans couleur.
- **Zones de classement** : liseré gauche + pictogramme (▲ montée, ◆ barrage, ▼ relégation) + légende visible.
- **Jauges** : valeur chiffrée toujours à côté ; la couleur dit à qui appartient la barre, pas si la note est bonne.

## 5. Character Design Direction

- **Gabi (seul personnage récurrent)** : ancien coach bourru, pull bordeaux `#71322F`, chemise ivoire, carnet de cuir ; 16 expressions (atlas v5) validées, rien à redessiner.
  - Cadrage buste, regard vers le contenu, placé du côté opposé au texte qu'il commente.
  - Médaillon (barre haute) : cadre doré, fond `PANNEAU`, 40 px, touche F1 écrite à côté.
  - Dans le corps (écrans de décision seulement) : buste 160-200 px, bulle = panneau `PANNEAU_2` rayon 12, texte crème 13 px.
  - Atlas opaque sur `#232228` (froid) : exiger un export avec transparence.
  - Mouvement réduit : expression fixe.
- **Joueurs (portraits 2D)** : buste, légère contre-plongée, lumière chaude latérale, fond uni sombre ; cadrage serré, rond dans les listes, rayon 12 dans les fiches ; numéro de maillot géant `IVOIRE_3` en filigrane (≤ 20 %). Pas de photo studio grise.
- **Joueurs (3D, match)** : réalisme stylisé, carrures par poste, maillot couleur de club unie + numéro dos ; pas de visage détaillé (1 joueur ≈ 60-120 px à 1080p).
- Distinguer nous / adversaire : plein/anneau en 2D, maillot + bandeau en 3D (clubs proches : l'adversaire change de maillots) ; staff et dirigeants en nom + fonction, sans portrait générique.
- Poses naturelles, jamais héroïques figées.

## 6. Environment Design Language

- **Lieux** : bureau du manager, vestiaire, tunnel, salle d'analyse, salle de presse, centre médical, stades par niveau. Architecture de rugby de club : béton, tôle, tribunes couvertes, bois du vestiaire.
- **Texture** : illustrations peintes photoréalistes, soirée/nuit, une source chaude dominante. **Un seul traitement** : légèrement désaturées et assombries, tirées vers le vert du fond (`FOND`), saturation des verts −20 % ; appliqué à la source.
- **Fond de l'interface** : ardoise `FOND` + photo d'ambiance de l'écran à 16 % d'opacité (banque « fond-* », `shell.gd` `FOND_PHOTO`, choix de Léo du 20/11/2026, écart avec la graphiste qui proposait l'aplat seul) ; les panneaux opaques passent dessus. Les autres illustrations vivent dans leur cadre : plein cadre (titre, tunnel, fin de saison), bandeau de page vitrine (club, match, accueil), jamais derrière un tableau. Toujours un voile sombre sous un texte posé dessus (≥ 4,5:1 mesuré au pire pixel).
- **Récit sans texte** : météo du match (tunnel pluie, vent, chaleur, sec), niveau du stade selon la division.
- **Terrain de tactique** : bandes `PELOUSE`/`PELOUSE_2` à plat, liseré `PELOUSE_BORD` ; lignes crème 1 px (essai, 22 m, 10 m, médiane), pointillés 4-4 `IVOIRE_3` (5 m, 15 m) ; proportions réelles (100 × 70 m, en-buts compris).

## 7. UI/HUD Visual Direction

### 7.1 Vue art

**Coque unique (16 écrans de gestion ; titre, chargement et match en sortent)**, mesures à 1920×1080, échelle 100 % :
- Rail gauche 232 px sur `PANNEAU` : logo complet (sans « Rugby Manager ») puis carte du club (écusson, nom, liseré de club), entrées numérotées 1 à 9 (Bureau, Réception, Effectif, Tactique, Entraînement, Recrutement, Club, Finances, Compétitions, puis Formation), 10 entrées principales au plus ; en pied, séparés par un filet : Réglages, Sauvegarder.
- Barre haute 48 px : bouton **Menu** visible (☰ + « Menu » + « Échap » écrit) ; fil d'Ariane ; à droite recherche (Ctrl+K), date, médaillon Gabi (F1), **Continuer** (pilule dorée, « Espace » écrit, dit ce qui bloque).
- **Menu pause** (Échap ou bouton Menu) : **fenêtre** centrée sur l'écran voilé (`PANNEAU` 70 %), rayon 18, ~400-560 px, seule exception à « pas de fenêtre » (choix de Léo du 20/11/2026) : Reprendre, Sauvegarder, Charger, Réglages, Retour à l'accueil, Quitter. Même menu en match (Échap = pause + menu).
- Contenu : en-tête compact sans photo, puis grille de panneaux séparés de 16 px ; marges 24 px ; espacements 4 / 8 / 12 / 16 / 24 / 32.
- Match (direct) : bandeau de score haut-gauche (écussons des clubs, score crème 40 px, temps, phase) sur `PANNEAU` 90 % rayon 18 ; journal en bas-gauche 16 px ; tiers inférieur pour l'événement (une bannière à la fois).

**Typographie** (OFL, dans le jeu) :
- **Barlow Condensed**, **droite** (SemiBold, Bold, ExtraBold ; plus de fichiers italiques) : titres, en-têtes, menus, onglets, boutons, chiffres d'affiche. C'est la police des titres retenue par Léo (écart : la charte prévoit une police d'affiche distincte, abandonnée).
- **DM Sans** : texte courant et cellules ; chiffres tabulaires (`tnum`, à vérifier).
- Pas de troisième famille. Exception (Léo, 20/11/2026) : Anton (OFL) pour le nom, le numéro, le niveau, le potentiel et les titres de blocs de la fiche joueur. Élargie le 21/11/2026 (Léo) aux grands titres des écrans Carrière (« LE PARCOURS DU MANAGER ») et Vestiaire (« LE VESTIAIRE »), toujours droite.

| Niveau | Police | Taille / interligne | Casse |
|---|---|---|---|
| Affiche (tunnel, fin de saison) | BC ExtraBold | 64 / 1,0 | capitales |
| Score direct, résultat | BC ExtraBold | 40-48 / 1,0 | — |
| Titre d'écran | BC ExtraBold | 28 / 1,1 | capitales, une ligne |
| Titre de panneau | BC Bold | 18 / 1,2 | capitales, 3 mots |
| Surtitre | BC SemiBold, doré | 12-13, interlettrage +8 % | capitales |
| Nom d'entité | BC SemiBold | 15 / 1,2 | normale |
| Menus, onglets, boutons | BC SemiBold | 15-18 | bas de casse |
| Corps | DM Sans Regular | 13 / 18 | normale |
| Cellule de tableau | DM Sans (chiffres `tnum`, à droite) | 13 / ligne 26 | normale |
| En-tête de colonne, légende | BC SemiBold, `IVOIRE_3` | 12-13 | capitales |
| Journal, sous-titres | DM Sans Medium | 16 / 22 | normale |

- Graisse avant taille ; jamais plus de 4 mots en capitales. Chiffres mis en avant en BC gras.
- **Échelle d'interface** : 90 / 100 / 115 / 130 %, défaut 100 %. **Aucun texte rendu sous 12 px réels** ; 90 % seulement si la fenêtre fait ≥ 2560 px. Recomposer (moins de colonnes) plutôt que tronquer.

**Iconographie** : pictogrammes au trait 1,75 px, 20 px (menus, boutons), 16 px (texte), 24 px au plus ; gris-vert au repos, crème actif, doré devant un titre de panneau ; toujours un mot. Famille Tabler (MIT) proposée par la graphiste, **à valider** ; pictogrammes rugby à créer dans le même trait. Icône d'application : symbole doré, 12 % de marge, 16-256 px, `.ico` Windows (16 et 24 provisoires).

**Composants** (un seul de chaque ; états : survol = `PANNEAU_2` ou aplat éclairci de 8 % ; enfoncé 98 % ; focus = anneau doré 2 px décalé de 2 px ; désactivé = opacité 40 % + raison au survol) :
- **Panneau** : `PANNEAU`, rayon 18, marge 18, titre capitales BC Bold 18 (icône dorée avant le titre) ; sans bordure ; ombre portée sur panneaux, cartes et tuiles : noir 50 %, sans décalage, étendue 4 px (choix de Léo du 20/11/2026, d'après la graphiste qui proposait 10 px). Jamais sur pilules, boutons, champs, pastilles ni lignes ; panneau-contenant d'un écran, jamais un panneau dans un panneau sauf carte (rayon 12).
- **Bouton principal** : pilule dorée, texte `PANNEAU`, 40 px (32 compact), un par écran ; survol `OR_VIF`. Continuer en coque ; sur une page sans Continuer, l'action qui fait avancer (« Lancer le match », « Valider la composition »).
- **Bouton secondaire** : contour 1 px `FILET`, texte crème ; secondaire plein : `VERT_FRANC`, texte crème, dans un panneau ; **lien** : sans fond ni contour, gris-vert + flèche, souligné au survol (« Annuler », pied de page). Libellé ≤ 4 mots ; jamais de texte en vert franc.
- **Onglets** : pilules ; actif = aplat crème, texte `PANNEAU` ; inactif = gris-vert ; jamais actif en vert.
- **Pastilles** : rayon 6, 24 px de haut (20 dans un tableau), BC SemiBold 14, pictogramme 14 px puis mot ; favorable (`VOILE_VERT` + vert clair), attention (`VOILE_DORE` + doré), neutre (`PANNEAU_2` + gris-vert) ; jamais sans mot ; 2 par ligne au plus. Compteur : pastille dorée, chiffre `PANNEAU` (écart à valider : ne compte pas comme aplat principal).
- **Tableau** (densité FM conservée) : dans un panneau ; lignes 26 px, filet entre lignes, pas de bandes colorées ; en-têtes capitales `IVOIRE_3` alignés sur leurs valeurs ; noms DM Sans 600 crème ; chiffres alignés à droite ; colonne triée : en-tête doré + flèche ; survol `PANNEAU_2`, sélection `SELECTION` sur toute la ligne (rayon 6) ; regroupement par poste avec intertitre ; tri et filtre au clavier. Valeur colorée seulement pour un état.
- **Jauge** : rail `PANNEAU_3` 8 px en pilule, remplissage en pilule, valeur chiffrée toujours ; comparaison : nous vert clair à gauche, adversaire doré à droite, critère au centre ; note isolée : vert clair > 80, gris-vert 50-80, doré < 50, avec le chiffre ; pas de dégradé.
- **Menu latéral** : entrée 40 px, icône 20 px gris-vert, libellé BC 600 ; **entrée active = pilule crème, icône et texte `PANNEAU`** ; survol `PANNEAU_2` ; compteur = pastille.
- **État vide** : panneau avec pictogramme gris-vert, une phrase dite par le club (« Rien à décider aujourd'hui »), et au plus une action en lien ou secondaire ; jamais un bouton doré de remplissage.
- **Champ** : pilule, fond `PANNEAU_3`, contour `FILET`, focus anneau doré.

**Exceptions de Léo contre la charte de la graphiste (maintenues)** :
- **Pas de fiche à droite qui suit la sélection** : un clic ouvre la fiche joueur complète (page), le survol montre une mini-fiche ; l'écran de travail = barre d'outils + tableau pleine largeur.
- **Pas de petite fenêtre** (composant « Fenêtre » non adopté) : les décisions se prennent dans la page, sur panneau ; aucune boîte modale. Seule exception : le menu pause (fenêtre sur l'écran voilé).

**Mouvement** :
- Entrée d'écran : fondu + glissement vertical de 8 px, 160 ms, ease-out ; cascade 30 ms par panneau, 6 panneaux au plus.
- Sélection : fond qui passe en 100 ms ; tableaux sans animation. Continuer : symbole qui se remplit pendant le calcul.
- Essai : bannière du club qui marque dans le tiers inférieur, 600 ms au total, puis retour à l'état de base ; aucun flash.
- Mouvement réduit : fondus 100 ms, rien ne glisse ; « Transitions : Aucune » = instantané.
- Jamais : rebond, élastique, parallaxe permanente, clignotement > 3/s.

**Interdits** : photo de fond non voilée ou derrière un tableau sans panneau ; panneau avec bordure, verre, biseau ; ombre autre que celle de la charte (noir 50 %, 4 px, sans décalage) ou posée sur une pilule, un bouton, un champ, une pastille ou une ligne ; plus d'un aplat doré par écran ; doré sans mot ni pictogramme pour une attention ; vert franc en texte ou trait fin ; vert clair en paragraphe ; rouge hors cartons rouges et vraies erreurs ; couleur de club sur bouton, texte, jauge ou fond ; texte penché ; `NUIT` comme panneau ; page à fond clair (hors document papier) ; fiche flottante à droite ; fenêtre qui s'ouvre ; icône sans mot ; texte incrusté dans une image ; mentions « fictif » / « IA ».

### 7.2 Vue UX

- **Interactions** : la densité FM sert la semaine (comparer, trier) ; arrondi et pilules n'ajoutent aucun coût de lecture.
- **Lisibilité au direct** : score, temps, phase lisibles en < 2 s (40 px, `PANNEAU` 90 %) ; journal 16 px relisible.
- **Plancher accessibilité** : contrastes ≥ 4,5:1 sur les paires de texte (§4.4) ; ≥ 3:1 pour focus et marqueurs ; couleur jamais seule (§4.5) ; focus distinct du survol et de la sélection ; Échap + bouton Menu visible ; cibles ≥ 24 px.
- **Retour** : Continuer dit ce qui bloque ; chaque refus dit quoi faire ; sauvegarde visible.
- **Conflit 1 (tranché par Léo)** : T1 exige 14 px de corps à 1920 ; Léo a choisi 13 px (densité FM). Compensation : plancher 12 px réels, échelle réglable, contrastes élevés. T1 et E1 à réécrire.
- **Conflit 2** : la charte propose des lignes de 40 px ; Léo garde la densité FM (26 px, comparatif du 20/11) ; cibles ≥ 24 px.
- **Conflit 3** : Échap = Retour et Échap = menu pause. Retenu : Échap quitte d'abord la sous-page ouverte, puis ouvre le menu pause ; le bouton Menu reste l'accès direct.
- **Conflit 4** : 90 % d'échelle descend sous T1 à 1920 ; réservé aux fenêtres ≥ 2560 px.
- **Conflit 5** : « un seul aplat doré par écran » contre un écran à deux décisions fortes. Retenu : un seul doré, l'autre en secondaire plein ; à escalader au creative-director si le besoin revient.

## 8. Asset Standards

### 8.1 Vue art

- Nommage : `[categorie]_[nom]_[variante]_[taille].[ext]` (ex. `ui_ico_effectif_20.svg`, `env_tunnel_pluie_2560.png`, `char_gabi_rire_512.png`, `brand_logo_creme-dore_1774.png`).
- **Logo définitif** de la graphiste intégré : version principale crème + « 27 » doré, transparente ; symbole (doré, crème, vert clair) ; icônes 16, 24, 32, 48, 64, 128, 256 px et `.ico` pour l'exécutable Windows, dans `native/godot/branding/`. Logo complet ≥ 120 px de large (sinon symbole), symbole net dès 48 px ; marge = moitié de la hauteur du « 27 » (logo), quart de la largeur (symbole). 16 et 24 px provisoires (version simplifiée à dessiner).
- Formats : icônes SVG au trait (couleurs remplacées à l'exécution) ; illustrations PNG 2560 × 1440 (plein cadre) et 2560 × 480 (bandeaux) ; portraits PNG transparents 512 × 512 ; Gabi PNG transparent 512 × 640.
- Couleur : sRGB ; étalonnage §6 appliqué à la source, pas dans le jeu.
- Polices : TTF OFL, licence jointe (Barlow Condensed droite, DM Sans, Anton pour la fiche joueur et les grands titres Carrière et Vestiaire).
- 3D : réutiliser l'existant ; maillots par couleur de club, sans texture de marque.

### 8.2 Vue technique

- Moteur : Godot 4.7, rendu GL Compatibility (`project.yaml`).
- **Aucun budget de performance défini** (`project.yaml` sans bloc `performance`, `technical-preferences.md` à `[TO BE CONFIGURED]`) : pas de limite de polygones, mémoire texture ni matériaux à citer.
- Panneaux, pilules et jauges : `StyleBoxFlat` (`Charte.style_panneau`, `Charte.style_pilule`), sans shader ; shaders 2D éventuels compatibles GL Compatibility.
- Polices : `hinting` par défaut changé en 4.7 (`breaking-changes.md`) : vérifier la netteté à 12-13 px ; `tnum` et `FontVariation` non couverts par `docs/engine-reference/godot/`, à tester.
- Illustrations : ~2 Mo PNG chacune (≈ 30 dans `immersive08/`) ; 2560 × 1440 RGBA ≈ 14 Mo en mémoire vidéo.
- **Arbitrage ouvert** : sources 2560 (netteté 1440p) ou 1920 compressé VRAM (mémoire, démarrage lent) ; défaut proposé : 2560 pour ≤ 3 illustrations chargées à la fois, sinon 1920.

## 9. Reference Direction

| Référence | Prendre précisément | Éviter |
|---|---|---|
| Charte de la graphiste « Rugby Legacy 27 » (source) | nuancier 7 teintes, panneaux 18 sans bordure, pilules, rôles du doré et du vert clair, logo | fiche à droite qui suit la sélection, composant Fenêtre, lignes de 40 px |
| Football Manager (FM24 tableaux, OOTP) | densité : vrais tableaux triables, lignes 26 px, beaucoup de colonnes | son habillage (gris-bleu, dégradés), cartes FM26 qui remplacent les tableaux, panneau de détail permanent |
| Habillage Six Nations 2025 et scorebug moderne | score et horloge protégés et dominants ; une seule bannière liée au temps ; retour à l'état de base | couleurs et marques du tournoi ; dégradés et reliefs |
| Disco Elysium | l'illustration peinte porte l'ambiance, l'interface reste sobre à côté | texte trop petit, colonne de texte sans hiérarchie |
