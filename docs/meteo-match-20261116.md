# La météo pèse sur le match (16/11/2026)

## Existant

La météo était déjà tirée à la création de la rencontre (`createRugbyMatch`, `dist/rugby.js` :
Sec, Sec, Pluie, Vent), annoncée au coup d'envoi, enregistrée dans le rapport, et utilisée par
des forfaits : au but −16 points par vent et −6 sous la pluie, jeu au pied −9 m par vent,
ballon perdu au plaquage 0,55 sous la pluie (0,30 au sec), en-avant +0,04 pour le jeu au large
sous la pluie, choix tactique de l'IA (`dist/opposition.js`). Elle n'est montrée au manager
qu'au coup d'envoi : la feuille de match l'annonce « révélée au coup d'envoi ». Aucun écran
d'avant-match ne la montre, donc le conseil du staff s'affiche pendant la rencontre (aide des
consignes, `rugbyMatchView`) et le coup d'envoi précise l'intensité.

## Changements (rencontres avec `weatherVersion: 1`)

- `l.meteo = {pluie 0-2, vent 0-2, chaleur 0-1, terrain 'souple'|'lourd'}`, déduit sans aléa
  de l'étiquette (tirage inchangé), de l'affiche et de la date (`tirerMeteo`, `dist/matchflow.js`).
  Forte pluie = terrain lourd. Chaleur : un match sec sur six.
- Réglages : `METEO_MATCH` (`dist/matchflow.js`), interrupteur `WEATHER_RULES`. Mêmes règles
  pour le club du manager et les clubs IA.
- Les rencontres commencées avant (sans `weatherVersion`) gardent les forfaits d'origine.
  La sauvegarde valide la version et les intensités (`validateFlowState`, `dist/saves.js`).

| Effet | Valeur par niveau |
| --- | --- |
| Réussite au but | −3 points (pluie), −5,5 points (vent) |
| En-avant dans le jeu courant | +2,2 points de probabilité (pluie) |
| Ballon perdu au plaquage finissant en en-avant | 0,30 + 0,07 (pluie) |
| Jeu au pied d'occupation | ×(1 + 0,25) (pluie) |
| Longueur du jeu au pied | −4 m en moyenne, ±4 m de dispersion (vent) |
| Finition ballon porté / mêlée près de la ligne | +4 points (pluie) |
| Mètres par avancée, terrain lourd | ×0,85 |
| Fatigue par minute, forte chaleur | ×1,12 |

## Mesures (`tests/meteo-match.cjs`, 160 matchs IA contre IA par condition, mêmes affiches et graines)

| Par match | Sec | Pluie forte | Grand vent | Chaleur | Pluie (avant) | Vent (avant) |
| --- | --- | --- | --- | --- | --- | --- |
| En-avant | 16,3 | 21,0 | 16,7 | 16,4 | 19,8 | 16,4 |
| Réussite au but | 76,3 % | 72,8 % | 68,4 % | 75,3 % | 72,7 % | 65,2 % |
| Essais | 6,68 | 5,69 | 6,83 | 6,74 | 5,81 | 6,84 |
| Essais sur ballon porté ou mêlée | 0,91 | 1,48 | 0,86 | 0,96 | 1,06 | 0,92 |
| Mêlées | 9,7 | 12,5 | 9,8 | 9,7 | 11,5 | 9,6 |
| Jeux au pied d'occupation | 3,9 | 8,1 | 2,6 | 3,8 | 6,4 | 2,6 |
| Mètres par avancée | 15,3 | 12,9 | 15,4 | 15,2 | 14,7 | 15,4 |
| Condition en fin de match | 73,8 | 74,3 | 73,7 | 71,7 | 74,4 | 73,7 |

## Repères

Ordres de grandeur retenus (choix de simulation, pas une loi du jeu : voir
`docs/rugby-rules-reference.md`, ligne « attributs, météo, fatigue et tactiques ») : sous la
pluie, en élite, plus d'erreurs de main et de mêlées, plus de jeu au pied, environ un essai de
moins et une réussite au but en légère baisse ; le vent pèse surtout sur les tirs au but longs.
Ce sont des estimations d'analyste, sans jeu de données Top 14 importé : à recaler si une
source chiffrée est retenue (registre `docs/ressources-utiles.md`).

## Vent par période (17/11/2026, rencontres avec `windVersion: 1`)

- `l.meteo.sens` (0 ou 1) : camp qui a le vent dans le dos en première période, tiré de la même empreinte que la météo
  (aucun tirage ajouté). Les équipes changent de côté à la mi-temps : le vent change de camp (`ventPour`, `dist/matchflow.js`).
- Jeu au pied : −10 m par niveau de vent de face, +2 m de vent de dos (moyenne des deux camps = −4 m d'origine) ;
  dispersion inchangée. Tir au but : −9 points par niveau de vent de face, −2 de vent de dos (moyenne −5,5 d'origine).
  Réglages : `METEO_MATCH.piedVentSens`, `METEO_MATCH.butVentSens` ; interrupteur `WIND_DIRECTION_RULES`.
- Le conseil du staff nomme le camp favorisé et annonce le changement à la mi-temps (`meteoConseil`).
- Les rencontres commencées sans `windVersion` gardent la moyenne d'origine ; la sauvegarde valide `sens` et `windVersion`.
- Test : `tests/meteo-vent-periodes.cjs`.

## Météo connue la veille (17/11/2026, carrière Monde)

- La veille du match du club (calendrier journalier), le ciel, l'intensité et le sens du vent sont fixés et gardés dans
  la sauvegarde (`worldMode.meteo` : rencontre, date, `weather`, `pluie`, `vent`, `chaleur`, `terrain`, `sens`) par
  `fixerMeteo` (`native/engine/world-career.cjs`), appelé à chaque jour suivant et après chaque commande du worker
  (fin d'avant-saison, reprise, chargement). Jamais pendant un match ; effacée à la clôture de la semaine du match.
- Tirage sans aléa (`meteoPrevue`) : empreinte de la carrière (graine de variation) et de la rencontre ; même loi que le
  coup d'envoi (Sec 1/2, Pluie 1/4, Vent 1/4, intensités `METEO_MATCH.tirage`). Aucun `Math.random` consommé.
- Coup d'envoi : `createRugbyMatch` reprend l'annonce telle quelle (`meteoAnnonceePour`, `dist/matchflow.js`) avant la
  composition des feuilles IA (qui lisent le ciel) ; le tirage `rand(0,3)` du ciel reste fait pour ne pas décaler les
  suivants. Les rencontres non annoncées (cadence hebdomadaire, autres modes) gardent le tirage du coup d'envoi.
- Modèle natif : `next.meteo` (même format que `live.meteo`, plus `date`), présent dès la veille.
- Interface : écran Match « AVANT-MATCH » (bloc « La météo de demain / du match » : ciel, camp qui a le vent dans le dos
  en 1re période, conseil du staff ; sinon « Bulletin météo la veille du match ») ; courrier « Bulletin météo » du staff,
  une fois par match, qui arrête « Continuer » et ouvre la composition. Le mail de la pelouse suit la météo annoncée
  (glissante sous la pluie, lourde sous forte pluie).
- Tests : `tests/meteo-veille.cjs` (moteur et modèle), `tests/godot-meteo-vent.*` (écran Match dans le vrai Godot).
