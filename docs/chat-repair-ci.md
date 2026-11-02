# Développement et récupération CI depuis Chat

## Fonctionnement normal (sans Work)

Le connecteur GitHub consulte `main`, `AGENTS.md`, les réservations de l'issue #73 et les PR, crée des branches et publie les commits directement dans GitHub. Les GitHub Actions installent Node/Chromium et exécutent les tests sur les commits exacts. Le résultat de `Validation CI` est la source de vérité : une CI en cours ou ignorée n'est jamais verte.

Pour chaque lot, éviter les allers-retours : **une prise de chantier**, une branche et une PR, **une réception terminale du run** et **une passation finale** dans #73. Ne multiplier ni les commentaires de suivi ni les relances sans échec réel. Toutes les fusions conservent l'autorisation explicite de Léo par PR et HEAD, l'intégrateur unique, le ruleset et les sept jobs post-fusion. Les chemins incompatibles restent réservés séparément.

Le code du workflow privilégié provient uniquement du SHA de `main`, jamais du code d'une PR. Les commandes normales `/cd-check PR SHA40` et `/cd-merge PR SHA40` restent inchangées et exigent un `main` déjà vert. La réparation ci-dessous est **distincte et non générique**.

## Réparation encadrée d'une CI rouge

L'orchestrateur accepte également deux syntaxes strictes **uniquement après installation de cette évolution sur main** :

```text
/cd-repair-check PR HEAD_SHA40 MAIN_SHA40 RUN_MAIN_ROUGE
/cd-repair-merge PR HEAD_SHA40 MAIN_SHA40 RUN_MAIN_ROUGE
```

Par exemple, pour l'incident documenté #212 : `/cd-repair-check 212 59aeb359c9966a892ac8994e636af38f12fe0bbd f189d09f317b73d4e9e3d54ee694e6c4c2c9262b 41427301234`. **Ceci n'est pas une commande à émettre avant installation.**

Le mode réparation n'est pas une dispense générale :
- Le **dernier** run de CI main doit correspondre à l'identifiant explicitement fourni, au SHA main courant et au bon workflow ; état terminal `failure`, sept jobs complets et uniques. `classification` réussie, `Validation CI` échouée, cinq suites réellement exécutées (success/failure), au moins une en échec ; ni skipped ni échec d'infrastructure non classifié accepté.
- La PR doit cibler ce main exact et conserver son HEAD exact. La comparaison des fichiers est bornée à **un seul fichier modifié**, soit `tests/*.cjs`, soit `dist/*.js` sans sous-répertoire. Impossible de modifier le gate, les workflows, les permissions ou les fichiers de données avec une commande de réparation.
- Le contrôle du CLI `ci/release-gate.cjs` reste obligatoire avec `CD_EXPECTED_HEAD_SHA` ; la PR non draft, `mergeable_state=clean`, la CI PR complète réussie sur HEAD exact et `Validation CI` restent nécessaires. GitHub doit appliquer son ruleset et la fusion SHA-verrouillée.
- Une commande de fusion exige **toujours** une autorisation explicite de Léo ciblant le numéro et le HEAD, puis l'exécution par l'intégrateur unique. Le même groupe de concurrence sérialise commandes normales et réparation. Les commandes normales continuent d'exiger un main vert.

Après une fusion autorisée, conserver le reçu SHA de GitHub, déclencher la CI complète du **nouveau** main sur ce SHA et vérifier exactement sept jobs `success` ; tout échec entraîne `STOP` et un bilan factuel dans #73. Aucun ancien succès ni ancienne exécution n'est recyclé.

### Limite fondamentale : amorçage de #212

**Cette PR d'orchestration ne peut pas débloquer rétroactivement #212.** Le code de `main` est le seul exécuté par le workflow GitHub privilégié. Tant que la présente évolution n'est pas elle-même intégrée via une procédure autorisée, les nouvelles commandes n'existent pas côté serveur. Il est interdit de lancer un workflow privilégié depuis une branche de PR pour contourner ce problème. Pour #212, conserver la procédure exceptionnelle approuvée dans [#6574920305](https://github.com/Xynph/cadrage-debordement/issues/73#issuecomment-6574920305) et sa condition de disposer d'un vrai environnement CLI authentifié. Aucun merge direct via le connecteur, aucune modification temporaire du ruleset et aucun `push` vers `main`.

Pour tout incident touchant plusieurs fichiers ou les protections de CI elles-mêmes, la commande refuse et une procédure exceptionnelle documentée, avec autorisation distincte et environnement authentifié, reste nécessaire. La récupération courante est volontairement limitée aux correctifs minimaux d'un seul fichier, pour éviter une voie de fusion ouverte à des changements privilégiés.

## Métriques à relever sur trois PR suivantes

Mesurer : demande → PR prête, PR verte → décision d'intégration, CI PR et post-fusion (temps réel), nombre de contrôles intermédiaires, nombre de commentaires de passation et collisions de fichiers. L'objectif est de supprimer les consultations et transferts redondants, **pas** de retirer des suites, des contrôles d'écriture ou les tests de sauvegardes.
