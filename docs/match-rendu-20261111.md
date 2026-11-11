# Rendu du match : réception du 11 novembre 2026

Réception de la PR #545 (Forward+, éclairage, caméra de retransmission).
Captures prises sous Linux avec Godot 4.7.2 et un rendu **logiciel**
(Vulkan `llvmpipe` pour Forward+, OpenGL `llvmpipe` pour le repli). Les
couleurs et les cadrages sont représentatifs ; **les durées ne le sont pas**.

## Planches

- [Jour](match-rendu-20261111/jour.jpg) et [soir](match-rendu-20261111/soir.jpg) :
  caméra TV, caméra action, vue tactique ; avant (`main` `1c83195d`), après
  en Forward+, après en repli OpenGL.
- [Trois niveaux de qualité](match-rendu-20261111/qualite.jpg) en Forward+.

Les 54 mesures (luminance moyenne, part de pixels écrêtés ou bouchés) sont
dans `mesures-avant.json`, `mesures-forward.json` et `mesures-repli.json`.

## Ce que la réception a corrigé

| Constat sur la première version de la PR | Correction |
| --- | --- |
| `tests/godot-match-framing.cjs` échouait : la caméra TV pivotait en suivant le ballon, ce que le test interdit (« Follow camera has no aim snap or roll »). La description de la PR affirmait à tort que les tests n'étaient pas concernés. | Caméra sur rail : elle accompagne le ballon sans pivoter (hauteur 34 m, recul 46 m, champ de 33°). Les lignes du terrain gardent la même orientation, comme dans une vue de manager. |
| Jour délavé : luminance moyenne 0,51 contre 0,31 avant, pelouse pâle. | Exposition 1,12 → 0,80, contraste 1,14, saturation 1,28, brume divisée par deux, part du ciel dans l'ambiance réduite. Luminance 0,45. |
| Soir terne, puis laiteux après une première correction. | Projecteurs 2,25 → 4,4 et plus chauds, ambiance 0,38 → 0,24, exposition propre au soir, saturation 1,5. La pelouse éclairée ressort, les tribunes tombent dans l'ombre. |
| Soir en « Détail » : voile gris, vue tactique bouchée à 32 %. | Densité du brouillard volumétrique 0,012 → 0,0022. Reste 9 % de pixels bouchés en vue tactique, comme en « Économie » (7 %) : ce sont les abords sombres du terrain. |
| Repli OpenGL assombri : jour en « Économie » à 0,14 contre 0,23 avant, soir à 0,05. | Les nouveaux réglages ne s'appliquent qu'en Forward+ (`NativeMatchView.cinematic_rendering()`). En repli, le rendu d'origine est conservé : luminances identiques à l'ancien rendu à 0,01 près, vue tactique identique. |

## Luminance moyenne, niveau « Équilibré »

| Vue | Avant | Après, Forward+ | Après, repli OpenGL |
| --- | --- | --- | --- |
| Jour, TV | 0,31 | 0,45 | 0,32 |
| Jour, action | 0,31 | 0,45 | 0,31 |
| Jour, tactique | 0,35 | 0,40 | 0,35 |
| Soir, TV | 0,15 | 0,27 | 0,15 |
| Soir, action | 0,15 | 0,28 | 0,15 |
| Soir, tactique | 0,18 | 0,19 | 0,18 |

Aucun pixel écrêté en Forward+.

## Ce que cette PR ne règle pas

Le gain vient de la caméra et de la lumière. Les joueurs restent de petits
personnages sans animation de rugby, la pelouse est un aplat et le stade un
assemblage de blocs. Le niveau visé par Léo demande des animations et des
décors : voir `docs/palier-genial-20261111.md` (PR #549).

## Reste à vérifier sur le PC (RTX 4080 SUPER)

1. Images par seconde aux trois niveaux, en 1440p, jour et soir.
2. Premier lancement : Forward+ compile ses shaders au premier match ; à
   comparer aux 28,2 s déjà relevés.
3. L'aspect réel du halo et de l'occlusion, peu visibles en rendu logiciel.
4. Le démarrage forcé en `--rendering-method gl_compatibility`.
5. Le ballon le long de la touche proche : la caméra passe au-dessus de
   l'auvent (calcul : 14,6 m contre 12,8 m), à confirmer à l'écran.

Pour refaire les captures :

```
CD_MATCH_RENDER_PROOF=<dossier absolu> godot --path native/godot \
  --script ../../tests/godot-match-render-capture.gd
```
