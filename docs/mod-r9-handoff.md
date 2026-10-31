# R9 — Contrat final pour première carrière modée (adaptateur, non jeu intégré)

## Etat GitHub observé
R1 PR #97 fusionnée ; les autres PR de mods non fusionnées. L'intégrateur réserve les fichiers centraux `dist/index.html`, `dist/game.js`, `dist/saves.js` et prépare la connexion native. Cette PR est **empilée sur R8 #105**, elle-même sur R7 #104 puis R4 #101. Ne pas fusionner hors ordre.

## Interface livrée à l'intégrateur
`modding/r4/career-bridge.cjs` ne crée aucun gestionnaire. Il reçoit **l'instance canonique R5/R6** et propose deux fonctions :
- `createCareer(world,ids,template,createNativeCareer)` : sélection explicite des mods, construction d'une nouvelle carrière via le callback natif, conservation obligatoire du `modBinding` et retour à la sélection précédente si la création échoue.
- `planResume(world,save)` : une sauvegarde sans `modBinding` retourne vers le monde fictif **sans mutation** ; une carrière modée active seulement ses IDs/version enregistrés et refuse en cas de pack absent, de version divergente ou de liaison invalide, sans laisser un état partiellement changé.

Le jeu doit raccorder ces deux points à la création et à la reprise des carrières **et tester dans le navigateur la persistance effective**. Le bridge ne sauvegarde ni ne charge les données sur disque et ne rend pas le jeu jouable seul.

## Tests et critères de réception
`node tests/mod-r9-career-bridge.cjs` reproduit les entrées/sorties de l'API R5 sans dépendre de fichiers encore non fusionnés. Les tests de bout en bout natifs sont à construire après réception de R5/R6 : installer mod ZIP valide, refuser mod corrompu, ouvrir nouvelle carrière explicitement, fermer, rouvrir même mod/version, refuser mod absent ou version divergente, ouvrir ancienne sauvegarde avec base fictive et constater l'absence de mutation. Ne jamais lancer une carrière modée avec données non validées.

Le jeu fictif doit rester fonctionnel sans mod installé. La publication de contenus tiers, logos et photos exige de vérifier les droits applicables. Pas de contenu réel dans cette PR.
