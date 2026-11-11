# Verdict final de la CI commune

[PR 566](https://github.com/Xynph/cadrage-debordement/pull/566), tête `d83a81747416080abd7be49ef4472c060cacd879` : **les deux campagnes finales sont SUCCESS**. Main reste `96f537040bf9f2e37bf10b0a9b09518b732244a2`, revérifié après les tests.

- [JavaScript 43050364420](https://github.com/Xynph/cadrage-debordement/actions/runs/43050364420) : couverture `full`, cinq shards verts, **625 invocations de suites PASS**, 625 chemins uniques correspondant exactement aux 625 CJS attendus. Répartition : 124 / 126 / 125 / 125 / 125. Le contrôle final Validation CI publie SUCCÈS sur cette tête à 16:41:05 UTC.
- [SDK réel et P1 43050364671](https://github.com/Xynph/cadrage-debordement/actions/runs/43050364671) : SUCCESS ; 12 cas SDK réels, P1 principal **4 337 contrôles / 0 échec**, complément **1 660 / 0**, contrats **3 tests TAP / 3 PASS / 0 SKIP**. [Reçu détaillé voisin](ci-common-d83a817-sdk-receipt-20261111.md).

Les journaux complets des cinq shards, du classificateur et de Validation CI ont été récupérés avec le connecteur GitHub natif. Les listes PASS ont été dédupliquées et comparées aux fichiers attendus de la tête commune ; aucune omission ni doublon. Le JSON voisin conserve empreintes, compteurs et réponse API complète. Le SDK reste absent des shards Node : leurs SKIP SDK habituels ne sont pas présentés comme une validation Godot ; seuls les 12 cas du job dédié portent ce reçu réel.

Aucun correctif après les tests ni nouveau push de la commune. Le seul ajustement préalable concerne le budget 480 s de la nouvelle matrice sur profil frais ; les anciens 180 s SDK et 15 s VM restent inchangés. L’ancienne tête a été annulée avant sa campagne pour ce remplacement documenté.

Les 35 suites auditées restent classées avec leurs limites. Les compléments locaux des PR 567, 568 et 569 sont hors du gel commun et ne sont pas inclus dans cette CI. Les routes et états P1 non couverts restent explicités ; guide commun limité à layout/native ; aucun nouveau reçu Windows, paquet ZIP ou Release. Aucune fusion.
