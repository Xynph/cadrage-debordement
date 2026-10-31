# Proposition de gouvernance : deux intégrateurs, fusions sécurisées

**Statut : PROPOSITION. PAS ACTIVÉE.** Ne pas faire fusionner le compte hors match tant que l'utilisateur n'a pas approuvé la modification de gouvernance, la PR n'est pas intégrée et les protections distantes de `main` ne sont pas réellement activées et vérifiées.

## État constaté
- Le dépôt dispose déjà de `ci/release-gate.cjs` : contrôle état de PR, SHA de tête, Tests JavaScript et job Validation CI, puis fusion squash avec condition SHA de la PR.
- Cette condition protège le **SHA de la branche PR**, **pas le SHA de main**. Deux PR peuvent réussir leurs tests avant qu'une première fusion change main. Les commentaires de l'issue #73 ne sont pas des verrous atomiques.
- Les droits du connecteur disponibles ici ne permettent ni de consulter la configuration de protection des branches ni d'installer des rulesets. Il est impossible d'affirmer que ces protections existent.
- La PR #74 a été intégrée dans `main` (relevant `AGENTS.md`). L'issue #73 est ouverte.

## Activation obligatoire côté propriétaire GitHub
1. **Settings > Rules > Rulesets** (ou Branch protection rules selon interface). Cibler `main`, interdire les push directs, suppressions et force-push, exiger des PR et des vérifications réussies **à jour sur la branche cible** ; imposer explicitement le contrôle `Validation CI` du workflow Tests JavaScript. Autoriser le *merge queue* si disponible : il teste la combinaison de la PR avec la dernière version de main et sérialise les mises en production.
2. Activer la protection **pour les administrateurs**, **aucun acteur de contournement**. Vérifier les règles réellement appliquées ; s'il existe un accès administrateur contournant les contrôles, la garantie n'est pas assurée.
3. Ne pas autoriser les deux comptes à employer la commande de fusion avant que la configuration soit prouvée. Les jetons/connexions des deux comptes doivent avoir seulement les droits nécessaires ; ne jamais partager de secrets dans l'issue.
4. Les workflows doivent exiger CI sur le **dernier SHA de la PR**, et `main` à jour. Pour une PR contenant un changement de sauvegarde : tests de reprise/validation des anciennes carrières ; pour le code sportif : règles rugby et tests de match.
5. **Après changement de main**, rebaser/actualiser la seconde PR puis relancer la CI. Une CI verte datant du main précédent ne suffit pas.

## Workflow par compte
- Prise de chantier sur l'issue #73 : fichiers exacts, branche, SHA de `main`, liens PR, statut.
- Développement sur branches différentes et petites PR séparées. Si chemins se recouvrent : arrêter et se coordonner.
- Avant fusion, convertir la PR de *draft* à *ready for review* après revue ; vérifier les protections, dernier SHA, `Validation CI`, tests sauvegardes et état `mergeable_state=clean`.
- La fusion doit passer par **la merge queue GitHub si disponible**, autrement par le mécanisme GitHub de fusion protégé et `ci/release-gate.cjs` avec contrôle du SHA actuel. L'issue #73 n'est **jamais** le mécanisme de verrouillage ; seule la protection GitHub appliquée au moment de la fusion peut rejeter une course.
- Après la fusion, vérifier le workflow `push` sur le commit fusionné et publier une passation avec SHA et liens.
- En cas de CI manquante, protection inaccessible, PR devenue obsolète, check incomplet ou conflit : **STOP, ne pas fusionner**.

## Outil de politique proposé
`ci/dual-merge-policy.cjs` permet de tester sur des snapshots structurés qu'une fusion est interdite si les protections exigées ou la CI ne sont pas vérifiées. **Il ne modifie pas GitHub, n'installe pas de ruleset, ne verrouille pas main et ne réalise aucune fusion**. La CI de cette PR vérifie les scénarios négatifs. Le vrai verrou reste une protection serveur de GitHub et, de préférence, sa merge queue.

## Risques résiduels
- Une vérification du main par script puis une fusion REST ne constituent **pas une opération atomique**. Sans protection serveur stricte, deux comptes pourraient tous deux fusionner après la même vérification.
- Une merge queue nécessite la configuration GitHub adaptée. Les workflows de tests doivent alors être compatibles avec les événements `merge_group` si GitHub l'exige ; ne pas activer la queue sans vérifier cette compatibilité.
- Les fusions de deux PR sans conflit de fichiers peuvent quand même casser une logique commune. Les tests d'intégration restent indispensables.
