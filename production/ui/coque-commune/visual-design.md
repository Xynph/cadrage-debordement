# Traitement visuel : Coque commune (art-director, Phase 2 de /team-ui)
> Date : 2026-11-19 · Source UX : `design/ux/coque-commune.md` · Maquette : `direction-artistique/interface/revue-20261119/frag/coque-retouchee-v2.html`
> Règle de lecture : colonne « 1920 » = pixels de la maquette ; colonne « Réf. 2560 » = ×4/3, valeurs que le jeu place (coque en pixels 2560). Plancher : aucun texte sous 12 px réels (taille = max(12, réf. × fenêtre/2560 × échelle)).

## 1. Jetons (tous de `design/art/art-bible.md` §4.2)
| Usage dans la coque | Jeton | Hex |
|---|---|---|
| Fond de coque | `fond` | `#0E0D0B` |
| Rail, barre haute | `panneau` | `#171512` |
| Survol, touche dans champ | `panneau-2` | `#201D19` |
| Entrée active, champ de recherche, touche | `panneau-3` | `#2B2721` |
| Filets 1 px | `filet` | `#3D372E` |
| Texte principal, filet actif, badge (fond) | `ivoire` | `#F6EEDC` |
| Texte secondaire, étiquettes | `ivoire-2` | `#BDB4A2` |
| Désactivé, séparateurs « / », contours Menu et Recherche | `ivoire-3` | `#8C8474` (jamais sur `panneau-3`) |
| Continuer (seul aplat or) | `or` / survol `or-vif` | `#E9C062` / `#F1C970` |
| Texte du badge et de Continuer | `nuit` | `#000000` |
| Liseré d'en-tête, écusson | `club-trait`, `club` | dérivés du club (défaut `#B5524A`, `#71322F`) |
| « ✓ Sauvegardé » | `v` | `#6CC48A` (daltonien : `#5AA9E6`) |
| « ! Échec » | `d` | `#EE6F5F` |
- Couleurs ajoutées par rapport à la coque actuelle : `club` (plaque), `club-trait` (liseré), `v` (✓). Supprimées : vert-gris de `components.gd`, `CLUB_CHROME #11191E`, Continuer à la couleur du club.
- Contrastes : voir fiche UX §12 (tous ≥ 4,5:1 texte, ≥ 3:1 contours). Couleur jamais seule : ✓ + mot, « ! » + mot, badge = chiffre.

## 2. Polices
| Rôle | Police (fichier) | Graisse |
|---|---|---|
| Nom du club, libellé Continuer, journée « J9 », initiales de repli | Barlow Condensed (`ui/immersive08/fonts/BarlowCondensed-ExtraBoldItalic.ttf`) | ExtraBold Italic, capitales |
| Journée « J9 » | BarlowCondensed-BoldItalic.ttf | Bold Italic |
| Étiquettes de touches | Barlow Condensed SemiBold droit (`native/godot/fonts/BarlowCondensed-SemiBold.ttf`) | SemiBold |
| Entrées, fil, date, recherche, « division · rang », ligne Sauvegardé | DM Sans (`native/godot/fonts/DMSans.ttf`) | Regular ; Medium pour l'entrée active, le dernier morceau du fil, Menu |
- Vraie italique uniquement (pente ~10-12°) ; cisaillement interdit. Chiffres `tnum` pour date, badge, journée. Pas de troisième famille.

## 3. Tailles (rail, barre, contenu)
| Élément | 1920 | Réf. 2560 |
|---|---|---|
| Rail (largeur) | 232 | 309 |
| En-tête de club (hauteur) | 88 | 117 |
| Écusson | 40×50 | 53×67 |
| Nom du club | BC ExtraBold Italic 20/22, interlettrage +1 % | 27/29 |
| « division · rang » | DM Sans 12/16 `ivoire-2` | 16/21 |
| Liseré d'en-tête | 3 px, incliné 10°, bas à 10 px | 4 px, bas à 13 |
| Entrée de section (ligne × police) | 62 × DM Sans 18/24 | 83 × 24/32 |
| Entrées Presse, Sélections, pied (ligne × police) | 54 × 18/24 | 72 × 24/32 |
| Retrait gauche du texte / du pictogramme | 22 / 22 (texte à 54 avec pictogramme) | 29 / 29 (72) |
| Filet actif | 3 px, incliné 10°, à 8 px du bord, hauteur ligne − 22 | 4 px, 11 px, ligne − 30 |
| Séparateur de groupes | 1 px `filet`, marges 20 / 8 | 27 / 11 |
| Badge non lus | min 28×24, DM Sans Bold 16, coins coupés 4 px | 37×32, 21, 5 px |
| Touche « Ctrl S » (dans le rail) | h 20, DM Sans SemiBold 12, rayon 2 | h 27, 16, 3 |
| Ligne « ✓ Sauvegardé » | DM Sans 14/18, retrait 42 | 19/24, 56 |
| Barre haute (hauteur) | 48 | 64 |
| Bouton Menu | h 32, DM Sans Medium 13, burger 16, contour 1 px `ivoire-3`, rayon 2 | h 43, 17, 21, 1 px |
| Précédent, Suivant | 36×36, contour 1 px `ivoire-3`, flèche trait 1,5 px | 48×48, trait 2 px |
| Fil d'Ariane | DM Sans 13/18, séparateur « / » `ivoire-3`, écart 8 | 17/24, 11 |
| Recherche | 300×32, rayon 2, fond `panneau-3`, contour 1 px `ivoire-3`, loupe 16 | 400×43, loupe 21 |
| Date + journée | DM Sans Medium 13 + BC Bold Italic 15 | 17 + 20 |
| Médaillon de Gabi | 54×36 (portrait 48×32 en ovale) + touche « F1 » | 72×48 (64×43) |
| Continuer | 292×36, bord droit incliné 10° (7 px), libellé BC ExtraBold Italic 18/20 caps, « Espace » 12/16 après filet noir 35 % | 389×48, 9 px, 24/27, 16/21 |
| Gouttières de barre | 16 à gauche, 20 entre éléments, 8 à droite | 21, 27, 11 |
| Contenu | marges 24, utile 1640×984, grille 12 col, gouttière 16 | 32, 2187×1312, 21 |
- Entrées longues : jamais de « … » ; réduction jusqu'à 12 px réels puis infobulle. Lignes de rail compressibles 62 → 44 px (83 → 59 réf.) avant défilement du groupe central.

## 4. États (aucun nouveau cadre ; rayons 0, 2 px pour le champ)
| État | Rail (entrée) | Barre (boutons, liens) | Continuer |
|---|---|---|---|
| Repos | texte `ivoire`, pictogramme `ivoire-2` | contour `ivoire-3` (Menu, Recherche, flèches), texte `ivoire` | `or`, texte `nuit` |
| Survol | fond `panneau-2` | fond `panneau-2` ; liens du fil soulignés (filet 1 px) | `or-vif` |
| Pressé | fond `panneau-3` | fond `panneau-3` | `or-vif`, texte décalé de 1 px |
| Actif | `panneau-3` + filet `ivoire` incliné ; texte Medium | dernier morceau du fil `ivoire` Medium | — |
| Focus clavier | contour `ivoire` 2 px décalé 2 px, coins nets | idem | idem, le décalage laisse l'or visible |
| Désactivé | `ivoire-3` + forme (flèche barrée) | Précédent / Suivant seulement | — |
| Bloqué | — | — | `or` conservé, « ! » + raison à la place d'« Espace » |
| En cours | — | — | ovale tracé `or-vif` qui se remplit, libellé inchangé |
- En-tête : survol `panneau-2` ; fiche du club affichée : `panneau-3`. Badge : `ivoire` plein, texte `nuit` (18,18:1), sans survol propre (suit la ligne). Aucune ombre, aucun dégradé, aucun verre.
- Plaque d'identité : écusson de la banque (recolorable, masque) sur fond transparent ; repli = plaque `club` + initiales `ivoire`.

## 5. Mouvement (voir fiche UX §10 ; mouvement réduit = fondu 100 ms, rien ne glisse)
- Page : contenu seul, glissement 12 px (16 réf.) le long de l'axe incliné + fondu, 160 ms ease-out, cascade 30 ms (6 blocs max).
- Filet actif : glisse 100 ms. Menu pause : voile `nuit` 70 % + fondu 100 ms. Continuer : ovale qui se remplit. Ligne « Sauvegardé » : texte remplacé, sans animation.
- Jamais : rebond, élastique, parallaxe, clignotement > 3/s.

## 6. Liste d'assets
| Asset | Statut | Détail |
|---|---|---|
| Polices Barlow Condensed italiques (SemiBold, Bold, ExtraBold) | Présentes | `native/godot/ui/immersive08/fonts/` (à importer dans le thème ; vérifier le dossier `fonts/` partagé pour SemiBold droit) |
| DM Sans, Barlow Condensed SemiBold droit | Présentes | `native/godot/fonts/` |
| Écusson de club | Existant | Banque recolorable `native/godot/art/banque/recolorables/ecusson-*.webp` + masque ; repli initiales. Écusson réel du Pack : hors dépôt, lu à l'exécution |
| Pictogrammes Carrière, Réglages, Sauvegarder | **À créer** | trait 1,5 px, grille 20 px (27 réf.), extrémités coupées à 10°, `ivoire-2` / `ivoire` actif ; remplacent les glyphes ↺ ⚙ ↓ de la maquette (pas de caractère de police) |
| Pictogramme loupe, burger, flèches ← → | **À créer** | même règle ; burger = 3 traits à extrémités coupées |
| Coche ✓ et point d'exclamation « ! » | **À créer** | formes dessinées à extrémités coupées (la maquette utilise des caractères) |
| Médaillon de Gabi | Existant | `native/godot/guide/gabi_medaillon.gd` + masque ovale ; revoir cadrage 72×48 |
| Ovale tracé de Continuer | À vérifier | progression existante (`continue_progress`), couleur `or-vif` |
| Forme du badge, du filet, du bord de Continuer | Code | polygones à 10° (décalage = hauteur × 0,176) |
| Photo de forêt du pied de rail | **À supprimer** | remplacée par la ligne « Sauvegardé » |
| Palette verte-gris de `components.gd`, `CLUB_CHROME` | **À retirer** de la coque | remplacés par les jetons ci-dessus |

## 7. Écarts et vérifications pour l'art
- Écart charte §3C « aucun cadre complet » : contour 1 px `ivoire-3` sur Menu, Précédent/Suivant, Recherche (maquette validée, cibles lisibles comme boutons). À inscrire dans l'art bible.
- Écart charte §7.1 : entrées de rail 18/24 (au lieu de 13/18) et sans numéro ; lignes 62 / 54 px (49 px et 248 réf. dans le code actuel).
- Écart charte §4.2 : `v` (vert) utilisé pour « Sauvegardé », au-delà de « victoire, apte » ; décision de Léo.
- Écart code : rail 248 réf. → 309 réf. ; barre 48 px de maquette = 64 réf. ; Continuer en `or` et non à la couleur du club.
- À vérifier à l'intégration : `tnum` dans DMSans.ttf (art bible §7.1) ; lisibilité du liseré de club jaune ou blanc (règle de dérivation §4.2) ; capture à 1280×720 / 130 % ; capture d'un club à nom long (28 caractères).
