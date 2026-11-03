# Développement simplifié — prototype sans activation

## Diagnostic du 3 novembre 2026

Le dépôt possède déjà : `tests.yml` (classification + 5 suites + Validation CI = 7 jobs), `ci/delivery-readiness.cjs` (précontrôle), `ci/release-gate.cjs` (fusion avec SHA verrouillé), les commandes `/cd-check` et `/cd-merge`, et une intégration rapide encadrée par sélection explicite du propriétaire. Créer un second gate autonome doublerait les contrôles et augmenterait le risque.

## Première simplification livrée par cette PR

`node ci/dev-conductor.cjs` présente **un seul bilan lisible** des PR ouvertes, regroupées par DATA / V60 / CI / GAME / DOCS, avec chevauchements de fichiers, dépendances vers d'autres branches et prochaine action. `--json` permet une consommation automatisée ultérieure. Tous les appels GitHub sont des GET via `gh api`. L'outil n'a **aucune** capacité d'écrire, de fusionner, de relancer la CI ou de modifier les réservations.

Il **n'affirme jamais** qu'une PR est validée : seul le gate officiel sur le SHA exact et les protections GitHub peuvent le déterminer. Un chevauchement signale une coordination nécessaire, pas un conflit Git certain. Les périmètres DATA et V60 restent intacts.

## Suite en deux phases, soumise à validation

1. **Pilotage unique** : faire consommer ce bilan en complément du précontrôle existant, éviter les doubles passations, conserver un seul compte intégrateur. Évaluer sur des PR réelles le nombre de requêtes manuelles économisées.
2. **Activation contrôlée** : adapter dans une PR séparée le gate existant (pas le contourner) pour les changements ordinaires, avec tests de sécurité, verrouillage du SHA, CI obligatoire 7/7 et post-fusion 7/7, exclusions des sauvegardes, sécurité, données critiques et règles du rugby. Vérifier d'abord l'accès et les protections des règles GitHub.

La demande utilisateur peut être unique, mais GitHub Actions ne fait pas travailler spontanément deux assistants ChatGPT en arrière-plan : les deux producteurs restent responsables du code. L'automatisation doit s'occuper du contrôle et du passage de relais, pas inventer une exécution par un développeur.

## Mesures

- Avant : lecture individuelle de N PR, rapprochements manuels des fichiers et de leurs dépendances ; commandes de fusion séparées.
- Maintenant : **1 commande de lecture** pour l'état transverse de N PR. Réduction instrumentale de N consultations d'ensemble à 1 (pas de gain de temps chronométré à ce stade).
- Couverture : tri, chemins sensibles, chevauchement, bases empilées, états draft, refus de métadonnées invalides ; tests Node `node tests/dev-conductor.cjs`.
- Aucun gain de durée de CI revendiqué. Aucun workflow ajouté ou désactivé ; aucune activation ni fusion.

## Utilisation

```sh
node tests/dev-conductor.cjs
node ci/dev-conductor.cjs
node ci/dev-conductor.cjs --json
```
