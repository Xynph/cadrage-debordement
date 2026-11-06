# Diagnostic serveur depuis Chat, sans navigateur Work

Après intégration de cette PR technique sur `main`, déposer dans l'issue #73, avec l'identité GitHub Xynph :

```
/cd-diagnose 328 807ac9e6b4b5387888f807df05949f33f2c682cd
```

Le workflow `Chat diagnostic serveur (sans Work)` exécute exclusivement le code de `main` et lit les APIs GitHub authentifiées : ruleset #26326518, état `mergeable_state` de la PR, SHA exact de main, dernier run `push` ou `workflow_dispatch` des sept jobs JavaScript, CI sur le HEAD PR et checks obligatoires. Il publie un reçu dans #73. Aucun droit `contents:write`, aucune mutation PR / branche, aucune fusion.

Un diagnostic VERT n'est **pas** une fusion ni un reçu `CONTRÔLE VERT` officiel. Il faut ensuite soumettre `/cd-check PR HEAD`, attendre le reçu officiel, puis `/cd-merge PR HEAD` seulement si tous les invariants et réservations restent conformes. Les contrôles du gate existant restent inchangés. Un diagnostic STOP est bloquant ; ne jamais contourner les règles ou interpréter `mergeable=true` comme `mergeable_state=clean`.

**Limite :** tant que le diagnostic n'a pas été fusionné sur main, sa commande ne fonctionne pas. Les droits d'accès aux règles serveur et à l'API checks restent soumis aux permissions du token GitHub Actions : si refus, le workflow publie STOP et ne prétend pas avoir réussi. Aucun outil ne garantit qu'aucune tâche future ne nécessitera Work, mais ce circuit supprime la dépendance au navigateur pour ces contrôles lorsqu'il est déployé et validé.
