# Fusion contrôlée depuis Chat — PR #197

## Utilisation et autorité

Uniquement un **nouveau commentaire** de Xynph (identifiant GitHub 350229047), dans l’issue #73 du dépôt Xynph/cadrage-debordement (1439603196), sur une seule ligne exacte :

```
/cd-check NUMERO_PR SHA_COMPLET_40_CARACTERES
/cd-merge NUMERO_PR SHA_COMPLET_40_CARACTERES
```

`cd-check` exécute le gate officiel sans mutation de branche et publie son résultat dans #73. `cd-merge` demande le squash puis attend la CI du commit réellement fusionné. Le token n’identifie pas le compte ChatGPT : l’identité GitHub du propriétaire **ne remplace pas l’autorisation explicite de Léo ni la coordination de #73**. En particulier #193 reste sans autorisation de fusion.

Un seul ordre à la fois. Le groupe de concurrence est attaché au job autorisé et non à tous les commentaires ; pas d’annulation d’un job actif. GitHub conserve un seul job en attente dans ce groupe : ne pas l’utiliser comme une file de commandes illimitée. Une commande mise en attente dont main a changé est refusée ; la soumettre à nouveau après vérification des réservations et du SHA. Modifier un commentaire ne relance pas l’action.

## Frontière de confiance et permissions

- Workflow sur la branche principale ; checkout du SHA immuable `github.sha`, jamais du code de la PR. Refus si ce snapshot diffère du main courant. Checkout sans persistance des identifiants, actions épinglées à leur SHA.
- Permissions globales nulles. Job seul : contents write (squash), actions write (lecture/dispatch), issues write (compte rendu) et pull-requests read. Aucun PAT, secret permanent, permission administration ou id-token ajouté. Les protections serveur restent applicables.
- Révalidation de l’événement, dépôt, issue, auteur numérique/login/type, sender, acteur et acteur de relance. Nouvelle lecture du commentaire pour refuser une commande modifiée/déplacée. Syntaxe stricte ; aucun texte de commentaire interpolé dans une commande shell.
- `ci/release-gate.cjs` conserve ses critères `decide()` et sa fusion avec SHA attendu. Garde additive `CD_EXPECTED_HEAD_SHA` dans la **lecture du gate lui-même**, pour empêcher qu’une nouvelle tête à CI verte remplace le SHA autorisé entre deux étapes. Le comportement manuel antérieur est conservé si cette variable est absente.

## CI avant et après fusion

Avant chaque ordre, le dernier run principal du main exact doit être réussi et comporter les sept jobs complets : classification, Suites 1/5 à 5/5 et Validation CI. Une CI récente rouge/en cours ne peut être masquée par une ancienne verte. Sans cette précondition, aucun gate de fusion n’est exécuté : un échec post-fusion bloque donc les ordres suivants jusqu’à correction et validation du main.

Le CLI officiel vérifie toujours PR ouverte/non draft, base main, même dépôt, `mergeable_state=clean`, CI PR Tests JavaScript sur la tête exacte et Validation CI. Le SHA est transmis à GitHub au moment du squash ; aucune option de bypass ou auto-merge.

Après mutation, le SHA provient du reçu du CLI, **pas d’une lecture opportuniste du main**. La branche doit correspondre à ce reçu. Dispatch explicite de tests.yml car un push créé par GITHUB_TOKEN ne déclenche pas le workflow push ordinaire. Le reçu REST `workflow_run_id` est utilisé lorsqu’il est disponible ; repli borné sur un nouveau run de ce workflow et de ce SHA seulement, sans ambiguïté et sans accepter un ancien run.

Le job attend `gh run watch --exit-status`, puis vérifie workflow, événement, branche, SHA, statut, conclusion et les sept jobs sans omission ni skipped. main doit encore correspondre au reçu. Succès publié uniquement après ces vérifications. En cas d’échec après mutation, la PR peut déjà être fusionnée : consulter le run et main avant toute reprise ; aucun rollback automatique ni promesse d’annulation.

## Validation et premier essai

Les tests locaux couvrent l’authentification, les commandes malformées/injections, les relances, main rouge/avancé, SHA périmé, refus du gate, dispatch sans mutation pour check, reçu REST, mauvais SHA post-fusion, sept jobs obligatoires et permissions du workflow. Une régression exécute le vrai CLI contre un faux transport gh : avant la garde, une nouvelle tête à CI verte était fusionnée ; après la garde, refus sans requête de mutation. Ce transport de test ne traite aucun jeton réel.

La CI complète de la tête finale et la CI bootstrap post-fusion doivent être vertes avant d’annoncer le système installé. Ensuite l’autre compte Chat peut faire un **premier cd-check sur une PR éligible**, sans autorisation implicite de fusion. Un essai de bout en bout avec vraie mutation devra porter sur une PR distincte explicitement autorisée ; il n’est pas revendiqué par les tests locaux. Une commande check sur une PR fermée ou conflictuelle doit échouer sans fusion, ce qui est un refus attendu.

Si le commentaire du connecteur est attribué à un bot/autre identité, il sera refusé : ne pas élargir l’allowlist pour contourner cette protection. Les comptes n’ont pas de messagerie instantanée ; le message de disponibilité est publié dans #73 pour leur prochaine session.

## Références officielles vérifiées le 1er novembre 2026

- [issue_comment : SHA de la branche par défaut et workflow présent sur cette branche](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#issue_comment)
- [Événements créés par GITHUB_TOKEN et exceptions workflow_dispatch](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)
- [Dispatch REST : ref de branche/tag et reçu de run, version 2026-03-10](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event)
- [Fusion REST : contents write et verrou sha](https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request)
