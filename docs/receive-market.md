# Réception du marché interclubs immersif — 9 novembre 2026

Le parcours Recrutement immersif remplaçait la vue classique sans reprendre son entrée du marché sous contrat. Le bandeau de recrutement propose désormais « Marché entre clubs → » à côté de « Repérer la relève → ». Les deux boutons conservent la surface disponible du bandeau, sans chevaucher les onglets ni les filtres. Ils ouvrent les dialogues de production existants ; aucune règle de transfert, donnée économique ou sauvegarde n’est modifiée.

## Vérifications réelles

Le test `tests/godot-immersive-interclub.cjs` lance `main.tscn` avec le vrai worker Node, une carrière commune et un profil temporaire hors application. Il navigue vers Recrutement en 1920 × 1080, puis redimensionne ce canvas immersif en 1280 × 720. La navigation fraîche en 720p utilise la vue compacte historique, qui possède déjà ses entrées dans l’onglet des missions ; le présent test cible la régression du canvas immersif.

Avant correction : 12 contrôles, deux échecs correspondant à l’absence du bouton aux deux définitions. Après correction : **58 contrôles, zéro échec**, Godot 4.7.2 / Node 22.23.4 Linux, sans fenêtre. Les clics souris passent par les événements Godot et ouvrent les vrais dialogues du marché et de la relève. Le test vérifie la visibilité, les libellés entiers, l’absence de chevauchement et le dessin des boutons au-dessus du voile décoratif, les candidats du worker, l’export et les octets du profil inchangés.

Commande :

```sh
CD_GODOT_EXECUTABLE=/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64 /workspace/.cloud-setup/tools/node22/bin/node --test tests/godot-immersive-interclub.cjs
```

Preuve locale headless : `/tmp/cd-immersive-interclub-m4l8fq/godot.log`.

Avant le déplacement des boutons au-dessus du voile décoratif, une exécution graphique X11/llvmpipe a produit quatre captures et terminé ses **58 contrôles fonctionnels sans échec**. Le runner graphique reste en échec car cette machine ne dispose pas de `libspeechd.so.2` et Godot signale `Parameter "synth" is null` à l’initialisation de la voix système. Cette erreur n’est pas filtrée par le test. Les captures de recrutement et du dialogue en 1080p/720p sont sous `/tmp/cd-immersive-interclub-d6dfkn/` ; la capture de recrutement 720p a été inspectée visuellement, avec les deux libellés visibles et séparés. Aucune recette Windows ni écoute audio revendiquée.

Relecture indépendante du raccord d’analyses Monde dans `club_canvas.gd` : insertion bornée de la vue existante dans la liste défilante des archives, style Legacy appliqué, sans calcul ni mutation supplémentaire ; aucune objection à ces quatre lignes.
