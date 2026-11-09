# Visages automatiques dès le centre de formation

L’interface compacte et le canevas immersif utilisent le même portrait pour un académicien identifié. Le helper immersif appelle désormais `game_skin.portrait` pour les vignettes, les dossiers et l’encadrement identifiés : photo valide du pack en priorité, composition locale fictive sinon. Le grand portrait composé porte un badge explicite. Une illustration générique reste réservée aux emplacements sans identité.

Le visage provient de l’ID stable, sans dépendre du nom ou du club. La promotion publique conserve cet ID et le profil de portrait. La reconversion emploie `sourcePlayerId` pour conserver la même origine visuelle ; le vieillissement illustratif peut évoluer. Les éléments IA sont prégénérés : aucune requête réseau ni inférence locale, aucune unicité visuelle garantie.

Plan exécuté : reproduire le défaut en Godot sur un vrai académicien ; corriger uniquement `_portrait` ; vérifier les branches compactes/immersives, les packs imbriqués et absents, la promotion réelle et l’absence de mutation par l’affichage. Le test de reconversion vérifie le contrat de descripteur sans simuler une carrière entière.

Recette : après staging officiel puis import Godot 4.7.2, lancer `CD_GODOT_EXECUTABLE=… node --test tests/godot-academy-portraits.cjs`. Ajouter `CD_ACADEMY_GRAPHICS=1` dans un environnement X11 équipé pour produire les captures 1280/1920. Le test emploie un profil temporaire et vérifie sauvegarde, RNG et fichier inchangés par la consultation.

Réception Cloud du 9 novembre 2026 : 56 contrôles Godot sans fenêtre, 58 en X11 avec captures visionnées, et 5 tests Node des portraits réussis. Godot 4.7.2, Node 22.23.4, rendu Mesa logiciel ; aucun test Windows natif annoncé.
