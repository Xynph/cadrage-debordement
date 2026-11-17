# Jeunes du centre : note au poste = niveau (16/11/2026)

Piste 5 de `docs/passation-codex-consolidation-20261115.md` (« jeunes générés avec des qualités trop généreuses
pour leur niveau, pilier 64 → 82 au poste »).

## Constat (carrière Monde neuve, club 102, graine 4242)

`academyPlayer` (`dist/development.js`) tire un niveau (`rating` 52 à 66) puis `ensureSkills` donne à chaque qualité
`niveau + profil de la famille de poste ± 9`. Le profil relève les qualités du rôle : la note au poste (`roleNote`)
dépassait donc le niveau de **+12,1 en moyenne** sur les 60 jeunes du centre (minimum +5, maximum +19 ;
piliers gauches +16,3, demis d'ouverture +15,3, demis de mêlée +14,8). Les pros, recalés à la création (barème V2),
sont à +0,8.

Conséquences en jeu :

- un jeune de niveau 52 jouait comme un joueur de 66 au poste, souvent au-dessus de son propre potentiel général ;
- `native/engine/espoirs-match.cjs` (`calibrated`) devait recaler à la volée les seuls jeunes appelés en équipe
  première ; les autres (matchs des espoirs, fiches, choix du staff hors feuille) gardaient la note gonflée ;
- `academyPotential` convertit un plafond tiré **au poste** (64 à 94) en potentiel général
  `niveau + (plafond − note au poste)` : l'écart de +12 retirait autant au potentiel général.

## Correctif

`youthSkillsAtLevel(p)`, appelé dans `academyPlayer` juste après `ensureSkills` : décalage uniforme des qualités
(bornes 15-99, au plus trois passes) jusqu'à ce que la note au poste égale le niveau — le principe de `calibrated()`,
appliqué une fois à la naissance du joueur. Toutes les créations passent par là : centre du manager, centres des clubs
de l'ordinateur, centres invités, jeunes d'urgence, recrues d'espoirs extérieurs (copie d'un jeune créé).

Mesure après correctif (même carrière) : écart moyen **0,0** (minimum 0, maximum 0) sur les 60 jeunes.

Le plafond affiché au poste ne change pas (même tirage) ; le jeune part de son vrai niveau et garde toute sa marge de
progression (potentiel général = plafond au poste). Aucune modification des carrières déjà créées : leurs jeunes
gardent leurs qualités, et `calibrated()` continue de recaler ceux qui sont appelés.
