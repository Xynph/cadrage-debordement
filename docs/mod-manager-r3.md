# R3 — Atelier de mods indépendant

R3 ajoute un chargeur navigateur/Node pour mods JSON et ressources PNG/JPEG/WebP. Il vérifie les chemins relatifs, signatures binaires, tailles et SHA-256 réel des images, avec import explicite. Le gestionnaire garde l'univers fictif séparé, active ou désactive un mod sur demande et fournit une signature de sauvegarde versionnée.

**Important :** ce code n'est pas encore raccordé à l'interface du jeu. Il ne change aucune sauvegarde actuelle et ne livre aucun contenu réel. Le branchement graphique et le stockage persistant requièrent l'intégrateur, après la fusion de R1 et R2.

Test cible : `node tests/mod-manager-r3.cjs`. Les fichiers de mods sont des données, jamais des scripts exécutables. La vérification des droits des ressources externes relève de la distribution des packs.
