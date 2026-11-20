# UX Spec : 13 — Match en direct (habillage du match 3D)

> **Statut** : choix de Léo intégré (revue DA du 19/11/2026), en code sur `claude/da-match-direct-20261120`
> **Auteur** : ux-designer (CCGS), mode autonome, rigueur `minimal`
> **Dernière mise à jour** : 20/11/2026
> **Fiche détaillée** : `hud.md` (philosophie, inventaire, règle de nécessité, accessibilité) ; cette fiche ne garde que le choix de Léo et ses écarts.
> **Maquettes** : `direction-artistique/interface/revue-20261119/apercus/13-match-direct-1.png` (base), `-2.png` (bannière d'essai), `-3.png` (menu Échap) ; HTML `frag/13-match-direct.html`.
> **Code** : `native/godot/ui/contextual/live_view.gd` (bandeau, commandes, journal, menu, pages), `match_temps_forts.gd` (bannière des grands moments), `director.gd` (Échap). La bande Équipe / Réglages / Plus est remplie par `match_between.gd` (écran 14).

## 1. Choix de Léo

**Variante 1 · Bandeau d'angle** (avis DA). Emprunts DA : la **bannière d'essai** de la variante 2 ; le **menu du match ouvert par Échap** de la variante 3 (exception de Léo : petite fenêtre permise pour ce seul menu). Le score centré de la variante 3 est écarté (il gêne la mêlée et les poteaux).

## 2. Zones (1920 × 1080, marge 24 px)

| Zone | Contenu | Règle |
|---|---|---|
| Haut-gauche | Bandeau d'angle : horloge (32 px) et période (« 1re MT »), plaque du club recevant, score ivoire 40 px, plaque du visiteur ; bord droit incliné de 10° | Toujours visible, rien ne le recouvre (voile du menu compris) |
| Haut, à droite du bandeau | Bande des commandes (écran 14 : état du jeu, Équipe, Réglages, Plus), puis **Pause · Espace** | La même en 3D et à l'entracte |
| Sous la rangée | Météo à gauche (aux arrêts seulement) ; **Échap · Pause et menu** à droite (en 3D, hors action) | Le rappel est cliquable : il ouvre le menu |
| Bas-gauche | Journal : 2 faits, minute en italique, DM Sans 16 px sur panneau 85 %, 744 px | Le plus ancien en ivoire secondaire |
| Tiers inférieur, au-dessus du journal | Bannière d'événement (une à la fois) | Voir §4 |
| Centre | Rien de permanent | — |

## 3. Interactions (« tout ce qui a l'air cliquable ouvre quelque chose »)

| Élément | Action |
|---|---|
| Plaque d'un club (clic, Entrée) | Fiche du club (fiche commune `club_sheet_canvas.gd`) dans une page du direct ; match en pause ; « ← Retour au direct » le relance s'il jouait |
| Nom d'un de nos joueurs dans le journal | Survol : mini-fiche ; clic : fenêtre Équipe sur lui. Les adversaires restent du texte (pas de faux lien) |
| Pause · Espace | Pause / Reprendre |
| Échap · Pause et menu, ou Échap | Pause + menu du match |
| T | Fenêtre Équipe |
| Plus › Confier la fin à l'adjoint | Confirmation **dans le menu du match** (plus de fenêtre) |

## 4. Bannière d'événement (emprunt variante 2)

« ESSAI » à la couleur du club qui marque (assombrie pour l'ivoire ; un club jaune ou or prend le bordeaux de la charte), filet, marqueur, « Club · 52e minute », « +5 » et le score à droite ; même largeur que le journal. Mi-temps et fin : même bannière sur panneau. 600 ms d'animation en tout (300 entrée, 300 sortie), aucun flash ; animations réduites : posée d'emblée.

## 5. Menu du match (emprunt variante 3)

Échap met en pause (jamais le menu de carrière). Voile noir 70 % **sous** le bandeau (score et minute lisibles), panneau de 480 px : Reprendre le match (focus, Échap / Espace), Réglages (page du direct : l'écran Réglages, « ← Retour au menu du match »), Vitesse du match (◂ Posée / Normale / Rapide / Éclair ▸, flèches), Quitter le match (premier appui : avertit ; second : le jeu se ferme, la carrière reprend avant le match — décision du 16/11). Pied : ↑↓ Choisir · Entrée Valider · Échap Reprendre.

## 6. Écarts assumés

- La phrase « qui a le ballon » est dans la bande des commandes, à droite du score (comme l'entracte, maquette 14), pas sous le bandeau.
- Le bandeau garde les noms pendant l'action (variante 1) ; seules la météo et l'aide Échap se retirent.
- Pause garde le libellé seul (pas d'icône « ❚❚ »).
