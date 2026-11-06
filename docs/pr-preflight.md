# Précontrôle GitHub des PR depuis l'issue #73

## Objectif et limites
Après intégration **séparée** de cette PR technique dans `main`, l'identité propriétaire `Xynph` peut poster dans l'issue #73 une ligne strictement au format :

`/cd-preflight 336 bac1dbb32c91f0557902c74b28121cefa6ec5c37`

La commande déclenche le workflow `pr-preflight.yml` **de `main`**, qui checkout uniquement `main` (jamais le code de la PR ciblée) et utilise `ci/pr-preflight.cjs`. Le workflow ne devient utilisable sur `issue_comment` qu'après fusion officielle de la PR technique ; aucun test en branche DRAFT ne prouve le comportement de l'événement de production.

## Vérifications
- Issue #73, événement `created`, auteur et acteur `Xynph` ID immuable, format strict PR + SHA 40 hex, puis relecture du commentaire original depuis GitHub.
- `main` réel ; PR ouverte ciblant `main` exact, dépôt d'origine, HEAD exact, `mergeable_state=clean` et `mergeable=true`.
- Réutilise `decide()` de `ci/release-gate.cjs` uniquement en diagnostic et autorise l'analyse d'une PR DRAFT en neutralisant son drapeau dans la copie en mémoire. **Ne modifie jamais la PR**.
- Workflow JavaScript de la tête exacte terminé SUCCESS, sept jobs obligatoires chacun SUCCESS (Validation CI incluse).
- Diff paginé, absence de chemin identique dans les autres PR ouvertes ; existence d'un commentaire propriétaire #73 de RÉSERVATION mentionnant numéro de PR et chacun des chemins. Cela vérifie une trace de réservation, non une exclusivité parfaite des réservations historiques ; une collision ou absence de preuve donne STOP.
- Diagnostic dans résumé Actions et commentaire #73 ; aucune mutation de branche, de DRAFT/READY, ni déclenchement des commandes /cd-check ou /cd-merge.

## Sécurité
Permissions générales `contents:read`. Le **seul job issue_comment** reçoit `actions:read`, `pull-requests:read` et `issues:write` strictement pour publier le diagnostic dans #73. Aucune permission `contents:write`, `administration:write`, aucun PAT, secret, déclenchement privilégié sur code PR ou clé long terme. Les déclenchements non propriétaires échouent avant exécution ; le script recontrôle l'identité.

`mergeable_state` provient du REST GitHub authentifié, et ne doit pas être déduit de `mergeable=true`. Une valeur absente/unstable/dirty est STOP.

**La liste `bypass_actors` du ruleset #26326518 reste INCONNUE** : ce jeton minimal ne fournit pas les droits nécessaires pour l'attester. Aucun verdict du précontrôle ne prétend prouver `bypass_actors=[]`, le ruleset actif ou accorder le droit de fusion. L'attestation actuelle doit être obtenue indépendamment par une identité administratrice autorisée ; ne pas ajouter de droit Administration write au workflow pour cette raison.

Le précontrôle **ne remplace ni le ruleset serveur ni le gate officiel** `/cd-check` puis `/cd-merge`, ni la vérification post-fusion 7/7. Un précontrôle techniquement vert ne vaut jamais CONTRÔLE VERT du release gate.

## Tester et publier
Exécuter `node --check ci/pr-preflight.cjs` puis `node tests/pr-preflight.cjs`. La CI PR exécute les mêmes validations sans jeton d'écriture ; la commande issue_comment réelle est à recevoir seulement après intégration indépendante du lot technique. En cas de limite API, pagination dépassée, commentaire non authentifié, CI en cours, HEAD divergent ou conflit : STOP, aucune fusion. La publication d'un diagnostic exige `issues:write` ; un échec de publication fait échouer le job.
