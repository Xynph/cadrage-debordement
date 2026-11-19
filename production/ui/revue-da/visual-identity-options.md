# Rugby Legacy 27 — Identité visuelle : trois options (art bible §1-4 et §9)

> Auteur : agent `art-director` (CCGS), 19/11/2026. Rigueur `minimal` (listes de contraintes).
> Statut : **PROPOSITION, en attente du choix de Léo.** Rien n'est à traduire en code avant son choix.
> Regard propre : les maquettes A/B/C de la revue précédente n'ont pas été regardées ; seules la v6 « Carnet du club », Gabi et les illustrations du jeu ont servi de matière.

---

## 0. Ce que j'ai regardé et ce que j'en retiens

### 0.1 Veille (ce qui fait un bel écran de gestion sportive)

| Source | Ce qu'on prend | Ce qu'on évite |
|---|---|---|
| FM26 (tuiles → cartes, « Portal ») | Une tuile = un résumé cliquable qui s'ouvre en détail ; recherche globale. | Tout en tuiles, plus de vrais tableaux : critiqué (réapprentissage, bugs, densité perdue). |
| Motorsport Manager | Interface « propre et fluide », peu de chiffres par panneau, ADN FM mais plus aéré. | Simplification qui vide les écrans de fond (pièces, installations). |
| F1 Manager 24 | Vues et sons empruntés à la vraie retransmission : la télé rend la donnée crédible. | Menus « très textuels » sous un vernis brillant. |
| Six Nations 2025 (habillage) | Photos de joueurs maison, cadrées en contre-plongée, poses dynamiques, plus de corps visible ; bannière « ESSAI +5 » animée sur l'horloge ; minuteur d'exclusion ; graphismes compréhensibles sans commentaire. | Marques et couleurs du tournoi. |
| Six Nations (feed mondial) | Une seule grammaire graphique pour 15 matchs ; données Opta transformées en graphique en ~3 s. | Gros logo sur le bandeau qui masquait le jeu (cadrage desserré après coup). |
| Scorebug moderne (SVG 2026) | Fin des dégradés et des reliefs, « laisser respirer le jeu » ; la typo porte l'identité ; score et horloge toujours dominants ; animation = glisser/rétrécir pour faire de la place, puis retour à l'état de base. | Effets de finition plaqués après coup. |
| Coupe du monde 2023 (AE Live / Ignite, prix Motion Awards) | Un « système » d'éléments animés plutôt que des écrans isolés ; police dédiée à l'identité. | — |
| Persona 5 (hors sport) | Palette restreinte (rouge/noir/blanc), une seule couleur de sélection qui tranche ; l'élément survolé grandit ; zones d'écran fixes par type d'info ; la typo crie le style. | Lisibilité sacrifiée (l'équipe a dû corriger des menus « illisibles »). |
| Disco Elysium (hors sport) | L'écran pensé comme un seul tableau peint ; l'illustration porte l'ambiance, l'interface reste sobre ; colonne de texte façon fil de messages. | Texte trop petit, aucune personnalisation. |
| NBA 2K25 MyGM (hors genre direct) | Page « web 2.0 » rétro : un registre visuel peut raconter un lieu ou une époque. | — |

Constat confirmé par la recherche : aucun jeu de rugby n'a de vraie direction artistique de management ; les références solides sont FM/OOTP pour la densité et l'habillage télé du rugby pour l'émotion.

### 0.2 L'existant (captures 1920, v6, Gabi, illustrations)

Ce qui marche :
- **Gabi** : personnage chaleureux (pull bordeaux, carnet en cuir), 16 expressions ; c'est déjà la meilleure pièce du jeu.
- **Illustrations** (vestiaire, tunnel sous la pluie, stade des Brumes, briefing) : lumière chaude sur fond sombre vert-noir, très cinématographiques ; elles méritent plus de place.
- **Tableau d'effectif** : dense, trié, lisible ; à garder tel quel dans le fond.
- **v6 « Carnet du club »** : colonnes ivoire, bloc central photo sombre, numéros « 01 / À décider », une seule affiche qui crie (BÉZIERS — VALENCE). C'est la bonne hiérarchie.

Ce qui ne marche pas :
- **Tout est un cadre** : chaque bloc a sa bordure, son titre en capitales, son bouton contouré ; l'œil ne sait pas où aller (bureau : 9 cadres de même poids).
- **Quatre couleurs fortes concurrentes** (vert vif, or, bordeaux, rouge) sur fond vert-noir : le vert sert à la fois de fond, de « disponible », de sélection et de bouton.
- **Petits textes** : sous-titres de 11-12 px, étiquettes ambre sur bordeaux, liens en or sur noir.
- **Le direct** n'a pas d'habillage : bandeau générique, journal en bas sans hiérarchie, aucun moment fort.
- **Photos** traitées comme des vignettes rectangulaires ; portraits de joueurs sur fond studio gris : sans lien avec l'univers du club.

### 0.3 Matériel disponible

- Polices dans le jeu : **Barlow Condensed** (Medium, SemiBold, Bold, ExtraBold), **DM Sans** (variable). Toutes deux OFL.
- Ajouts proposés (Google Fonts, OFL) : **Fraunces** (serif à caractère, option A), **Barlow** non condensé (option B, texte), **IBM Plex Mono** (option C, chiffres de tableau noir). À vérifier : licence dans le fichier, chiffres tabulaires (`tnum`) et import Godot avant usage.

---

## 1. Les trois directions

Échelles typographiques données à **1280×720** (×2 en 2560×1440). Plancher : **14 px** pour tout texte utile ; 13 px toléré pour les en-têtes de colonnes en capitales espacées seulement.

### Direction A — « Le Programme de match »

**Intention** : le jeu se lit comme le programme qu'on achète à l'entrée du stade et le carnet de Gabi : papier, encre, une grande photo, des numéros de rubrique ; le rugby comme culture de club, de village, de tradition.

**Jetons couleur**

| Jeton | Hex | Rôle |
|---|---|---|
| `papier` | `#F2EEE4` | fond d'écran |
| `carte` | `#FBF9F4` | surface de lecture (colonnes, fiches) |
| `encre` | `#1C2226` | texte principal, titres |
| `encre-2` | `#545D62` | texte secondaire, légendes |
| `filet` | `#CFC8B8` | filets fins (jamais de cadre complet) |
| `club` | `#7A1F2B` | couleur du club (ici bordeaux) : action principale, ligne active, n° de rubrique |
| `or-vieilli` | `#8A6420` | distinctions, trophées, records (≥ 16 px seulement) |
| `nuit` | `#161B1F` | le seul bloc sombre de l'écran (affiche du match, moment clé) |
| `nuit-texte` / `nuit-texte-2` | `#F2EEE4` / `#A9B0B2` | texte sur `nuit` |
| `v` / `n` / `d` | `#276B44` / `#8A5A0E` / `#A0302A` | victoire / nul / défaite, toujours avec la lettre |

**Typographie** : titres **Fraunces 700** (ou, sans ajout, Barlow Condensed ExtraBold italique) ; rubriques et chiffres **Barlow Condensed SemiBold** ; texte **DM Sans**.
Échelle : affiche 44 / titre d'écran 30 / rubrique 22 / sous-titre 17 / texte 15 / légende 14 / en-tête de colonne 13 caps +6 %.

**Formes** : rayons 2 px (cartes), 999 px pour les pastilles V/N/D seulement ; filets 1 px `filet`, filet de rubrique 3 px `club` (24 px de long) ; aucune ombre portée, aucun dégradé.
**Forme signature** : le **numéro de rubrique** « 01 / » en `club` + filet horizontal pleine colonne, comme un programme imprimé. Les sections sont séparées par l'espace et un filet, jamais par un cadre.

**Composition**
- Grille 12 colonnes, gouttière 24 px, marges 32 px ; colonnes de lecture ≤ 70 caractères.
- Asymétrie assumée : une colonne étroite « À décider » à gauche, un bloc `nuit` central (affiche), une colonne « cap » à droite (structure v6).
- **Un seul bloc `nuit` par écran.** Un seul bouton plein `club` par écran ; les autres actions sont des liens soulignés avec flèche.
- Tableaux : lignes zébrées à 3 % d'encre, ligne du club en `club` 8 % + filet gauche 3 px.

**Photos et portraits**
- Illustrations de lieux en grand, à fond perdu dans le bloc `nuit`, voile noir 35 % en bas pour le texte.
- Portraits de joueurs détourés sur `carte`, légère teinte chaude (sépia 10 %), cadrage poitrine, numéro de maillot géant en filigrane `filet` derrière.
- Gabi en marge, comme une annotation dans le programme (bulle papier, filet `club`).

**Mouvement** : feuilletage horizontal court (140 ms, ease-out) entre écrans ; apparition des rubriques en cascade 40 ms ; rien ne rebondit. Option « animations réduites » = fondu 80 ms.

**Interdit** : cadres sur tout le pourtour, capitales sur plus de 4 mots, plus d'une couleur forte (hors V/N/D), fond blanc pur, texte `or-vieilli` sous 16 px, textures papier visibles (grain, taches).

**Risques** : écran clair pendant de longues sessions nocturnes (prévoir une variante « encre » sombre) ; le match et la 3D jurent avec le papier ; Fraunces est une police de plus à importer.

---

### Direction B — « Le Direct »

**Intention** : tout ce qui touche au match et à la compétition a l'autorité d'une retransmission du samedi soir : la donnée paraît vraie parce qu'elle est habillée comme à la télé.

**Jetons couleur**

| Jeton | Hex | Rôle |
|---|---|---|
| `fond` | `#0D141C` | ardoise bleutée (pas de noir pur) |
| `panneau` | `#15202B` | bandeaux, cartes |
| `panneau-2` | `#1D2B39` | survol, ligne sélectionnée |
| `texte-1` | `#EEF2F5` | texte principal |
| `texte-2` | `#9AA9B8` | texte secondaire |
| `club` | `#B82E3C` | aplat du club (texte blanc dessus) ; variable selon le club, plafonnée en luminance |
| `adversaire` | `#4A86DB` (texte) / `#7AA7EC` sur `panneau` | camp adverse |
| `essai` | `#F4B740` | moments forts : essai, record, bannière ; texte `fond` dessus |
| `data` | `#4CC3E0` | chiffres d'analyse, courbes, possession |
| `v` / `n` / `d` | `#43C383` / `#F4B740` / `#EF5B52` | toujours avec la lettre ; `d` réservé au `fond` ou au `panneau` |

**Typographie** : **Barlow Condensed Bold** en capitales pour titres et noms d'équipes ; **Barlow** (ou DM Sans) pour le texte ; **chiffres tabulaires obligatoires**.
Échelle : score 64 / titre d'écran 32 caps / bandeau 22 caps / sous-titre 17 / texte 15 / légende 14 / en-tête 13 caps +8 %.

**Formes** : rayons 0 ; traits 1 px `panneau-2`, liseré de 4 px `club` ou `adversaire` sur le bord d'entrée des bandeaux.
**Forme signature** : la **coupe à 12°** (la ligne d'avantage vue de la tribune) : bandeaux et étiquettes en parallélogramme, coin coupé, jamais de rectangle arrondi. Score encadré par deux plaques de couleur de club.

**Composition**
- Écran en couches comme une retransmission : bandeau haut (contexte), zone de jeu ou de donnée au centre, « tiers inférieur » pour l'événement.
- Score et horloge toujours dominants et immobiles ; tout le reste glisse autour.
- Chiffres énormes réservés aux vrais indicateurs (score, classement, points) ; une seule « bannière » à la fois.
- Classements : vrais tableaux, ligne du club en aplat `club` 20 %, zones de qualification par filet latéral `data`, de relégation par filet `d` + pictogramme.

**Photos et portraits**
- Portraits en buste, contre-plongée légère, sur fond `club` en aplat avec numéro géant 30 % d'opacité (façon composition d'équipe Six Nations).
- Illustrations de stade et de tunnel en plein cadre, désaturées 20 %, voile `fond` 50 % en dégradé du bas.
- Gabi en médaillon de consultant (cercle, liseré `essai`), dans le tiers inférieur.

**Mouvement** : entrées par glissement le long de la diagonale 12° (180 ms, ease-out) ; essai = l'horloge s'efface, bannière `essai` « ESSAI +5 » glisse (600 ms au total) puis tout revient à l'état de base ; chiffres qui « tombent » (compteur 300 ms). Vitesse réglable, option pour couper.

**Interdit** : dégradés de relief, reflets, biseaux ; plus d'une bannière à l'écran ; rouge `club` et `d` côte à côte sans lettre ; texte sous 14 px dans les bandeaux ; logos qui masquent le terrain.

**Risques** : appliquée au bureau ou aux finances, devient un tableau de bord criard et fatigant ; « encore un jeu sombre » proche de l'existant ; la couleur du club variable doit être contrôlée (clubs jaunes, blancs).

---

### Direction C — « Le Tableau noir »

**Intention** : l'interface est tracée comme le terrain et le tableau du staff : lignes de 22, de 10 m et pointillés de 5 m structurent l'écran ; le manager pense en zones et en lignes.

**Jetons couleur**

| Jeton | Hex | Rôle |
|---|---|---|
| `fond` | `#0E1411` | vert-noir du vestiaire de nuit |
| `pelouse` | `#13201A` | panneaux, zones |
| `ligne` | `#1F3328` | tracé de grille (non textuel) |
| `craie` | `#EAE6D8` | texte principal, tracés actifs |
| `craie-2` | `#A2ADA4` | texte secondaire |
| `menthe` | `#7FD3A0` | donnée positive, focus clavier |
| `poteau` | `#E6C35C` | sélection, élément actif (texte `fond` dessus) |
| `brique` | `#E07A6A` | alerte, défaite |
| `adverse` | `#7FA8E0` | camp adverse sur les schémas |
| `club` | couleur du club en **trait** seulement (liseré 2 px) | identité sans aplat |

**Typographie** : **Barlow Condensed Medium** pour titres (casse normale) ; **DM Sans** pour le texte ; **IBM Plex Mono** pour tous les chiffres de tableaux et les annotations tactiques.
Échelle : titre 28 / zone 20 / sous-titre 16 / texte 15 / chiffres mono 14 / légende 14 / en-tête 13 caps.

**Formes** : rayons 0 ; traits 1 px `ligne`, tracés actifs 2 px `craie` ; pointillés 4-4 pour les séparations secondaires.
**Forme signature** : la **grille-terrain** : l'écran est divisé en bandes verticales aux proportions d'un terrain (en-but / 22 / 10 / milieu) ; les séparations sont des lignes de terrain, les sous-séparations des pointillés de 5 m. Les flèches tactiques à la craie (trait irrégulier léger) annotent les décisions de Gabi.

**Composition**
- Gauche → droite = de notre en-but vers celui de l'adversaire : la lecture suit le sens de l'attaque (ex. effectif : avants à gauche, arrières à droite ; plan de jeu : zones réelles).
- Pas de cartes : des zones délimitées par des lignes.
- Densité élevée assumée, chiffres alignés en mono.

**Photos et portraits**
- Portraits en duotone `fond`/`craie` (gravure), couleur rendue seulement au survol ou à la sélection.
- Illustrations utilisées en bande étroite (panoramique 6:1) en tête d'écran, voilées 60 %.
- Gabi dessiné « au bord du tableau », bulles à la craie.

**Mouvement** : les lignes se tracent (220 ms) à l'ouverture ; les flèches tactiques s'écrivent ; sélection = la ligne `poteau` glisse. Peu d'animations ailleurs.

**Interdit** : aplats de couleur vive, photos en couleur au repos, cartes arrondies, ombres, effet « craie » sur le texte courant (seulement sur les annotations).

**Risques** : très proche de la palette actuelle vert-noir (gain perçu faible) ; portraits en duotone moins chaleureux, en tension avec Gabi ; une grille-terrain stricte rend les écrans non tactiques (finances, presse) artificiels ; IBM Plex Mono en plus.

---

## 2. Humeur par état de jeu (§2, synthèse)

| État | A Programme | B Direct | C Tableau noir |
|---|---|---|---|
| Bureau, semaine | matin calme, lumière du jour, papier | studio d'avant-émission | réunion de staff |
| Préparation, tactique | carnet annoté | analyse d'avant-match | **point fort** : tableau, flèches |
| Avant-match / tunnel | affiche `nuit` plein écran | **point fort** : générique, compositions | — |
| Match en direct | (hors registre) | **point fort** : bandeau, bannière d'essai | entracte 2D (terrain vu de dessus) |
| Après-match | page de compte rendu | résumé chiffré, temps forts | pourquoi : schéma des leviers |
| Finances, club, presse | **point fort** : journal du club | trop criard | artificiel |

## 3. Langage des formes (§3, synthèse)

- A : **filet + numéro** (horizontal, calme, imprimé) ; l'espace sépare.
- B : **coupe à 12°** (diagonale, élan, avancée) ; la couleur sépare.
- C : **ligne de terrain** (orthogonale, mesurée) ; le tracé sépare.
- Commun à toutes : jamais de rectangle arrondi à ombre portée (le look « grande carte de téléphone » rejeté par Léo).

## 4. Couleurs : sûreté daltonisme et contrastes (§4)

**Paires à risque et repère de secours**
- V vert / D rouge (toutes options) : lettre V/N/D dans la pastille, toujours ; forme carrée pour V, ronde pour N, triangle pour D en option daltonien.
- `club` rouge / `d` rouge (B) : la défaite porte la lettre et un pictogramme ; le club n'est jamais un texte seul.
- N ambre / `essai` or (B) : même couleur volontairement ; N toujours lettré, la bannière toujours textuelle.
- `menthe` / `poteau` (C) : la sélection ajoute un trait 2 px, la donnée positive une flèche ▲.
- Notre camp / adversaire sur le terrain : couleur **et** forme (plein / anneau).

**Contrastes calculés (WCAG 2.x, ≥ 4,5:1 exigé)**

| Option | Paire | Ratio |
|---|---|---|
| A | `encre` sur `papier` | 13,88 |
| A | `encre-2` sur `papier` / sur `carte` | 5,81 / 6,40 |
| A | `club` sur `papier` | 8,81 |
| A | `carte` sur `club` (bouton) | 9,70 |
| A | `or-vieilli` sur `papier` | **4,62** (limite : ≥ 16 px) |
| A | `nuit-texte` / `nuit-texte-2` sur `nuit` | 14,97 / 7,88 |
| A | `v` / `n` / `d` sur `papier` | 5,54 / 5,11 / 6,14 |
| B | `texte-1` sur `fond` / `panneau` | 16,45 / 14,65 |
| B | `texte-2` sur `fond` / `panneau-2` | 7,71 / 6,00 |
| B | blanc sur `club` | 6,01 |
| B | `essai` sur `fond` (et `fond` sur `essai`) | 10,31 |
| B | `data` sur `fond` | 8,99 |
| B | `adversaire` sur `fond` / clair sur `panneau` | 5,05 / 6,73 |
| B | `v` / `d` sur `fond` | 8,27 / 5,55 |
| B | `v` / `d` sur `panneau` | 7,36 / **4,94** |
| C | `craie` sur `fond` / `pelouse` | 14,92 / 13,46 |
| C | `craie-2` sur `fond` / `pelouse` | 8,03 / 7,24 |
| C | `menthe` / `poteau` / `brique` / `adverse` sur `fond` | 10,41 / 10,94 / 6,36 / 7,61 |
| C | `fond` sur `poteau` | 10,94 |
| C | `brique` sur `pelouse` | 5,73 |

Toutes les paires de texte passent. Règle à ajouter pour B : la couleur de club réelle (variable) doit être assombrie jusqu'à ≥ 4,5:1 avec le blanc avant usage en aplat ; sinon texte `fond` dessus.

---

## 5. Avis du directeur artistique

**Je recommande un mélange réglé : A comme maison, B pour le jour de match, C réduit à un composant.**

| Écrans | Registre | Pourquoi |
|---|---|---|
| Accueil, bureau, réception, presse, fiche joueur, club, formation, finances | **A Programme** | C'est la vie du club ; Léo a déjà validé cette hiérarchie (v6) ; Gabi (pull bordeaux, carnet en cuir) y est chez lui. |
| Effectif, recrutement, grand livre | **A, variante « encre »** (mêmes polices et règles, fond `nuit`, cartes `#1F262B`) | Tableaux denses pour de longues sessions : sombre reposant, sans changer de langage. |
| Composition, plan de jeu, entraînement, préparation | **A + composant « tableau noir » de C** (terrain, flèches à la craie, chiffres alignés) | La tactique gagne à être dessinée ; le reste de l'écran reste « programme ». |
| Avant-match, match en direct, entracte, après-match, classements, calendrier, rivalités | **B Direct** | Le passage du papier à la télé dit au joueur « on entre dans le match » ; c'est le seul endroit où la diagonale et les grands chiffres ont le droit de crier. |

Ce qui relie le tout : mêmes polices de base (Barlow Condensed + DM Sans), même échelle, mêmes V/N/D lettrés, même couleur de club, aucun cadre complet nulle part.

**Ce qu'on perd** : l'unité « tout sombre » actuelle (passer du clair au sombre doit être une transition voulue, 200 ms, jamais un clignotement) ; la grille-terrain de C comme système global ; Fraunces si on refuse une police de plus (repli : Barlow Condensed ExtraBold italique, comme la v6).

**Pourquoi pas une seule direction** : A seule rate le match (le papier ne sait pas faire monter la tension) ; B seule épuise sur le bureau et ressemble à l'existant ; C seule est la plus proche de ce qui ne plaît plus (vert-noir uniforme).

**Désaccord à signaler** : l'existant utilise le vert vif à la fois pour fond, disponibilité, sélection et bouton. Quelle que soit l'option, le vert doit redevenir **uniquement** « victoire / disponible ».

---

## 9. Direction de référence (par option)

| Option | Référence | Prendre précisément | Éviter |
|---|---|---|---|
| A | Programmes de match et journaux de club | numéro de rubrique, filets, une photo dominante | grain de papier, polices « vintage » |
| A | Disco Elysium | l'illustration porte l'ambiance, l'interface reste sobre | texte trop petit |
| B | Six Nations 2025 | portraits en contre-plongée, bannière « ESSAI +5 » liée à l'horloge, minuteur d'exclusion | couleurs et marques du tournoi |
| B | Scorebug moderne (SVG 2026) | score et horloge protégés, animation qui revient à l'état de base | dégradés, reliefs |
| C | Persona 5 | palette restreinte + une couleur de sélection qui tranche ; zones d'écran fixes | lisibilité sacrifiée au style |
| Toutes | FM26 (en négatif) | tuile résumé → détail, recherche globale | supprimer les vrais tableaux |

---

## Sources

Lues (page ouverte) :
- https://www.svgeurope.org/blog/headlines/six-nations-debuts-new-graphics-package-to-engage-fans-old-and-new/
- https://www.svgeurope.org/blog/headlines/live-from-six-nations-rugby-creating-a-universal-language-for-graphics/
- https://www.sportsvideo.org/2026/06/09/designing-the-modern-scorebug-how-broadcast-graphics-teams-are-rethinking-the-most-important-element-on-screen/
- https://mechanicsofmagic.com/2022/04/23/visual-design-of-games-persona-5/

Vues par résumé de recherche seulement (page non ouverte, ou ouverture en échec 404) :
- FM26 : https://www.footballmanager.com/features/total-football-total-control-fm26s-reimagined-user-interface ; https://www.gosugamers.net/entertainment/news/77565-review-football-manager-26-looks-good-but-its-buggy-interface-leaves-much-to-be-desired ; https://www.thesixthaxis.com/?p=465393 ; https://realsport101.com/article/football-manager-26-a-deep-dive-into-the-new-interface (404 à l'ouverture)
- Motorsport Manager : https://www.pcgamer.com/uk/motorsport-manager-wants-to-be-the-sim-racing-fans-deserve ; https://stuff.tv/?p=59310 ; https://www.racefans.net/?p=331987 ; https://overtake.gg/news/f1-manager-22-review.743/page/presentation-and-menus.152
- F1 Manager 24 : https://www.techradar.com/gaming/f1-manager-24-review ; https://www.impulsegamer.com/f1-manager-2024-pc-review/ ; https://www.tomsguide.com/gaming/f1-manager-24-let-me-live-out-my-dream-to-destroy-max-verstappen
- Coupe du monde 2023 : https://www.svgeurope.org/blog/headlines/ae-lives-auckland-based-agency-ignite-delivers-design-package-for-rugby-world-cup-2023/ ; https://www.ae.live/work/rugby-world-cup-2023 (404 à l'ouverture)
- Persona : https://www.siliconera.com/what-makes-the-ui-and-menus-in-persona-games-so-good/ ; https://www.pcgamer.com/games/rpg/persona-series-director-says-atluss-flashy-menus-are-actually-really-annoying-to-design
- Disco Elysium : https://www.pcgamer.com/games/rpg/why-does-isometric-perspective-suit-disco-elysium-you-can-design-the-entire-game-as-if-it-was-a-painting ; https://80.lv/articles/disco-elysium-working-on-ui-design
- NBA 2K25 MyGM : https://nba.2k.com/2k25/courtside-report/mynba/

Déjà au registre (`docs/ressources-utiles.md`, veille du 19/11/2026), non relues ici : Passion4FM skins FM24, OOTP 26, EHM BKmodern, URC logo navigateur, Sky Sport NZ First Light.

Non trouvé : aucune source exploitable sur l'habillage Canal+ du Top 14 ni sur l'URC au-delà du registre ; EA FC 26 et Eastside Hockey Manager non couverts par cette veille (registre seulement).
