# Développement simplifié — prototype sans activation

## Diagnostic du 3 novembre 2026

Le dépôt possède déjà : `tests.yml` (classification + 5 suites + Validation CI = 7 jobs), `ci/delivery-readiness.cjs` (précontrôle), `ci/release-gate.cjs` (fusion avec SHA verrouillé), les commandes `/cd-check` et `/cd-merge`, et une intégration rapide encadrée par sélection explicite du propriétaire. Créer un second gate autonome doublerait les contrôles et augmenterait le risque.

## Première simplification livrée par cette PR

`node ci/dev-conductor.cjs` présente **un seul bilan lisible** des PR ouvertes, regroupées par DATA / V60 / CI / GAME / DOCS, avec chevauchements de fichiers, dépendances vers d'autres branches, prochaine action et **état des 7 jobs de la CI officielle associé au HEAD exact**. Le tableau distingue CI absente, en cours, échouée, incomplète, 7/7 SUCCESS, sans se substituer au gate. `--json` permet une consommation automatisée ultérieure. La lecture CI se limite aux 100 dernières exécutions PR du workflow officiel : une exécution plus ancienne non retrouvée reste marquée absente, jamais verte par supposition. Les jobs sont vérifiés individuellement, et la mention **7/7 SUCCESS** signifie seulement le résultat des tests, **jamais l'autorisation de fusion**. Tous les appels GitHub sont des GET via `gh api`. L'outil n'a **aucune** capacité d'écrire, de fusionner, de relancer la CI ou de modifier les réservations.

Il **n'affirme jamais** qu'une PR est validée : seul le gate officiel sur le SHA exact et les protections GitHub peuvent le déterminer. Un chevauchement signale une coordination nécessaire, pas un conflit Git certain. Les périmètres DATA et V60 restent intacts.

## Accès directement depuis GitHub (désactivé tant que cette PR n'est pas intégrée)

Le nouveau workflow `.github/workflows/dev-conductor-dashboard.yml` propose un déclenchement **manuel** depuis l'onglet Actions, sur `main` uniquement. Un champ facultatif `pr` accepte un numéro de PR pour lancer le **gate officiel** par `node ci/release-gate.cjs PR` **sans `--merge`** ; aucun système parallèle de fusion n'est ajouté. Le numéro est validé strictement et l'échec du gate entraîne l'échec du contrôle ciblé. Il réexécute les tests ciblés et produit le bilan dans le résumé de son exécution. Il possède seulement `contents: read`, `pull-requests: read` et `actions: read`, sans token d'écriture ni `pull_request_target`. Il ne peut pas intégrer de PR, et ne se déclenche pas sur les modifications DATA ou V60. Un gate vert reste **informatif** ici : pour fusionner, la procédure officielle de livraison et les contrôles serveur restent nécessaires. Une fois le code validé et fusionné par le gate officiel, il devient un point d'entrée simple pour l'intégrateur. Il ne remplace aucune CI existante.

## Suite en deux phases, soumise à validation

1. **Pilotage unique** : faire consommer ce bilan en complément du précontrôle existant, éviter les doubles passations, conserver un seul compte intégrateur. Évaluer sur des PR réelles le nombre de requêtes manuelles économisées.
2. **Activation contrôlée** : adapter dans une PR séparée le gate existant (pas le contourner) pour les changements ordinaires, avec tests de sécurité, verrouillage du SHA, CI obligatoire 7/7 et post-fusion 7/7, exclusions des sauvegardes, sécurité, données critiques et règles du rugby. Vérifier d'abord l'accès et les protections des règles GitHub.

La demande utilisateur peut être unique, mais GitHub Actions ne fait pas travailler spontanément deux assistants ChatGPT en arrière-plan : les deux producteurs restent responsables du code. L'automatisation doit s'occuper du contrôle et du passage de relais, pas inventer une exécution par un développeur.

## Mesures

- Avant : lecture individuelle de N PR, rapprochements manuels des fichiers et de leurs dépendances ; commandes de fusion séparées.
- Maintenant : **1 commande de lecture** pour l'état transverse de N PR. Réduction instrumentale de N consultations d'ensemble à 1 (pas de gain de temps chronométré à ce stade).
- Couverture : tri, chemins sensibles, chevauchement, bases empilées, états draft, refus de métadonnées invalides, SHA CI obsolète, jobs manquants, en cours, rouges ou verts ; tests Node `node tests/dev-conductor.cjs`.
- Aucun gain de durée de CI revendiqué. **Un nouveau workflow manuel en lecture seule** a été ajouté ; aucun workflow existant désactivé, aucune activation de fusion ni fusion.

## Utilisation

```sh
node tests/dev-conductor.cjs
node ci/dev-conductor.cjs
node ci/dev-conductor.cjs --json
node ci/dev-conductor.cjs --gate 259  # vérification officielle sans fusion
```
