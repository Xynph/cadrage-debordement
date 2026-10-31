# R1 — Base fictive et système de mods séparés

Le jeu de base doit être entièrement fictif. R1 fournit un **jeu d'essai fictif** de deux compétitions (14 et 16 clubs) sous des noms inventés, sans logos ni identités réelles. Ce catalogue de démonstration ne représente pas les participants réels 2026/27. Les joueurs, jeunes et staffs restent vides et seront initialisés par le moteur futur ou des données fictives originales.

Le schéma versionné, les identifiants stables, les références entre entités, les rôles et postes, les dates, la provenance et les contrôles des droits sont conservés. Exécution : `node tests/world-catalog-r1.cjs` puis `node tools/world-import.cjs world-data/r1/fr-2026-2027.json`.

## Architecture cible
- **Jeu de base** : univers inventé entièrement fonctionnel sans packs.
- **Mod extérieur facultatif** : paquet de données isolé, identifié, versionné et activé explicitement par le joueur. Aucun vrai nom, photo, blason, effectif ou calendrier réel n'est embarqué par défaut.
- **Contrôle des droits** : la séparation en mod n'accorde aucun droit de reproduction ni de redistribution. Un mod réel ne doit être diffusé qu'avec les autorisations et licences nécessaires ; sinon, concevoir un importeur privé alimenté par des données légitimement détenues par l'utilisateur.
- **Sauvegardes** : garder les carrières historiques inchangées ; une future carrière avec mod stockera son ID et sa version pour prévenir toute substitution involontaire.

R1 n'est pas encore raccordé à `dist/`, et n'ajoute aucune donnée réelle. Les travaux futurs doivent créer l'installateur/validateur de mod et le moteur multi-ligues sans altérer les sauvegardes existantes.
