# Six prototypes pour Oval Legacy 27

Le lot part du joueur et du stade Godot existants, après la réception de l’export de la PR #427. Les règles, le score et les trajectoires sportives restent définis par la simulation.

| Chantier | Résultat attendu | Réception |
| --- | --- | --- |
| Crochet | Appui gauche ou droit et retour au cycle de course | Rig réel, deux côtés, présence, pause et maintien du ballon |
| Passe | Lâcher, vol et réception sur une passe identifiée | Main de départ, arrivée sur le receveur, refus des cas ambigus |
| Gabi | Réaction silencieuse à la composition | Portrait réel, articulation audio et mouvements réduits |
| Stade | Comparaison jour et soirée sur le stade existant | Fixture graphique à trente joueurs, lisibilité et mesures |
| Ralenti | Lecture web d’une action et avance pas à pas | Provenance de l’action, contrôles clavier et navigateur |
| Banc | Comparaison reproductible d’une célébration et des outils de retargeting | Fixture, mesures brutes et provenance des composants |

Les essais visuels utilisent des profils de recette. La variante de recherche prompt2rig reste séparée des assets distribués et chaque résultat précise les étapes réellement exécutées.

## Où essayer les prototypes

- **Crochet.** Le renderer sait ajouter un appui à gauche ou à droite pendant la course d’un même porteur si le flux 3D décrit le changement de direction. La fixture en fournit deux, vérifie la pose sur le squelette existant, le ballon, la pause et le retour à la course. Le flux de match actuel ne fournit pas cette trajectoire dans ses portées rectilignes habituelles.
- **Passe.** La scène de recette relie la main du passeur, le vol du ballon et les mains du receveur en mouvement. Elle exige deux acteurs explicites de la même équipe et rejette une identification ambiguë. Le moteur actuel ne transmet pas ce couple pour une passe en jeu courant. Le raccord au match reste à faire.
- **Gabi.** Une pose muette de l’atlas existant ponctue la préparation de la composition. Elle se joue une fois, respecte les mouvements réduits et cède la place à l’articulation de la voix.
- **Stade.** Dans la scène de recette, J et S alternent jour et soirée, et 1 à 3 changent de caméra. La même scène conserve trente joueurs. Sur le PC de recette et à 1280 × 720, les deux séries de 120 mesures donnent des temps médians de 1,857 et 1,890 ms et 278 et 280 appels de dessin. Ces mesures décrivent cette scène et cette machine.
- **Ralenti.** [Ouvrir la page hors ligne](../tools/animation-replay/index.html). Le scénario fictif provient du moteur, avec quatre phases, trente joueurs, le ballon, le score et le commentaire. La page interpole les positions entre les instantanés. La lecture et le pas à pas au clavier ont été essayés sous Chrome. Le contrôle Open3D Skills a produit treize captures pour les formats bureau, tablette, mobile et le mode de mouvements réduits.
- **Banc.** [Reproduire la comparaison](../tools/animation-bench/README.md). Le même mannequin sert à comparer une célébration animée à la main à une séquence de points synthétiques retargetée avec prompt2rig. Les mesures portent sur ce mannequin et sur ces entrées.

Avec le SDK Godot 4.7.2 à la racine du dépôt, lancer les scènes de recette sur l’écran secondaire de ce PC avec les commandes suivantes.

```powershell
& $GodotExe --windowed --screen 1 --position 2640,80 --path native/godot --script ../../tests/godot-match-pass.gd -- --demo
& $GodotExe --windowed --screen 1 --position 2640,80 --path native/godot --script ../../tests/godot-match-stadium-evening.gd
```

## Écran de jeu sur PC

Dans **Paramètres → Affichage → Écran de jeu**, choisir un moniteur pour déplacer la fenêtre et mémoriser le choix. Le profil est relu lors de la connexion au moteur, avant l’arrivée sur l’accueil. **Automatique** conserve l’écran du lancement. Le jeu fait de même si le numéro d’écran enregistré est indisponible. Les anciens fichiers de préférences restent lisibles et les données de carrière sont indépendantes de ce réglage.

La recette Windows avec deux moniteurs a vérifié au clavier la sélection, le plein écran, la fenêtre de 1 440 × 900 et un nouveau processus sur le même profil. Sur ce PC, `--screen 1` démarre directement sur l’écran de droite, aux coordonnées (2560, 0).

## Outils essayés

- Le crochet, la passe et le stade emploient les ressources Godot existantes, dont le GLB issu du travail Blender de la PR #427. Ce lot ne contient aucun nouveau clip exporté par Blender.
- Open3D Skills a servi à contrôler les captures du ralenti. Teardown a servi de référence pour la gestion d’une source de temps unique.
- Le banc appelle les fonctions de retargeting de prompt2rig. Les critères de lecture des formats et des tailles s’inspirent de l’audit d’assets de Claude Code Game Studios.
- L’exporteur de Sprite Forge a été testé sur les fixtures du projet amont. Les 26 tests passent. Le portrait de Gabi utilise l’atlas déjà présent dans le jeu.
