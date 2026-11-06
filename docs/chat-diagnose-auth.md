# Diagnostic Chat : preuve complète du ruleset #26326518

## Pourquoi la PR #328 reste STOP
GitHub REST masque `bypass_actors` lorsque l'identité requérante n'a pas le droit
de modifier le ruleset. Un `GITHUB_TOKEN` Actions limité à la lecture ne peut
pas démontrer que la liste est vide. Une propriété absente ne vaut **jamais** `[]`.

## Raccordement proposé (DRAFT : ne pas activer sans évaluation)
Le seul workflow `.github/workflows/chat-diagnose.yml` est déclenché par un
commentaire strict `/cd-diagnose PR SHA` de l'identité propriétaire dans #73.
Le workflow crée un jeton éphémère GitHub App limité au **seul dépôt**
`Xynph/cadrage-debordement`, avec `permission-administration: write`, et
révoqué à la fin du job. Le jeton est exposé seulement au processus Node comme
`CD_RULESET_TOKEN` ; seul l'appel `GET /rulesets/26326518` l'utilise. Les
autres lectures, vérifications et l'écriture du compte rendu emploient le
`GITHUB_TOKEN` limité déjà en place.

**Risque résiduel important :** GitHub ne propose pas une permission
`bypass_actors:read` distincte. L'identité disposant d'Administration write
peut potentiellement **modifier les protections**, même si notre code n'exécute
qu'un GET. La limitation au dépôt, à une courte durée de vie et à un job
propriétaire réduit l'exposition mais ne rend pas cette permission lecture seule.
Ne pas installer l'App si ce risque n'est pas acceptable. Préférer dans ce cas
un contrôle manuel hors Actions et maintenir STOP pour le gate automatique.

## Préparation propriétaire (aucune clé à publier)
1. Créer une GitHub App dédiée, privée et limitée à un seul dépôt, sans webhook.
2. Accorder uniquement `Repository administration: Read and write` en plus
   de `Metadata: read` implicite. Ne pas ajouter d'autres droits de contenu,
   d'Actions, de PR, d'issues ou d'organisation.
3. Installer uniquement dans `Xynph/cadrage-debordement`.
4. Définir dans Actions la variable `CD_DIAGNOSTIC_APP_CLIENT_ID` et le secret
   `CD_DIAGNOSTIC_APP_PRIVATE_KEY`. Ne jamais coller la clé dans issue/chat/log.
5. Vérifier que la PR technique est testée et intégrée avec le gate existant
   avant d'exécuter un diagnostic sur #328. Tant qu'elle reste DRAFT, aucun
   chemin officiel ne change sur main.

## Garanties et réception
- Le workflow `issue_comment` ne s'exécute que pour la commande exacte issue
  de Xynph sur #73 ; un commentaire de PR extérieure ne déclenche pas le jeton.
- Les dépendances GitHub Actions sont épinglées à des SHA.
- Si secret/installation/permissions absents, l'étape de jeton échoue : STOP.
- Si `bypass_actors` est absent, non tableau ou non vide : STOP.
- Si l'identité ou le HEAD change, si un check échoue ou si main avance :
  STOP. Pas de modification du ruleset, bypass ni fusion directe.
- Tester `node tests/chat-diagnose-auth.cjs`, puis les workflows CI sur le
  HEAD exact de cette PR technique. Ne jamais annoncer un test end-to-end
  positif sans authentification déployée et reçu serveur réel.
- Pour #328 : seulement après DIAGNOSTIC VERT sur son HEAD courant, exécuter
  `/cd-check PR SHA`, attendre le reçu officiel VERT, puis `/cd-merge PR SHA`
  et vérifier les 7 jobs post-fusion sur le SHA exact de main.

Sources : GitHub REST « Get a repository ruleset » (champ bypass_actors masqué
sans droit de modification) et actions/create-github-app-token v3.
