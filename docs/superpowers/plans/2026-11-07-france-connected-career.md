# Plan carrière France — trente clubs et deux divisions reliées

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development for this cohesive engine subproject, with one implementer owning the coupled competition/state/save files and a fresh review before integration. The parent implements the independent art direction natively.

**Goal:** trente départs jouables, deux titres et une accession réelle entre divisions, sans modifier une carrière historique ou la BDD Rugby Réel.

**Architecture:** `S.clubs` contient trente propriétaires stables. `S.franceMode` version1 porte deux partitions14/16 et leurs calendriers ;34étapes communes et433résultats par saison, tous issus du moteur. Les champs natifs sont des projections validées. Branches France explicites, aucun changement global de14en30.

**Tech Stack:** JavaScript natif, APIs existantes de rugby/management, node:test, navigateur Chromium de la vraie page.

**Spec:** `docs/superpowers/specs/2026-11-07-clubs-territoires-design.md` ; audit préalable hors dépôt `CD/golden-engine-architecture.md`.

## Contraintes globales

`fiction` historique14 et `lnr`14 restent inchangés à graine/horloge identiques. Aucune écriture `dist/lnr-*`, notes V12, BDD, calendrier réel, modding ou données de l'autre producteur. Catalogue propre `CDFranceClubs` fourni par le parent, IDs0–29 stables et slugs de correspondance. Pas de réindexation lors d'accession/mobilité. Lois de match conservées sur le profil documenté ; format des compétitions2026/27 vérifié dans le Livre2 LNR du1juillet2026. La cadence34étapes et l'absence de Nationale sont des abstractions déclarées.

## Points de revue

Un nul de championnat reste un nul même quand l'autre division joue une finale. Clubs14–29 ne se confondent jamais avec les invités Espoirs. JSON perd les alias de référence : projections persistées strictement vérifiées. Stockage refusé pendant journée/intersaison : aucune transaction partielle installée. Les nœuds/taille d'une carrière de dix saisons restent dans des plafonds finis et contrôlés.

## Contrat de données et interfaces

`CDFranceClubs.clubs` fournit `id,slug,division,city,name,abbr,color,stadium,base,cashMillions,goal,cityImage,stadiumImage`, immuables. `division` vaut `elite` ou `accession` au départ ; la partition de carrière évolue séparément. Les valeurs financières/de niveau sont fictives.

`S.franceMode={version:1,catalogue:'france-territories-2026-10-31-v1',competitionRules:'fr-pro-2026-27',matchRules:'fr-pro-2025',startSeason:2026,week,leagues:{elite,accession},accessMatch,movement,yearbook}`. Chaque ligue porte membres, calendrier, journée, phase, tableau final, champion et finaliste. Les résultats portent `fixtureId,season,week,leagueId,round,phase,neutral` et, si nécessaire, `winner,decision`; tirs au but distincts du score de rugby.

`CDFranceCompetition` expose `active(s)`, `leagueId(s,clubId=s.club)`, `members(s,id)`, `regularRounds(s,id)`, `ranked(s,id)`, `currentFixtures(s)`, `userFixture(s)`, `project(s)`, `record(s,result,context)`, `closeWeek(s)`, `planMovement(s)`, `beginSeason(s)`, `validate(s)`. Les fonctions pures ne mutent pas à la lecture ; celles de transaction sont nommées comme telles.

`CDFranceCareer` raccorde démarrage, semaine, intersaison, contexte de rencontre, mobilité et projections. `CDFranceSaveValidation` ajoute les invariants de France au profil strict existant. Aucun module nouveau ne consomme RNG/horloge ni ne normalise S à son chargement.

La phase de carrière suit les34étapes :30régulières (D1 a quatre repos collectifs, cadence fictive), barrages, demies, finales, accession, puis ended. Le moteur conserve le contexte réel de chaque rencontre jusqu'à sa fin et après import. D1 demies et deux finales neutres, D2 demies à domicile, accession chez le finaliste D2. Les six qualifiés suivent le règlement vérifié ; le départage de championnat et celui éliminatoire sont documentés et testés, sans pénalité gagnante aléatoire remplaçant la procédure.

### Tâche unique : noyau de carrière connecté, livré comme un ensemble cohérent

**Propriété exclusive du producteur moteur :** nouveaux `dist/france-competition.js`, `dist/france-career.js`, `dist/france-save-validation.js`, `dist/france-knockout.js` si nécessaire ; `dist/game.js`, `dist/rugby.js`, `dist/matchflow.js`, `dist/opposition.js`, `dist/saves.js`, `dist/manager.js`, `dist/economy.js`, `dist/career-integration.js`, `dist/world-career.js`, `dist/manager-mobility.js`, `dist/ai-roster-cycle.js`, `dist/match-preparation.js`, `dist/office-career-press.js`, `dist/interclub-world-v124-v130.js`, `dist/index.html`, `dist/main-menu-v3.js`, `dist/main-menu-slots.js`, `dist/art-direction-v4.js`, `dist/premium-editorial.js`, `dist/premium-squad.js` ; gardes dans les onze modules Espoirs V73–V104 relevés par l'audit. Ne toucher ces fichiers que si nécessaire et derrière branche France ; ne modifier aucun algorithme de notes/vieillissement.

**Parent DA :** catalogue `dist/france-clubs.js`, atlas/manifestes, nouveaux `dist/art-director.js/.css` et ses tests, notices Windows. Le producteur moteur est seul écrivain de `index.html` et `game.js` dans son espace isolé ; le parent raccorde les deux scripts DA après intégration. Pas de double édition de ces fichiers.

**Tests nouveaux :** `tests/france-competition.cjs`, `tests/france-saves.cjs`, `tests/france-career.cjs`, `tests/france-browser.mjs`, `tests/france-harness.cjs` si nécessaire. Les fixtures du vrai navigateur chargent tous les scripts dans leur ordre livré, pas seulement le harness historique.

- [ ] RED calendriers et classement :14/26/182 et16/30/240, aller/retour unique, repos, égalités2/3clubs avec sous-groupes.
- [ ] RED phases/match :433rencontres natives après34étapes ; lieux corrects ; nul de championnat conservé dans un contexte croisé ; prolongation et décision éliminatoire séparée et restaurable.
- [ ] RED carrière/sauvegardes :30départs dont29, feuilles23,29académiesIA, export/import, partition14/16, promotion directe et deux issues du barrage sans perte d'ID/contrat/joueur/trésorerie, mobilité dans les deux sens.
- [ ] RED import hostile avec checksum recalculé : partitions, calendrier/résultats doublons, mélange France/LNR, projections fausses, champion sans finale ; état/disque inchangés. Stockage refusé et transition interrompue vérifiés.
- [ ] Implémenter les modules/branches minimales, générer les matchs via le moteur natif, conserver les vrais résultats et joueurs. Garder explicites les dimensions par mode et une seule application des effets hebdomadaires.
- [ ] Router la chaîne Espoirs V73–V104 incompatible hors France AVANT toute clôture/ensure/panel ; les wrappers `advanceSeason` passent vers leur fonction précédente. Formation native complète pour30, anciens modes inchangés. Staff/médical/vestiaire/médias/supporters/match3D restent exécutés. Pas de remplacement tardif du renderer.
- [ ] Régressions historiques : export/match/intersaison avec graine/horloge fixes identiques ; suites saves, mobilité, transactions, LNR ; chargement de tous les scripts et navigation des clubs14/23/24/29.
- [ ] Exécuter au moins huit à dix saisons natives, mesurer taille/nœuds, valider chaque intersaison et sauvegarde ; si plafond insuffisant, plafond France fini explicite, historique inchangé.
- [ ] Revue indépendante du sous-projet, corrections vérifiées, commit local et rapport précis à l'intégrateur ; aucun pushmain, gate ou mutation des autres producteurs.

## Références

[LNR Livre2 sportif2026/27](https://assets.lnr.fr/3/0/4/6/9/8/LIVRE-2_Sportif-et-Comp%C3%A9titions_2627_V2_703069b00e686885076f1b627c8c5441.pdf), articles2005–2013,2034,2085 ; `docs/rugby-rules-reference.md`. Les dispositions sportives non simulées, notamment Nationale/administratif, sont distinguées des abstractions et des lois de match déjà présentes.
