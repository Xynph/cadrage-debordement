# Développement et récupération CI depuis Chat

## Fonctionnement normal (sans Work)

Le connecteur GitHub consulte `main`, `AGENTS.md`, les réservations de l'issue #73 et les PR, crée des branches et publie les commits directement dans GitHub. Les GitHub Actions installent Node/Chromium et exécutent les tests sur les commits exacts. Le résultat de `Validation CI` est la source de vérité : une CI en cours ou ignorée n'est jamais verte.

Pour chaque lot, éviter les allers-retours : **une prise de chantier**, une branche et une PR, **une réception terminale du run** et **une passation finale** dans #73. Ne multiplier ni les commentaires de suivi ni les relances sans échec réel. Toutes les fusions conservent l'autorisation explicite de Léo par PR et HEAD, l'intégrateur unique, le ruleset et les sept jobs post-fusion. Les chemins incompatibles restent réservés séparément.

Le code du workflow privilégié provient uniquement du SHA de `main`, jamais du code d'une PR. Les commandes normales `/cd-check PR SHA40` et `/cd-merge PR SHA40` restent inchangées et exigent un `main` déjà vert. La réparation ci-dessous est **distincte et non générique**.

## Réparation encadrée d'une CI rouge

L'orchestrateur accepte également deux syntaxes strictes **une fois cette évolution fusionnée sur main** :

```text
/cd-repair-check 212 59aeb359c9966a892ac8994e636af38f12fe0bbd
/cd-repair-merge 212 59aeb359c9966a892ac8994e636af38f12fe0bbd
```

Elles sont **épinglées à ce seul incident** :
- main attendu `f189d09f317b73d4e9e3d54ee694e6c4c2c9262b` ;
- dernier run main `41427301234`, terminal `failure`, sept jobs complets, seuls `Suites 1/5` et `Validation CI` en échec ;
- PR #212 ouverte sur `main`, HEAD exact, et **unique** fichier modifié `tests/governance-exclusive.test.cjs`.

Tout autre main, run récent, PR, SHA, chemin ou motif d'échec est **refusé**, y compris une PR ajoutant un fichier CI. Le contrôle du CLI `ci/release-gate.cjs` reste obligatoire avec `CD_EXPECTED_HEAD_SHA` ; GitHub doit appliquer sa protection native `Validation CI`, les règles de synchronisation, l'interdiction de push direct et ses autres restrictions. Aucune mutation n'est automatique par publication d'une PR ; la commande de fusion nécessite toujours l'autorisation explicite de Léo et une exécution par l'intégrateur désigné. Le même groupe de concurrence sérialise commandes normales et réparation.

Après une fusion autorisée, conserver le reçu SHA de GitHub, déclencher la CI complète du **nouveau** main sur ce SHA et vérifier exactement sept jobs `success` ; tout échec entraîne `STOP` et un bilan factuel dans #73. Aucun ancien succès ni ancienne exécution n'est recyclé.

### Limite fondamentale : amorçage de #212

**Cette PR d'orchestration ne peut pas débloquer rétroactivement #212.** Le code de `main` est le seul exécuté par le workflow GitHub privilégié. Tant que la présente évolution n'est pas elle-même intégrée via une procédure autorisée, les nouvelles commandes n'existent pas côté serveur. Il est interdit de lancer un workflow privilégié depuis une branche de PR pour contourner ce problème. Pour #212, conserver la procédure exceptionnelle approuvée dans [#6574920305](https://github.com/Xynph/cadrage-debordement/issues/73#issuecomment-6574920305) et sa condition de disposer d'un vrai environnement CLI authentifié. Aucun merge direct via le connecteur, aucune modification temporaire du ruleset et aucun `push` vers `main`.

Une fois le main réparé, envisager **dans une autre PR**, avec tests et autorisation distincte, une politique de récupération réutilisable. Cette première version reste volontairement épinglée afin de ne pas introduire de permission générique de fusion depuis main rouge.

## Métriques à relever sur trois PR suivantes

Mesurer : demande → PR prête, PR verte → décision d'intégration, CI PR et post-fusion (temps réel), nombre de contrôles intermédiaires, nombre de commentaires de passation et collisions de fichiers. L'objectif est de supprimer les consultations et transferts redondants, **pas** de retirer des suites, des contrôles d'écriture ou les tests de sauvegardes.
