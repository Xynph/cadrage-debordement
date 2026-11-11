# Contrats et dialogues dans les petites fenêtres

Réception Linux du 11 novembre 2026, base `96f537040bf9f2e37bf10b0a9b09518b732244a2`.
Correctif de présentation : `e2ded6a8d4f2964ec5b22b68ec84a64b06463569`.

Le minimum de fenêtre de 1540 px et celui du contenu de 1460 px empêchaient
`Dialogs._fit` de réduire la négociation : son affectation de taille était
contrainte par le minimum. Le contenu libère maintenant sa largeur minimale ;
le minimum préparé du dialogue suit l’espace disponible et retrouve sa valeur
préférée lorsque la fenêtre grandit.

## Mesures avant et après

Le débordement est mesuré en pixels à droite de la fenêtre hôte. Les deux modes
recrutement et prolongation sont reçus à chaque résolution, avec une contre-offre.

| Fenêtre | Largeur dialogue avant → après | Débordement dialogue avant → après | Débordement salaire/durée avant → après |
| --- | --- | --- | --- |
| 1280 × 720 | 1540 → 1252 | 260 → 0 | 248 → 0 |
| 1366 × 768 | 1540 → 1338 | 174 → 0 | 162 → 0 |
| 1440 × 900 | 1540 → 1412 | 100 → 0 | 86 → 0 |
| 1920 × 1080 | 1540 → 1540 | 0 → 0 | 0 → 0 |
| 2560 × 1440 | 1540 → 1540 | 0 → 0 | 0 → 0 |

La RED complète produit 36 échecs géométriques attendus. La réception contrats
corrigée contient 10 dialogues et 70 mesures de contrôles, sans débordement.
Les contrôles mesurés sont salaire, durée, reprise de contre-offre, récapitulatif,
prochaine action, autorisation et annulation. Les contrôles du contenu sont
mesurés après défilement vers chacun d’eux.

[Avant 1280 × 720](small-window-contracts-before-1280x720.png) ·
[Après 1280 × 720](small-window-contracts-after-1280x720.png)

Les données détaillées sont dans
[small-window-contracts-evidence.json](small-window-contracts-evidence.json).
Un rectangle est `[x, y, largeur, hauteur]` ; un débordement est
`[gauche, haut, droite, bas]`. Les rectangles des contrôles sont locaux au
dialogue ; `global_rect` donne leur position dans la fenêtre hôte. `dialog`
désigne la surface cliente Godot ; `frame` ajoute la bande de titre, sans les
marges d’expansion du style de bordure. Les PNG montrent également ces bordures.
Leurs limites
visibles croisent celles du dialogue, de l’hôte et du conteneur de défilement.

## Réception partagée

Le second processus vérifie 27 cas et 99 contrôles : confirmation, sélecteur de
fichier en lecture seule et trois onglets du vrai dialogue Paramètres aux cinq
résolutions, puis redimensionnement du même dialogue 2560 → 1280 → 2560.
La relance partagée finale utilise `popup_centered` directement, sans méta de
taille demandée : le minimum effectif passe de 1252 à 1540 px lors du retour
au grand format. Les 27 cas et 99 contrôles sont sans débordement. Cette
relance ciblée vérifie le scénario après son renforcement ; le premier passage
partagé utilisait `show_centered`.

Le fixture appelle les vrais constructeurs `Negotiation.open`, `Preferences.open`
et `Dialogs`, sur un hôte minimal. Il réutilise le mode de mise à l’échelle
désactivé et la densité physique du shell de carrière. Il vérifie le rendu et
la géométrie ; il ne constitue pas une réception du moteur de négociation ou
d’une carrière complète. Aucun bridge moteur ni module Gabi n’est instancié.
Les profils de lancement sont jetables et le pilote audio est `Dummy`.

## Reproduire

Le staging natif et ses imports doivent être présents, comme pour les autres
suites graphiques du dépôt. Les caches et sidecars d’import sont privés au
worktree. Xvfb utilise ici `DISPLAY=:101`, écran 2560 × 1440 × 24 ; rendu X11,
OpenGL Compatibility, Mesa llvmpipe, Godot 4.7.2 et Node 22.23.4.

```sh
DISPLAY=:101 \
CD_GODOT_EXECUTABLE=/workspace/.cloud-setup/tools/godot472/Godot_v4.7.2-stable_linux.x86_64 \
CD_SMALL_CONTRACT_GRAPHICS=1 \
CD_SMALL_CONTRACT_OUTPUT=/tmp/rg27-small-contracts-reception \
/workspace/.cloud-setup/tools/node-v22.23.4-linux-x64/bin/node \
  --test tests/small-window-contracts.cjs
```

La réception complète initiale a passé les deux tests. Après renforcement du
scénario de redimensionnement, la suite partagée a été relancée isolément et
passe également (même commande avec
`--test --test-name-pattern='Shared dialog fitting'`).

Chaque processus prend séparément `/tmp/rg27-godot-sdk.lock` et conserve sa
borne de 90 secondes d’exécution Godot. Les 37 captures et les journaux complets
restent dans `/workspace/qa/rg27-small-contracts-20261111/`. Seules les deux
captures comparatives utiles sont versionnées.

Un premier essai de préparation avait échoué sur des assets de staging absents.
Un autre essai avec 18 frames d’attente par mesure avait atteint sa borne après
neuf captures, sans JSON final : ces essais ne sont pas comptés comme réception.
Les attentes sont ensuite passées à huit frames, la fonction de fit attendant
deux frames. La RED complète et les réceptions corrigées utilisent cette même
attente, avec la borne de 90 secondes conservée.
