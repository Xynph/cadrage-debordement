# Préparation publique du replay Analyse/Club/Bureau

La variante graphique fraîche sur bd6 a atteint le plafond enfant de 150 s, dernière trace `advance_day 2026-08-30`, sans capture ni rapport UI. Son reçu rouge demeure dans `/workspace/work/night-phase10/analysis-club-office-public` ; ce changement ne le requalifie pas.

Le wrapper prépare désormais la carrière jetable CI via `tests/helpers/analysis-club-public-prepare.cjs`, puis ouvre exactement son profil complet dans le vrai client Godot. Ce nouveau cas CI utilise le mode `common`, club 0 (30 clubs), avec vrais identifiants de rencontre et calendrier quotidien. Il ne prétend pas reproduire les stratégies ou résultats de WorldChamp29. Options identiques au worker CLI : calendrier quotidien, presse obligatoire, carrière internationale et éventuelle `CD_GODOT_SEED` validée selon le même domaine. Aucun changement de moteur, timeout VM, transport graphique ou état sportif fabriqué.

La séquence reproduit l’ancien setup GDScript : nouvelle carrière, rendez-vous projetés publics (presse/accusés/protocole médical existant), journées réelles jusqu’à `matchReady`, composition automatique, début de match, continuation explicite des causeries pré/après, délégation, confirmation éventuelle, rendez-vous et clôture quotidienne de semaine. Les entraînements planifiés sont exécutés par les vraies journées ; aucun `train` supplémentaire ne figurait dans le setup graphique remplacé. Le helper ferme le bridge avant la réouverture. La sauvegarde n’est lue que pour vérifier l’archive ; elle n’est jamais réécrite par le test.

Le reçu `public-preparation.json` déclare explicitement le mode `common`, le club 0 et les flags et contient commandes et charges exactes, dates/semaines, version Node, SHA worker/profil, résultat archivé et ID réel, durée et état succès/erreur. Le journal JSONL est persisté après chaque réponse, donc conservé même si le processus est interrompu. Aucun checkpoint externe n’est requis en CI. Le mode checkpoint local conserve sa copie intégrale et sa vérification SHA source avant/après, y compris en échec.

Le budget total reste 180 s dès l’entrée du test ; préparation Node plafonnée à 60 s, enfant Godot limité au minimum de 150 s et du temps global restant (réserve finale de 1 s). Le replay GDScript n’est pas modifié : mêmes assertions de lecture/retour, même vraie interaction clavier, trois captures 2560×1440, sauvegarde/RNG/silence et absence de commande métier pendant la consultation. Ce cas qualifie ces consultations ; les anciennes suites continuent à couvrir les scènes de préparation 3D.

Vérification locale limitée à `node --check` des deux scripts et `git diff --check`. Aucun SDK, import ni préparation de carrière exécuté ici. État historique de préparation ; la réception intégrateur figure ci-dessous.

## Périmètres distincts et reçus conservés

Le nouveau parcours CI common0 qualifie uniquement la consultation et les retours par le replay complet inchangé. Ce choix est compatible statiquement avec les destinations : common-rosters initialise FranceCareer, FranceCompetition fournit des fixtureId archivés et france-calendar-cadence expose dates/journées. Fiction13 est écarté : calendrier quotidien absent et résultats sans fixtureId. Aucun moteur ni projection ne sont adaptés pour rendre le test vert.

Les reçus WorldChamp29 restent distincts : replay sur copie 72 assertions / 0 échec et reader-history frais 115 / 0 qualifiés ; préparation graphique fraîche plafonnée à 150 s rouge, puis préparation Node WorldChamp29 plafonnée à 60 s rouge sur réception 89244201 (23 commandes acceptées, match délégué/confirmé, semaine non encore clôturée). Aucun de ces rouges n’est remplacé par le nouveau cas common0.

Vérification de cette adaptation : syntaxe du helper (`node --check`) et `git diff --check` seulement. Ce statut de préparation est historique ; la réception ultérieure commune est consignée ci-dessous. Aucun SDK/import n’a été exécuté dans ce worktree documentaire.


## Réception publique Common 0 du 12 novembre 2026

Sur `0e644e61ef3f78a6df4346f8d14d5ea33515c097`, la préparation publique Node
crée Common, club 0 : 20 commandes acceptées en 20,682 s, du 7 au 14 septembre 2026,
vraie fixture `s1-elite-league-0-0`, résultat 15–20. Le replay client reçoit
**72 contrôles, zéro échec, sortie 0**, wrapper 72,938245 s et TAP total 73,006040 s.
Trois PNG originaux 2560×1440 sont inspectés et publiés avec préparation JSON/JSONL,
rapport, source-copy, journaux et hashes, sans profil entier.

[Preuves ciblées et scopes séparés](evidence/night-public-common-replay-20261112/README.md).
La présentation claire préexistante de l’archive Common 0 est conservée. Les
bulles textuelles Gabi visibles ne sont pas supprimées ; l’assertion de silence
passe avec audio Dummy, sans champs de compteurs sérialisés inventés.
Le replay WorldChamp copié 72/0 et reader-history frais 115/0 sur bd6 restent des
scopes distincts. Les rouges WorldChamp graphique 150 s et Node 60 s restent
conservés sans résultat UI fabriqué. Cette variante ne qualifie pas une campagne
globale ni les préparations WorldChamp interrompues.

Pointeur pour le registre SDK :
`docs/qa/evidence/night-public-common-replay-20261112/qualified/report.json`,
avec `qualified/public-preparation.json`, `qualified/run.log` et `provenance.json`.
