# Fusion ordinaire contrôlée

L’intégrateur désigné utilise le compte GitHub **Xynph**. Après arbitrage des réservations actives et revue du diff, il sélectionne **une PR et son SHA HEAD complet** dans Actions → **Fusion ordinaire contrôlée** → Run workflow, sur la branche `main`. Le lancement sélectionne une livraison au titre de l’accord général de Léo.

```sh
gh workflow run auto-release.yml -R Xynph/cadrage-debordement --ref main \
  -f pr=NUMERO -f sha=SHA_HEAD_COMPLET -f mode=check
```

`check` vérifie la sélection en lecture seule. `merge` demande un squash immédiat si les contrôles sont verts. Attendre le verdict terminal de la CI de la PR avant de lancer la commande. Le résumé GitHub Actions indique le résultat et, après une fusion validée, le lien vers la CI du commit fusionné. Une relance du run est refusée. Si une tête, une base ou une CI change, revoir la sélection et lancer une nouvelle demande.

## Périmètre initial

La PR doit être prête, ouverte par Xynph depuis le même dépôt, à jour sur `main` et fusionnable. Le diff complet comporte au plus 12 ajouts ou modifications de fichiers réguliers. Le périmètre couvre les chemins suivants.

- Documentation de présentation dans `docs/ui-presentation-*.md` et modifications des quatre guides UI listés dans le contrôleur.
- Modifications des feuilles de style existantes `dist/style.css`, `dist/main-menu-v3.css`, `dist/ui01-integration.css`, `dist/ui02-player-components.css`, `dist/ui03-scout-components.css` et `dist/ui04-academy-components.css`.

La voie sensible reste celle du [gate officiel](chat-release-gate.md). La fusion ordinaire refuse les recouvrements avec les PR prêtes ouvertes vers `main`, y compris l’ancien chemin d’un renommage. Elle parcourt les pages, avec refus si la liste ou un diff dépasse la limite vérifiable ou change en cours de contrôle. L’intégrateur arbitre les brouillons actifs et travaux réservés avant le dispatch. Cette vérification observe des instantanés GitHub successifs.

## Contrôles et activation

Le workflow exécute exclusivement le code du SHA de `main` à l’origine du dispatch. Il exige le ruleset de PR avec `Validation CI` stricte émise par GitHub Actions et la CI du HEAD exact. Une PR documentaire peut avoir la matrice JS ignorée si `classification` et `Validation CI` réussissent. Une PR CSS exige les sept jobs JavaScript verts et le job Chromium mutualisé réussi. Le dernier run de chaque autre workflow de PR visible sur la même tête doit aussi réussir.

Avant le squash, le gate officiel vérifie de nouveau le HEAD, la base et le run JS, tentative comprise. GitHub applique les protections serveur et compare le SHA au moment du squash. Le workflow exige sept jobs verts sur le `main` initial puis sur le commit fusionné. Si GitHub ne crée pas le run `push` après la fusion au `GITHUB_TOKEN`, le gate déclenche une seule CI de secours sur `main` et en vérifie le SHA. Un échec après squash demande une inspection du commit et de sa CI avant la demande suivante.

L’intégration de ce code ouvre le mode `check`. Le mode `merge` exige la variable de dépôt `CD_ORDINARY_MERGE_ENABLED=true`. Avant de l’activer, vérifier les protections de `main` sans bypass, les permissions effectives du `GITHUB_TOKEN` pour le squash et le dispatch de CI, puis exécuter `check` sur une PR témoin isolée sous `docs/ui-presentation-*.md` et sur un cas de refus. Activer le flag pour la fusion témoin, puis vérifier le reçu GitHub et la CI complète du SHA fusionné. Retirer le flag si le témoin échoue. L’activation ne nécessite aucun changement de l’auto-merge natif de GitHub.

Le dispatch remplace la fusion par étiquette `cd-integrate` et le prototype déclenché par fin de CI. Les variables de l’ancien prototype n’ont plus d’effet.
