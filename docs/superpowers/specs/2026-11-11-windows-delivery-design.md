# Livraison Windows vérifiable — conception du11novembre2026

Demande de Léo : poursuivre en autonomie jusqu'à une livraison comprenant intégration539/543, CI exacte, gate, reçu main, véritable ZIP Windows reçu sur runner Windows gratuit, puis publication des preuves. Budget externe0€.

## Choix de réalisation
- Réutiliser le constructeur officiel scripts/build-godot-prototype.py et qa_runner.gd embarqué. Aucun faux EXE, repli sur un Node système ou reçu déduit d'un ancien paquet.
- Standard windows-2022 dans le dépôt public. Godot4.7.2 et Node22.23.4 avec versions, SHA et notices figés. Mesa26.2.6 pour la copie QA graphique uniquement, avec ses notices inspectées ; jamais ajouté au ZIP livré.
- Une recette ciblée Windows dans543 prépare la version commune. Une seule campagne globale Node sera ensuite exécutée dans539 ; contrôle après fusion séparé obligatoire. Les corrections concurrentes ont été comparées avant reprise.
- GitHub Releases en brouillon pour ZIP, rapport et captures ; aucune nouvelle utilisation de upload-artifact, cache Actions, LFS, Packages ou runner élargi. Publication du brouillon uniquement après recette et vérifications du gate.
- Le jeu garde Gabi verrouillé sans WAV/TTS, pilote audioDummy pendant les essais.
- Les profils QA sont jetables, extérieurs au jeu et aux profils du compte. Les comptes GitHub et jetons ne sont pas transmis au jeu.

## Périmètre des reçus
La recette fraîche embarquée doit atteindre une saison complète et S2 avec les vrais matchs, jours, rendez-vous et citations. Un pilote SceneTree embarqué dans le véritable EXE exporté charge ensuite le profil existant, vérifie l'état et les citations avant toute nouvelle décision, puis capture les écrans réels en2560×1440.

Les templates officiels Godot 4.7.2 ignorent `--script`. Les classes de recette et leur scène d'entrée vide sont donc copiées avant import/export. Un `override.cfg` ajouté seulement à la copie QA sélectionne ces classes ; il est hashé dans `qaExtras`, interdit dans le ZIP et stable entre fresh et resume. SELF_TEST=1 délègue à l'unique qa_runner intégré ; SELF_TEST=0 conserve la comparaison pure du profil avant de créer main.tscn. Les modes graphics/resume doivent émettre sous 15 secondes un ACK liant mode, scripts embarqués, scène d'entrée, PID, EXE et profil, contrôlé avant l'attente longue. Un accusé absent ou divergent est un échec, jamais une preuve graphique.

Le ZIP original et tous les fichiers de son manifeste sont contrôlés avant/après les essais. Une éventuelle DLL Mesa dans la copie QA est identifiée, hachée et déclarée séparément ; aucun fichier du jeu n'est remplacé.

Le rapport lie commit, arbre source, outils, EXE, Node embarqué, ZIP, manifeste, processus, profils, résultats et images. Headless ne constitue pas une réception graphique. Les exemples/fixtures de tests unitaires ne constituent jamais une recette Windows.

## Contraintes de publication
Les reçus PC543 portent sur3b42dbf2/0dad et restent historiques. Les nouveaux reçus portent sur le nouveau paquet.
Les lots545/546/549 restent séparés selon l'ordre demandé. Le contenu public du paquet est vérifié avant publication ; le retrait complet des identités prévu par549 n'est pas réputé réalisé. Aucun pack Rugby Réel local ne doit être ajouté aux assets publics.

Léo a explicitement demandé l'exécution autonome ; les choix techniques ci-dessus sont des choix de réalisation, sans nouvelle demande d'approbation.

