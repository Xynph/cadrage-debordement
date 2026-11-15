# Passation vers Codex : consolidation du jeu (15/11/2026)

Session Claude « consolidation » (14-15/11). État de `main` au 15/11 9 h : `b0fe0988`, CI « Tests JavaScript » verte. Une autre session Claude (mode Monde, centre de formation, barème V2) a sa propre passation : `docs/passation-codex-20261115.md` (PR #736).

## Règles (en plus de AGENTS.md)
- Uniquement la carrière **Monde** dans les tests. Jamais de vrais noms ni de fichiers Mixamo dans ce dépôt public.
- Jamais de push sur `main`, jamais de force-push, jamais de `git stash` nu. Une branche par chantier, PR en français ; la description de PR est la passation (problème, cause, correction, tests, limites).
- Pas de mention `@nom` nue sur GitHub. Coordination sur l'issue **#591** : RÉSERVÉ / PRÊT / FUSIONNÉ.
- Demander à Léo avant tout ce qui est payant, destructif ou qui modifie la configuration GitHub.
- Léo veut **consolider** (agréable, beau, fluide, addictif) plutôt qu'ajouter des fonctionnalités. Être créatif et critique ; chaque critique doit devenir une correction.

## CI
- « Validation CI » exigée. Brouillon = CI légère (rouge attendu) ; batterie complète en PR prête : 7 shards JS + 3 shards Godot (bloquants si des fichiers Godot changent).
- Toute nouvelle suite longue doit avoir son budget dans `ci/run-shard-suites.sh` (180 s par défaut, sinon code 124) et son poids dans `ci/suite-weights.json`.
- Recette Windows du vrai EXE : étiquette `windows-receipt` (retirer/reposer pour relancer), verte depuis #723, borne de 20 s par réponse du moteur.
- `dist/rugby.js` modifié → `node scripts/build-rugby-common.cjs` puis `--check`. `node scripts/rename-brand.cjs` réécrit aussi les tests qui citent l'ancien nom : relire.
- Tests de match (#730) : règles sur beaucoup de matchs, statistiques sur des moyennes, scénarios avec tirages forcés (`tests/helpers/tirages.cjs`, `CD_RECALIBRAGE`, `CD_BUG`). Ne plus élargir des bornes ni chercher une graine qui « marche ».

## Livré par cette session (14-15/11)
Gabi bandeau + Bureau (#698, #706) · sauvegarde idempotente (#697) · suites Godot bloquantes (#704) · composition du staff (#693) · homme du match par maillot + adjoint en délégué (#707) · stats réalistes de la fiche joueur (#709) · vitesse des commandes, écriture différée (#711) · délégation : composition par le staff + alerte fatigue (#713) · fiche club + liens cliquables génériques (#715) · calendrier réparé + chiffres à une seule source (#718) · essais réalistes (#710) · nouvelle saison 12,8 → 8 s (#719) · « Continuer » jusqu'au prochain événement (#720) · retouches (#722) · recette Windows verte, import 16-19 → 11 s (#723) · conférence de presse rapide + « Envoyer mon adjoint » (#724) · dilemmes de ton (#727) · pénalités réalistes (#721) · mesure saison V2 + notes par maillot (#728) · appeler un espoir (#726) · finitions (#731) · mémoire des domaines du modèle (#729) · tests robustes (#730).

Documents : `docs/fluidite-commandes-20261114.md`, `docs/alleger-donnees-20261115.md`, `docs/essais-realistes-20261114.md`, `docs/hierarchie-penalites-20261114.md`, `docs/homme-du-match-postes-20261114.md`, `docs/stats-fiche-joueur-20261114.md`, `docs/tests-robustes-20261114.md`.

## Décisions de Léo
- Son propre club ouvre l'écran Club, jamais la fiche club.
- Délégation : « Confier aussi la composition au staff » cochée par défaut ; alerte de Gabi sous 70 % de condition.
- Feuille incomplète : appeler un espoir du centre (par défaut) ou jouer à 22.

## Chantiers ouverts, par priorité
1. **PR #714 (brouillon)** : conseil précis de Gabi le jour de match + stabilisation de `tests/native-club-support-ui.cjs` (informative dans `ci/run-godot-suites.sh`, échoue ~3 fois sur 4 : après la 1re réunion de soutien, « terminez le rendez-vous en attente » ou « Réponse du moteur local illisible »). Peut-être un vrai bug joueur. Objectif : cause réelle, 5 passages verts d'affilée, retirer de `informative_suites`.
2. **Agents libres** : le vivier grossit sans fin (27 → 858 → 1 714 en 3 saisons) et il est écrit deux fois (`S.market` = `economy.freeAgents`, ~3 Mo chacun en saison 3). Proposition à faire valider par Léo : départ à l'étranger ou retraite après 1 an sans contrat (jeunes et bons joueurs plus longtemps) ; n'écrire le vivier qu'une fois.
3. **Hiérarchie** : effectifs trop resserrés en Premiership, Championship, League One D2 (corrélation rang/effectif 0,15 à 0,32, parfois négative). Le moteur est correct : corriger l'écart de niveau dans le barème V2 (voir `docs/hierarchie-penalites-20261114.md` §7 et `docs/passation-codex-20261115.md`).
4. **Trop de points** en Premiership, Super Rugby, League One D1 (~65 points par match contre 56-58 réels).
5. **Centre de formation** : jeunes générés avec des qualités trop généreuses pour leur niveau (pilier 64 → 82 au poste) ; `calibrated()` de `native/engine/espoirs-match.cjs` ne recale que les jeunes appelés. Corriger le générateur.
6. **Fluidité** : étendre la mémoire de #729 à `nativeModel()` et aux équipes du staff ; ne revalider que les sections modifiées ; import ~11 s pour 20 Mo.
7. **Salle de presse 3D** : chaises vides, ajouter 2-3 journalistes et micros. « Honnête » reste le meilleur ton moyen sur les questions légères ; pas de vraie amende pour le ton agressif.
8. **Fiches légères** compétition, sélection nationale, entraîneur, sur le lien cliquable générique de #715.
9. **« Continuer »** : en saison, la conférence du lundi arrête l'avance si l'adjoint n'est pas réglé ; le rendez-vous annoncé n'est que celui déjà en file.
10. **Vérifier** que Gabi apparaît bien dans le bandeau du haut (absent de certaines captures de test).

## Décisions encore ouvertes (à demander à Léo)
- Agents libres (point 2).
- « Jouer à 22 » réservé à la Nationale (règle FFR actuelle) ou autorisé partout ?
