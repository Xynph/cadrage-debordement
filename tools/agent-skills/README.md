# Kit de compétences des agents

Compétences tierces mises à disposition des agents qui travaillent sur le
dépôt. Elles sont copiées à l'identique dans `.claude/skills` et
`.agents/skills`, épinglées par commit et décrites dans `manifest.json`.
Elles ne font pas partie du jeu distribué.

| Commande | Effet |
| --- | --- |
| `node tools/agent-skills/update.cjs --check` | Vérifie hors ligne que les deux dossiers correspondent au manifeste. |
| `node tools/agent-skills/update.cjs --commit <sha40>` | Télécharge la source à ce commit, recopie les compétences listées et réécrit les empreintes. |
| `node tests/agent-skills-kit.cjs` | Contrôle exécuté par la CI. |

Pour ajouter une compétence de la même source, ajouter son `name` et son
`path` dans `manifest.json`, puis relancer la mise à jour sur le commit voulu.
Seuls des fichiers Markdown sont acceptés ; aucun script tiers n'est exécuté.

Avant de valider une mise à jour, relire le diff : une compétence est une
consigne donnée aux agents. Inscrire toute nouvelle source dans
[le registre des ressources](../../docs/ressources-utiles.md) avec sa licence.

Une compétence écrite pour le projet peut vivre à côté, dans un dossier dont
le nom ne figure pas dans le manifeste : le contrôle ne la touche pas.
