# Match3D — qualité native 0.6, 8 novembre 2026

Lot de **présentation partiel**, sur la base `54d67fa9484ea2520c065d0affe96892f7f40dad`. Direction semi-réaliste sobre : gestes et appuis plus lisibles, palette de pelouse moins saturée, matières mates. Aucun résultat sportif, tick, horloge, règle, position source, identité ou attribut de joueur modifié. Aucun format de sauvegarde ni import modifié.

## Changements reçus en headless

- Les déplacements courts démarrent et finissent progressivement. Un nouvel instantané vers la même position ne redémarre plus le raccord ; une trajectoire mise à jour conserve sa vitesse dans les axes compatibles, sans dépasser ses points d'arrivée. Les grandes reformations d'équipe conservent une interpolation plus linéaire pour éviter un pic de vitesse et de caméra supplémentaire.
- La rotation du corps est bornée ; le passage marche/course possède une hystérésis. La cadence du clip dépend de la distance parcourue, sans cadence minimale de course lorsque le personnage avance à peine.
- Les pieds de l'athlète CC0 conservent leur phase de balancement d'origine. Pendant un appui bas et arrière identifié dans cette animation, une correction IK courte stabilise la cheville. Le solveur conserve les deux longueurs de jambe, limite la correction à 24 cm, relâche l'appui en phase aérienne et refuse de le maintenir pendant un pivot rapide ou une très grande translation. Il ne déplace jamais la racine du joueur.
- Un nouveau receveur n'attire plus instantanément le ballon jusqu'à son torse : position et orientation se raccordent depuis le ballon réellement affiché, puis les mains se referment à proximité. Les mises à jour d'un receveur en mouvement ne repoussent pas indéfiniment la réception. Seules les catégories de coup de pied déjà présentes reçoivent un arc visuel.
- Une pause présente directement les points de l'instantané arrêté, sans finir ensuite une marche ou un vol résiduel. Le suivi de caméra, la vue tactique complète et les trois qualités restent conservés.
- La lumière ambiante est moins plate, les ombres de contact plus proches du sujet, les matières peau/chaussures/tissu différenciées par leur rugosité. Les bandes de tonte et le grain de pelouse sont plus discrets ; le grain est désactivé en économie et s'atténue toujours à distance. Aucun nouveau mesh, asset, texture externe ou appel de dessin n'est ajouté par ces réglages.

## Preuves et portée

Les trois suites `godot-match-presentation`, `godot-match-framing` et `godot-match-motion` passent sous le SDK **Godot Windows 4.7.2 en headless**, lancé par Node 22 puis Node 26. Le cadrage couvre 1280×720, 1600×900 et 1920×1080, les trois caméras, les couleurs proches, les changements de qualité, la pause et l'absence/retour du ballon. Les entrées complètes de mouvement et de réception restent identiques après présentation.

Dans la fixture déterministe de mouvement :

| Observation | Base initiale | Candidat 0.6 |
| --- | ---: | ---: |
| Premier déplacement / déplacement en régime de la même marche | 1,000 | 0,063 |
| Première rotation du corps lors d'un demi-tour à 60 Hz | 0,471 rad | 0,120 rad |
| Premier déplacement du ballon vers un nouveau receveur à 60 Hz | 6,252 m | 0,189 m |
| Première rotation du ballon vers un receveur orienté à l'opposé | π rad avant correction ciblée | 0,095 rad |

Le candidat mesure **3,74 mm au maximum entre deux frames d'appui**, sur 150 paires dans la portion de marche droite testée. Ce résultat ne mesure ni tous les pieds bas ni tous les mouvements possibles. Le contact mains-ballon reste inférieur à 21,53 cm pendant la suite de 180 frames et l'écart relatif maximal de longueur de bras observé reste inférieur à 0,000001. Les deux segments de chaque jambe sont également vérifiés avant/après un déplacement de cible IK.

Mesure CPU seule, scène fixe de 30 acteurs, 1 200 frames par qualité, sans rendu GPU : médianes de la base 0,128–0,131 ms, du candidat 0,374–0,400 ms ; p95 de la base 0,149–0,163 ms, du candidat 0,571–0,586 ms. Le supplément d'environ 0,25 ms médian est local à ce matériel et à cette scène. **Ce n'est pas une mesure de FPS, ni une réception sur machine modeste.**

## Réception graphique reproductible

`tests/godot-match-motion-capture.gd` est un harness graphique séparé du moteur. Il prépare trois vues fixes, 120 frames de mouvement à 30 Hz dont 60 PNG conservés, puis des mesures sur la même scène fixe de 30 acteurs dans les trois qualités : médiane/p95 du temps de frame, temps CPU de projection, appels de dessin et primitives. Les 60 images de mouvement se lisent à **15 images/s** pour restituer les quatre secondes simulées.

Depuis la racine du dépôt, après chargement de `E:/Cadrage-Debordement/environnement.ps1` :

```powershell
$env:CD_MATCH_PROOF = 'E:/Cadrage-Debordement/artefacts/native06-20261108/match-graphics'
& $env:CD_GODOT_EXE --path native/godot --script ../../tests/godot-match-motion-capture.gd
```

Ne lancer qu'une recette graphique à la fois. Le harness refuse le mode headless et garde visibles les erreurs d'écriture. Pour comparer le mouvement au même cadrage, `CD_MATCH_VIEW_SCRIPT` peut nommer un ancien `match_view.gd` absolu sans son `class_name` global ; ses ressources `res://` appartiennent alors au projet courant. **Comparer également le terrain et les lumières exige un projet de référence complet**, pas seulement cet ancien script. Le parsing de ce harness a été reçu ; son rendu GPU et ses mesures graphiques restent à recevoir par l'intégrateur.

## Limites assumées et données manquantes

Le référentiel `docs/rugby-rules-reference.md` a été consulté. Ce lot n'applique aucune nouvelle loi. La scène canonique disponible ne contient que catégorie, possession, joueur mis en avant, positions de présentation, origine et ballon. Les formations de `matchScene` ne sont pas des trajectoires physiques mesurées. Elles ne désignent ni plaqueur ni paire de contact. **Aucun plaquage, chute, ruck, maul ou pression à deux corps n'est donc inventé à partir d'une simple proximité.**

Une véritable animation de contact demandera au minimum : identifiants explicites des participants et rôles ; nature et phase de l'action ; point, orientation et chronologie cohérente du contact ; état debout/sol et possession/libération du ballon. Une passe demanderait aussi l'émetteur, le receveur, le départ et l'arrivée attestés. Ces faits devront venir du moteur et de son adaptateur avec une validation distincte ; ce lot ne crée pas ce contrat.

Les grands changements de formation restent des raccords entre instantanés épars. Les demi-tours rapides ne disposent pas de nouveaux clips dédiés de recul ou de pas chassés. Le personnage CC0 et ses proportions, les tenues originales de contraste et l'enceinte générique restent ceux du portage. La validation GPU de la lumière, du grain, des chevilles et des pivots, ainsi que la réception de l'EXE exporté, restent indispensables avant de présenter cette amélioration comme reçue visuellement.
