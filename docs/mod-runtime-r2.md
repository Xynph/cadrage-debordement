# R2 — Mods optionnels et univers séparés

R2 développe un **noyau de gestion de mods indépendant** du jeu de base. Aucun `dist/**`, fichier de sauvegarde historique, interface ou moteur rugby n'est modifié. Ce lot est une fondation exécutable/testable, **pas encore un installateur graphique**.

## Paquet JSON
Un paquet comprend `manifest` et `files` (collections JSON explicites), avec `schema:1`, `id`, `version`, `title`, `kind`, `baseGame:1`, `data` et `assets`. Champs optionnels `dependencies`, `conflicts`, `license`. Les collections supportées sont compétitions, clubs, joueurs, staff, académies, calendrier. Les assets déclarés acceptent logos de clubs et compétitions, portraits de joueurs et staffs, photos des stades, avec chemin relatif, taille, SHA-256. **Le noyau ne télécharge pas les fichiers et n'exécute pas de scripts du mod.** Les images réelles ne sont pas intégrées ici.

## Sécurité et isolation
- Entrées non déclarées, chemins absolus, traversal, caractères de contrôle indirects, répertoires cachés, identifiants dupliqués et collisions sont rejetés.
- Limites d'inventaire et de taille de ressources ; contrôle du SHA déclaré. **La vérification du contenu binaire et des dimensions d'image reste à raccorder au futur chargeur de fichiers.**
- `createRegistry(base)` conserve une copie indépendante du jeu fictif. Installation sans activation, activation explicite, désactivation rétablissant l'univers fictif, contrôle des dépendances et conflits.
- `saveBinding()` renvoie `{schema:1,mods:[{id,version}]}`. `checkSave(binding)` refuse une version ou liste divergente. Aucune sauvegarde actuelle modifiée : l'intégrateur doit raccorder cette liaison à un **nouveau format versionné** de carrière avant que les parties modées soient jouables.
- Aucun URL externe exécuté, pas de chargement HTML, CSS ou JavaScript depuis un mod.

## Limites et R3
Les données sont des collections isolées et ne sont pas raccordées à `dist/index.html`. L'API vérifie des IDs et noms, mais la validation référentielle complète inter-collections (saisons, calendriers, propriété des joueurs, compatibilité sportive) appartient au raccordement du schéma R1. Les photos demandent un futur chargeur binaire avec vérification SHA réelle et types MIME, sans exécution de SVG actif.

Prochaine étape R3 : raccordement à la logique de carrière via adaptateur de compétition, choix de l'univers à la création d'une **nouvelle** carrière, gestion UI des packs, stockage disque portable isolé et tests d'anciennes sauvegardes. Toute redistribution de contenu doit disposer des droits applicables.

Test : `node tests/mod-runtime-r2.cjs`.
