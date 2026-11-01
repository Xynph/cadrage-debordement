# Livraison express sécurisée

## Intention et plan du lot

Produire un bilan agrégé informatif lié à une PR, son HEAD exact et au main
observé. Ne jamais fusionner, modifier le gate officiel ou remplacer Validation CI.
Seuls les quatre fichiers de la réservation #6564869188 sont concernés.

Choix : workflow manuel en lecture seule par défaut ; publication #73 séparée,
opt-in. Un déclenchement automatique `workflow_run` ajouterait un chemin privilégié
et des événements redondants ; il n'est pas retenu. Les commandes par commentaire
restent exclusivement dans le gate existant. Aucun workflow existant n'est modifié.

Plan d'exécution autonome demandé par Léo :
- [x] Tests négatifs du bilan : CI absente/rouge/en cours, jobs manquants, ancien
  succès masquant une relance rouge, mauvais SHA/dépôt, main ou HEAD changeant.
- [x] Implémenter la collecte paginée bornée, le verdict et le brouillon #73.
- [x] Workflow manuel, résumé Actions, publication optionnelle protégée sur main.
- [ ] Tests ciblés et revue sécurité ; publication d'une PR sans fusion ; passation.

## Utilisation

Après intégration autorisée de cette PR seulement, lancer manuellement le workflow
**Livraison express — précontrôle informatif** sur `main`, avec le numéro de PR et
son HEAD complet. Le propriétaire numérique `350229047` (`Xynph`) doit être
l'acteur initial et celui de la relance. Aucun événement commentaire, push,
workflow_run ou pull_request ne lance ce workflow.

Par défaut, seuls le journal et le résumé Actions sont produits. Le bilan :

1. Lit la PR REST, le SHA de main, la comparaison Git et le workflow officiel.
2. Agrège la dernière activité de tentative (updated_at puis ID) de chaque workflow PR observé sur le SHA et associé à
   cette PR, avec ses jobs paginés. Une ancienne réussite ne masque pas un run
   plus récent rouge ou en cours. Les jobs ignorés sont refusés : il peut donc
   être plus conservateur qu'un workflow ayant des jobs optionnels légitimes.
3. Réutilise `decide()` du gate officiel sans modification ; exige en plus les
   sept jobs complets du workflow Tests JavaScript pour PR et main, et behind=0.
4. Relit les listes de CI, HEAD, état de PR et main pour refuser un bilan qui a
   changé pendant la collecte. Maximum dix pages par liste ; refus au-delà,
   aucun résultat silencieusement tronqué, aucune attente active.
5. Prépare la commande exacte `/cd-check PR SHA40` seulement si le précontrôle
   est satisfait. **Le propriétaire doit la relire et la publier lui-même dans
   #73**. Le bilan n'exécute ni commande Chat ni CLI de fusion.

Pour publier une passation automatiquement, il faut **à la fois** l'entrée
`publish=true` et la variable de dépôt `CD_DELIVERY_PUBLISH=true`. Ce lot n'active
aucune de ces options. Le job séparé reçoit `issues: write` uniquement ; contenus,
Actions et PR restent en lecture seule. Il recharge les preuves depuis GitHub,
revérifie main et le propriétaire, puis poste un bilan dans #73. Aucun artefact
ou code provenant d'une PR n'est exécuté avec ce jeton. Les actions sont épinglées
et les credentials checkout ne sont pas conservés. Les entrées passent via des
variables d'environnement et des arguments cités, sans interpolation dans le shell.

Le texte de passation commence par un titre : il ne constitue pas une commande
`/cd-check` exécutable. Un commentaire émis par github-actions[bot] n'est de toute
façon pas l'auteur propriétaire autorisé par le gate existant. Aucune promesse de
notification ChatGPT ou de surveillance de session. Une relance explicite avec
publication peut ajouter une nouvelle passation ; aucune relance automatique.

En local : `node ci/delivery-readiness.cjs PR SHA40` avec Node et `gh` authentifié.
Ce mode reste sans écriture par défaut ; l'option de publication exige le contexte
GitHub Actions propriétaire sur main et la double activation. Ne pas définir
CD_PUBLISH pour une simple simulation.

## Audit des mécanismes existants (lecture seule)

Base examinée : `8122893ae0d0bb529d5c6f03cd9fba7e9db9feef`.

| Mécanisme | Constat | Conséquence du lot |
| --- | --- | --- |
| tests.yml | PR/main/manuel, classification + cinq shards + Validation CI, résumés natifs | Inchangé ; le nouveau test .cjs est découvert par le sharding existant |
| chat-release-gate.yml | issue_comment created sur #73, identité propriétaire, actions épinglées, code du snapshot main | Aucun nouveau déclenchement par commentaire |
| Permissions du gate Chat | Le job partage contents:write/actions:write/issues:write entre check et merge | Périmètre existant plus large que notre bilan ; aucune modification hors réservation |
| chat-release.cjs | Commande stricte, commentaire relu, main stable et CI 7/7 avant gate ; SHA attendu transmis au CLI | Appel de decide() en lecture seule ; aucune exécution de execute() |
| Post-fusion existant | Reçu SHA de fusion, dispatch identifié, contrôle du SHA/workflow et sept jobs après attente | Aucun essai de fusion dans ce lot ; le bilan ne certifie pas une nouvelle livraison |
| release-gate.cjs | PR ouverte non brouillon et clean, même dépôt, Tests JavaScript et Validation CI au HEAD ; comparaison SHA lors du squash | Critères conservés ; le bilan ne donne aucun droit de fusion |

Limites : aucun contrôle de bilan ne constitue une transaction atomique avec
GitHub. Une CI peut changer après la dernière lecture. Les protections serveur,
rulesets, contrôles externes, revues exigées et l'existence de workflows absents
des runs observés ne sont pas certifiés ici. Ces responsabilités restent au
contrôle officiel et à GitHub. Pas d'activation de gouvernance ni de protection
serveur. L'autorisation de Léo pour une fusion reste distincte et obligatoire.

## Étude merge queue — sans activation

Le dépôt actuel est public et appartient à **Xynph, type User**, selon la réponse
GitHub de cette session. La documentation GitHub décrit la disponibilité des
merge queues pour les dépôts publics d'organisations ou privés d'organisations
Enterprise Cloud : l'éligibilité de ce dépôt personnel n'est donc pas établie.
Aucun transfert d'organisation ou changement de forfait n'est proposé dans ce lot.

La CI existante ne déclare pas `merge_group`. GitHub exige cet événement pour
rapporter les contrôles d'un groupe de fusion. Le gate courant vise la CI de tête
PR puis un squash explicite : il ne constitue pas un protocole de merge queue.
**Ne pas activer la queue sur cette base.** Un chantier futur autorisé devrait
vérifier l'éligibilité, les règles serveur, tous les contrôles requis et leur
concurrence, puis valider les SHA synthétiques de groupe et l'autorisation par PR.
Ni changement de règle, ni activation, ni ajout en queue dans ce lot.

Sources officielles consultées :
- [Déploiement et disponibilité des queues](https://docs.github.com/en/pull-requests/concepts/deploying-code)
- [Contrôles requis et merge_group](https://docs.github.com/en/enterprise-cloud@latest/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks)
- [Gestion d'une merge queue](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue)

## Validation et réception

Tests ciblés : `node tests/delivery-readiness.cjs`, `node tests/chat-release.cjs`,
`node tests/release-gate.cjs`, `node tests/ci-sharding.cjs`. Syntaxe Node et
structure YAML vérifiées localement. Le nouveau bilan et les garde-fous sont
exercés avec des réponses API déterministes hors réseau ; aucun appel de
publication ou /cd-check réel n'est nécessaire pour ces tests.

La CI complète de la PR appartient au workflow existant et doit être contrôlée
sur le SHA publié. Ce nouveau workflow manuel ne sera exécutable sur main
qu'après une fusion autorisée ultérieure : aucun essai live de dispatch ou de
publication n'est revendiqué dans cette PR. La suite complète du jeu n'est pas
rejouée localement pour ce chantier limité ; elle reste attendue sur GitHub.
Les identifiants PR, SHA et résultats distants constatés figurent dans #73.


### Correction après revue indépendante de réception

La revue a reproduit un faux vert avec une relance rouge d'un ancien run :
GitHub conserve le run ID. Le bilan trie désormais par activité `updated_at`
(repli `created_at` si absent, date valide obligatoire), puis donne priorité à
l'état non vert en cas d'égalité de date, puis ID. Ce choix s'applique aussi à
la CI de main sans modifier les gates officiels. Les empreintes de relecture
incluent les dates et le numéro de tentative. Tests : relance rouge ancienne,
égalité de dates avec tentative en cours, relance de main, relance pendant la
collecte, ancien échec antérieur et date invalide. Aucun changement du workflow
ou d'activation automatique. Les résultats définitifs de la réception sont dans #73.
