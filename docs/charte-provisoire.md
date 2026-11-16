# Charte graphique provisoire (16/11/2026)

Référence fixée par Léo en attendant la charte de la graphiste. Deux éléments
seulement : la palette réduite à 5 couleurs et les maquettes de menus validées.

## Règle

- Aucune nouvelle couleur, police, taille de texte ou style de composant.
- Réutiliser les composants existants (`ui/game_skin.gd`, `ui/carnet_skin.gd`,
  `ui/immersive08/components.gd`).
- Tout élément visuel ajouté pour la graphiste (icône, illustration, espace
  réservé) est listé dans la description de la PR.
- Lot documentaire : cette charte ne modifie aucun rendu.

## Palette réduite à 5 couleurs

Décision de Léo : vert et doré en couleurs principales, fondus avec le fond.
**Non retrouvé : aucun fichier du dépôt ne définit ces 5 couleurs.** Le
reste est à confirmer par Léo ou la graphiste avant tout usage comme référence.

Valeurs réellement présentes dans `native/godot/ui/game_skin.gd` (l. 9-15),
habillage sombre qui s'en rapproche le plus :

| Rôle | Code | Constante |
| --- | --- | --- |
| Fond | `#151b1f` | `BG` (aussi `theme.gd`, `carnet_skin.gd`) |
| Doré | `#ddbd80` | `GOLD` |
| Vert | `#a6d2ae` | `GOOD` (`theme.gd` : `GREEN` `#a1d5ac`) |
| Texte | `#f5f4ec` | `INK` |
| Texte secondaire | `#bdc8c9` | `MUTED` |

Cette liste est indicative, non validée. Autres définitions divergentes (vérifiées) :
`carnet_skin.gd` (doré `#82592e`, vert `#38664b`), `immersive08/components.gd`
(fond `#0b1012`, doré `#d7ad59`, menthe `#82e3a3`), couleurs de résultat dans
`docs/native06-couleurs-20261108.md` (`ui/data_semantics.gd`).

## Maquettes validées (Bureau, Effectif, Composition)

Direction « affiner l'univers actuel plutôt que le remplacer » :
- PR #548 (fermée, non fusionnée, branche `claude/theme-unique-plan-20261111`,
  commit `8914e4d7`) : `docs/theme-unique-20261111.md` et six images
  `docs/theme-unique-20261111/` (`bureau-`, `effectif-`, `composition-proposition.jpg`).
  Absentes de `main` : à lire via la PR
  <https://github.com/Xynph/cadrage-debordement/pull/548>.
- Sur `main` : `docs/socle-menus-20261111.md` (écran Effectif, captures dans
  `docs/socle-menus-20261111/`) et `docs/native07-direction-menus.md`.
- Validation par Léo de la direction : rapportée en conversation, non vérifiable
  dans le dépôt. Maquettes « refaites » postérieures au 11/11 : non retrouvées.

## À recevoir de la graphiste

- Palette définitive (5 couleurs, codes) et sa déclinaison fond/texte/états.
- Polices et échelle de tailles (aujourd'hui Barlow Condensed et DM Sans).
- Style des composants (boutons, panneaux, pastilles, barres).
- Logo définitif (provisoire : PR #671) et icônes.
- Maquettes finales des autres écrans.
