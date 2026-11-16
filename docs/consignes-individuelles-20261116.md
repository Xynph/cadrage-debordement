# Consignes individuelles : tireurs et lanceur (16/11/2026)

Le manager désigne, avant le coup d'envoi, son **buteur** (pénalités et transformations), un **buteur de
secours**, son **lanceur en touche** et son **joueur au pied d'occupation**. Sans désignation, le staff
choisit le meilleur à chaque rôle ; les clubs de l'IA font de même. Écran : Composition → « Tireurs et
lanceur » (`native/godot/ui/immersive08/tactics_roles.gd`).

## Règles

- Stockage : `S.playerRoles` (`{buteur, secours, lanceur, pied}`, identifiants de joueurs du club ;
  absent = staff). Commande : `set_tactics` avec `roles` (`null` rend le rôle au staff), hors match.
- Coup d'envoi : copie dans `l.playerRoles` (seulement les joueurs de la feuille) pour les rencontres
  créées avec `l.playerRolesVersion === 1` ; un match commencé avant garde ses règles
  (`PLAYER_ROLES_RULES = 0` coupe l'option).
- Buteur d'une tentative : désigné s'il est en jeu, sinon buteur de secours, sinon choix du staff
  (`chooseScorer`, calcul d'origine).
- Choix du staff : meilleur « But » en jeu ; talonneur en jeu au lancer ; meilleur « Jeu au pied » parmi
  les arrières.
- Aucun tirage nouveau : sans désignation, les matchs sont identiques à ceux d'avant (vérifié par
  `tests/consignes-individuelles.cjs`, option coupée contre option active).

## Formules (coefficients de jeu, non mesurés)

- Tir au but : `goalChance` utilise l'attribut « But » du buteur retenu (0,006 par point, inchangé).
- Touche : `+ (Touche(lanceur) − Touche(talonneur en jeu)) × 0,004` ; un lanceur qui n'est pas
  talonneur ne gagne jamais rien et perd 0,05 de plus.
- Jeu au pied d'occupation : `+ (Pied(botteur) − Pied(choix du staff)) × 0,25` mètre.
- Alerte (Gabi, fenêtre) : buteur désigné du XV à 8 points ou plus sous le choix du staff.

## Mesures IA contre IA (300 affiches Monde par cas, graines appariées, conditions rétablies)

| Côté 0 | Pénalités | Transfos | Touches gagnées | Gain net au pied | Points |
| --- | --- | --- | --- | --- | --- |
| Staff (= avant) | 72,5 % | 73,3 % | 72,9 % | 5,7 m | 28,5 |
| Buteur le plus faible des arrières | 60,1 % | 61,5 % | 73,1 % | — | 27,5 |
| Deuxième ligne au lancer | — | — | 68,9 % | — | 28,2 |
| Ailier au lancer | — | — | 59,2 % | — | 26,8 |
| Botteur le plus faible des arrières | — | — | — | 3,5 m | 28,2 |

## Écarté

Consignes de style par joueur (« chercher le contact », « rester au large ») : le porteur est choisi par
rotation et le gain ne dépend pas de ses attributs (`restarts.js`, `matchflow.js`). Une consigne n'aurait
changé que le nom dans le commentaire, sans effet mesurable : non ajoutée.
