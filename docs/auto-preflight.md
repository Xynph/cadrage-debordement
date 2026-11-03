# Précontrôle automatique des intégrations ordinaires

## Objectif pour le jeu

Après une CI PR terminée et réussie, éliminer une partie des consultations manuelles : vérifier automatiquement les **sept jobs réels**, le **HEAD exact**, l'état READY et la possibilité d'appeler le **gate officiel existant**, puis publier un seul bilan dans le résumé Actions. Les développeurs consacrent davantage de temps au jeu, tout en conservant le même contrôle de qualité.

## Sécurité et limites

- Workflow `workflow_run` depuis le dépôt, checkout de **main uniquement** : aucun script ou branche de PR n'est exécuté avec le jeton.
- Permissions explicites **lecture seule** ; aucune issue, PR, commentaire ou branche écrite ; jamais `--merge`.
- Le déclencheur ne traite que `Tests JavaScript` de type `pull_request`, terminé `success`, avec SHA de PR présent dans l'événement. Si le SHA n'est pas disponible ou change, refus sûr.
- Relecture des sept jobs, de la PR READY et de `mergeable_state=clean`, puis appel sans `--merge` à `ci/release-gate.cjs` avec `CD_EXPECTED_HEAD_SHA`.
- Un résumé vert n'est **pas** une autorisation de fusion : le gate privilégié via `/cd-merge PR SHA`, les protections de branche et les vérifications post-fusion 7/7 restent inchangés.
- Si une PR est DRAFT, en conflit, en cours, liée à un SHA périmé ou non listée dans la charge utile GitHub, elle n'est **pas** déclarée prête ; aucun rapprochement approximatif.
- **Aucune activation d'intégration automatique.** Pour cela, une évolution contrôlée du mécanisme officiel et de ses règles d'autorisation serait nécessaire. DATA/V60/sauvegardes ne sont pas modifiés.

## Vérification

`node tests/auto-preflight.cjs` couvre les événements refusés, SHA erronés, sept jobs, double jobs, états PR, échecs du gate, absence de fusion et permissions du workflow.

Le workflow est ajouté sur une PR distincte. Il ne devient actif sur main qu'après intégration via le gate officiel. Cette PR ne déclenche donc pas à elle seule un test réel `workflow_run` du nouveau workflow ; sa réception native est à constater après fusion autorisée. Le test manuel du tableau `dev-conductor-dashboard.yml` hérité de #259 n'a pas été exécuté depuis le connecteur GitHub (pas d'action `workflow_dispatch` disponible en écriture).

## Mesures réelles / attendues

Avant : découverte du résultat PR, lecture manuelle de la CI, décision de contrôle séparée.
Après activation : jusqu'à **un précontrôle officiel par CI PR verte** sans clic de lancement ; bilan consultable sur Actions. Il ne s'agit ni d'un gain chronométré ni d'une réduction de la durée des sept tests.
