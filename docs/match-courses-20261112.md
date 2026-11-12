# Découpage des longues courses du moteur — 12 novembre 2026

Suite de la PR 599 (temps forts déclenchés par l'importance, `docs/match-importance-20261112.md`).
Limite relevée : un essai en jeu courant était un seul fait du journal, de 20 à 50 m de la ligne
jusqu'à l'en-but ; l'importance, calculée au début de chaque fait, n'avait pas le temps de monter
et 62 % des essais (niveau dynamique) passaient par le filet de rattrapage. Léo : « oui go ».

Code : `dist/restarts.js` (`courseDecoupee`, `advanceCausalPlay`, `resolveInGoal`),
`dist/rugby.js` (`scoreTry`, paramètre `prelude`). Interrupteur : `MATCH_COURSES_DECOUPEES`
(vrai par défaut) ; `CD_MATCH_COURSES=0` le coupe dans le worker natif et dans les harnais de test
(`tests/harness.cjs`, `tests/france-harness.cjs`), option `matchCourses:false` du pont.
Tests : `tests/match-courses.cjs`.

## 1. Ce que faisait le moteur

`advanceCausalPlay` : une course réussie avance `territory` (`carryGain`, 3 à 25 m selon les
plans). Si elle arrive dans les 22 adverses et que le tirage de finition réussit, le moteur appelle
`scoreTry(l, side, 'open', origin)` sans écrire la course : le fait `try` part de l'origine de la
course. Même chose pour le ballon tenu dans l'en-but et l'en-avant dans l'en-but
(`resolveInGoal`) : aucune course écrite, fait en-but depuis le point atteint. Quand la même
course n'aboutit pas, le moteur écrit un fait `carry` origine → point atteint.

## 2. Le découpage (présentation seule)

La décision ne change pas : mêmes tirages, dans le même ordre, mêmes valeurs. Juste avant le fait
final (essai, ballon tenu, en-avant dans l'en-but), le journal écrit, à la même minute :

1. **La course** origine → point atteint, porteur `actionPlayer` (choix déterministe déjà utilisé
   par le moteur), avec les phrases du moteur pour une course : c'est exactement le fait écrit
   quand la course n'aboutit pas (omis si le gain est nul, ballon déjà à 1 m).
2. **0 à 2 temps de jeu de soutien** jusqu'à quelques mètres de la ligne : reste > 18 m → 2,
   > 9 m → 1, longueurs égales ; porteurs choisis sans tirage parmi les joueurs en jeu de l'équipe
   (ni le premier porteur, ni le marqueur, ni le porteur précédent) ; textes « Soutien de… »,
   « … prend le relais après le regroupement », « Passe pour… ».
3. **Le fait final** part du dernier point : l'essai du marqueur (≤ 9 m pour un essai long), ou le
   ballon tenu / échappé dans l'en-but.

`scoreTry` reçoit un `prelude(marqueur)` : il tire la transformation puis le marqueur (même ordre
qu'avant ; `goalChance` ne lit ni le score ni les compteurs), écrit les temps de jeu avec le
**score d'avant l'essai**, puis compte l'essai. Les faits ajoutés sont des `carry` ordinaires, sans
marque : rien ne les distingue d'une course qui n'aboutit pas, l'importance ne peut pas y lire
l'issue.

Preuve (test `tests/match-courses.cjs` et 40 matchs à la main) : avec et sans découpage, score,
essais, statistiques du moteur, statistiques tactiques (mètres, `longGains`), feuilles de match
(minutes) et tirage suivant identiques ; le journal découpé contient l'ancien journal dans l'ordre,
plus des `carry` placés seulement avant un essai ou un en-but ; chaîne continue vers la ligne ;
même marqueur, même point d'essai.

## 3. Consommateurs du journal

| Consommateur | Effet |
| --- | --- |
| Score, essais, stats du moteur (`l.stats`, `tacticalStats`), minutes jouées | inchangés (prouvé) |
| Chiffres tirés du journal (`match-direct` `chiffresRugby`) | 60 matchs : courses 19,1 → 26,0 ; mètres 316 → 404 (moteur : 383) ; franchissements 3,88 → 4,87, désormais égaux à `longGains` du moteur (4,87) : la course qui menait à l'essai était invisible |
| Notes des joueurs (`notesDuMatch`) | les porteurs des temps de jeu reçoivent leur course : moyenne 7,05 → 7,08, max 8,45 → 8,56 |
| Fil / commentaire, journal Godot, filtre « Progression » | 2 à 3 lignes de plus avant un essai long ; ~7 faits de plus par match (199 → 206, plafond de sauvegarde 1000) |
| Temps forts / importance | voir § 4 |
| Chorégraphe | lit déjà les `carry` de l'équipe avant l'essai (`remonter` → `porte` / `franchi`, puis `essai` du marqueur) : l'essai est mis en scène depuis la course, avec ses temps de jeu ; entrées figées des tests inchangées |
| Entracte 2D (`match_terrain_2d.gd`) | `carry` déjà gérés (regroupement) ; non modifié |
| Sauvegardes / exports | même format de fait ; hashes des carrières régénérés (§ 5) |

Ancien chemin non causal (`rugby.js`, sauvegardes d'avant les règles causales) : non modifié.

## 4. Mesure (200 matchs, `node tools/qa/match-importance-mesure.cjs 200`)

« Coupé » : `CD_MATCH_COURSES=0`. Lignes « après » (déclenchement par l'importance).

| Niveau | Essais par le filet | Temps forts / match (p10–p90) | Avec point | Essais montrés | Action s/match | Épisode max |
| --- | --- | --- | --- | --- | --- | --- |
| Dynamique, coupé | 62,3 % | 15,5 (11–20) | 38,3 % | 856/856 | 155,7 | 38 s |
| Dynamique, découpé | **14,3 %** | 15,5 (11–20) | 38,2 % | 856/856 | 172,4 | 39 s |
| Clés, coupé | 70,8 % | 13,6 (9–18) | 44,6 % | 856/856 | 134,1 | 38 s |
| Clés, découpé | **20,7 %** | 13,6 (9–18) | 44,5 % | 856/856 | 147,1 | 38 s |
| Étendus, coupé | 34,7 % | 21,5 (16–27) | 26,2 % | 856/856 | 205,2 | 41 s |
| Étendus, découpé | **1,8 %** | 21,5 (16–27) | 26,1 % | 856/856 | 222,9 | 42 s |

Écarts entre temps forts, consécutifs, quarts, entracte : identiques à 0,2 point près. Scores et
essais par match identiques (même décision). Seul seuil de test touché :
`tests/match-highlights.cjs`, deux temps forts quasi identiques d'affilée ≤ 10 % (au lieu de
8 %) : sur ses 16 matchs, 6,6 % → 8,7 %, parce que les essais qui montent par l'importance
(« franchissement », « contre-attaque ») ne sont plus des rattrapages forcés exclus du compte.
