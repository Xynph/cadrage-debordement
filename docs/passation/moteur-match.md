# Moteur de match : passation du chantier réalisme (résumé)

Version résumée (26 et 27/11). Les PR fusionnées sont listées dans [etat-27-novembre.md](etat-27-novembre.md). Les restes sont dans [a-faire.md](a-faire.md).

## Méthode
Audits sur 150 à 500 matchs simulés (journal, phases), calage sur le réel par championnat, films de match de vérification, vérificateur GO. Une PR par lot, chiffres avant/après. Un lot ne doit jamais dégrader : favori, matchs serrés (Top 14 ≈ 40 %), points et essais par match.

## K2 niveau au poste (#1351, fusionnée)
Titulaire comparé à la norme de son poste dans le Monde ; seul l'excès au-delà d'une marge compte (niveau 5, mêlée 8, touche 7). Effet à −15 au poste (club 102, 400 matchs) : pilier 0 vers −2,6 point, talonneur −2,9 vers −4,6, 2e ligne −2,7 vers −3,4, 3e ligne −0,3 vers −1,5, ouvreur −0,2 vers −1,4, arrière −1,0 vers −1,6, ailier −0,6 vers −0,8, centre −0,3 vers −0,4. Référence 40,3 % vers 42,3 % de victoires (neutre à moins d'un point de marge). Piège : une fonction de même nom dans le module d'entraînement (`niveauForme`) a fait chuter le club de 40 à 31 % au premier essai. Doc : `docs/niveau-au-poste-20261126.md`.

## K3 remplaçants (#1350, en CI)
Fatigue = minutes jouées dans le match (plafond 1,6), effet d'un remplaçant frais sur jeu, mêlée, faute, main ; coût s'il est bien plus faible ; l'IA remplace au poste. Réglage final (`FRAICHEUR` dans `dist/matchflow.js`) : jeu 0,09, main 0,03, faute 0,08, mêlée 0,1, impact 0,6 sur 15 min. Un changement à la 50e : pilier 15 vers 25 %, 3e ligne 26 vers 40, demi 21 vers 32, ailier 19 vers 32 (60e : 12 vers 20, 17 vers 30, 15 vers 27, 12 vers 24). Calage Top 14 2 × 600 : serrés 38,5 vers 39,3, favori 63,7 vers 63,4, remontées 16,9 vers 20,9. Test `match-remplacants` (36,7 % pour 35, marge étroite). `match-consignes-direct` élargi de 24 à 192 matchs (accord du créateur, mêmes graines et assertions). `bonus-fin-de-match` : la mesure fait remplacer le club du joueur comme l'IA.

## Pièges rencontrés
- Base commune `dist/rugby-common-rosters.js` à régénérer après tout changement de `dist/` (`node scripts/build-rugby-common.cjs`).
- Fixtures de référence à régénérer : `tests/fixtures/match-gestes-sequence.json`, `tools/animation-replay/fixture.js`.
- `tests/ci-selection.cjs` à mettre à jour avec `ci/select-tests.cjs`.
- Tests à graine fixe au bord du seuil : élargir l'échantillon, même seuil.
- Tests sur entrées fabriquées qui ne prouvent rien : exiger de vrais plans et événements du moteur.
- `live.minute` compte les pas du chrono, pas les minutes de jeu.
- Merges successifs : vérifier `MERGE_HEAD` ; ne jamais committer une résolution avec marqueurs.
- Deux films de la même graine donnent des matchs différents : comparer le rythme, pas le résultat.
- Mesures : `scripts/mesure-essais-monde.cjs <graine> <club> --json f.json` ; saisons par `tests/helpers/carriere-reprise.cjs`.

## Décisions de réalisme déjà prises
Voir [regles-du-createur.md](regles-du-createur.md) section Match.

## Lacunes de ce résumé
Les scripts de mesure du chantier (sensibilité, calage, sondes) et les rapports d'audit (journal, phases, films) étaient hors dépôt et ne sont pas versés ici. Les refaire à partir des tests `tests/match-*.cjs` et des scripts `scripts/mesure-*.cjs`.
