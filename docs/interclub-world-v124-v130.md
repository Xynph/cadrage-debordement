# V124–V130 — Monde vivant interclubs : audit, implémentation et réception

## Audit de l'état de référence

Base `main` : `bd89594a1f4303ba869fca0e82233c66c5bf7600`.

**Systèmes réutilisés :**
- `dist/world-career.js` : résultats réels de la simulation via `worldRecordResult`, réputation, infrastructures, pression et rotations abstraites des entraîneurs, palmarès. L'historique `worldManagement.matches` est borné aux 180 rencontres les plus récentes, donc insuffisant pour toutes les rivalités d'une carrière longue.
- `dist/rugby-world.js` : fonction pure de face-à-face, utilisable pour les rencontres conservées ; aucune mémoire pérenne de rivalité.
- `dist/game.js` : `record(r)` consigne réellement tous les matchs simulés, `advanceSeason()` change d'année ; `createSaveDocument/parseSaveDocument` protègent les sauvegardes.
- `dist/v101-v116-ui-bridge.js` et `dist/living-locker-room-v117-v123.js` : panneaux PC dans l'onglet scrollable `Bureau > Dossiers du club`.

**Manque réel :** des histoires qui durent, des liens de rivalité à partir des résultats réellement simulés, des réactions de banc adverses et une archive de saison. Ne pas créer de faux résultats, faux contrats d'entraîneur ni données prétendument réelles.

## Apports V124–V130

- **V124 :** registre interclubs facultatif, créé à la première rencontre enregistrée ; conservation des confrontations par paires d'identifiants de club, indépendamment de l'ordre du tableau.
- **V125 :** intensité dynamique sur 0–100 selon rencontres serrées, retournements et rivalité de longue durée ; cumuls de victoires/nuls non perdus lorsque l'ancienne liste de résultats est tronquée.
- **V126 :** événements contextuels de championnat (surprise sportive, rivalité, large écart, match nul, autre résultat), produits à partir du score et des forces existantes.
- **V127 :** réactions fictives des bancs adverses avec personnalités de communication stables et pression évolutive ; aucune attribution à une personne réelle, aucun effet sur l'issue du match.
- **V128 :** persistance intersaisons, synthèses de carrière, pression amortie à la trêve ; 20 bilans de saison au maximum, 140 événements récents, paires persistantes.
- **V129 :** panneaux lisibles dans `Bureau > Dossiers du club` et `Championnat` sans bloc ajouté à la mise en page fixe.
- **V130 :** compatibilité anciennes carrières (pas de mutation à l'affichage), validation native des sauvegardes export/import, tests 15 saisons, test Chromium dédié.

## Garde-fous et limites

Pas de modification des données LNR, clubs, calendrier, moteur, simulation, MATCH 3D, économie, R&D, règles de transfert ni sauvegardes centrales. Le module observe seulement les résultats de `record` puis met à jour sa propre mémoire narrative optionnelle `S.interclubWorld`; l'intersaison enregistre un bilan. Il ne crée pas d'entraîneurs nommés, d'offres ou de résultats fictifs : les réactions sont explicitement simulées.

La pression interclubs relève du récit managérial, pas d'une nouvelle règle de licenciement IA : les mécanismes existants de `world-career` demeurent seuls maîtres des départs de techniciens. Les 15 saisons du test dédié évaluent les archives et les exports aux intersaisons, pas 15 calendriers joués match par match. Les noms des clubs ne sont jamais utilisés comme identifiants.

## Vérifications

- `node --check dist/interclub-world-v124-v130.js`
- `node tests/interclub-world-v124-v130.cjs` : résultats, idempotence, surprises, tension, réactions, 15 saisons, ancienne sauvegarde, import/export natif via harness.
- `node tests/saves.cjs` et `node tests/world-career.cjs` : non-régressions.
- `python tests/interclub-world-v124-v130-chromium.py` : vraie journée simulée, Bureau PC, championnat, export/import et ancienne carrière.
- CI `Tests JavaScript` complète : classification + 5 shards + Validation CI = 7 jobs et les workflows Chromium existants.

Aucune réception ne doit être présentée comme réussie tant que son run terminal n'est pas consulté. PR créée DRAFT et passation #73, sans gate ni fusion.
