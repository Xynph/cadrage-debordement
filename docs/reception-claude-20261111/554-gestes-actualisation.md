# PR 554 — actualisation du reçu au head a244814

Réception du 11 novembre 2026 à 15:51 UTC, sans modification du produit,
activation générale, fusion ni arbitrage graphique.

Head reçu : `a244814ee37d4c553faa2c9d61eea4455671a61d`.
Le reçu précédent de `b25c0aabc34dd519432c78ddec813bcec8a664c0` reste historique.
Le delta comporte 17 fichiers : intégration de la touche 555 et modification
de la présentation des temps morts ON. Les empreintes sont conservées dans
[le manifeste source](../qa/experimental-flags-20261111/554-a244814-source.json).
Les arbres moteur et ressources et le lanceur du test gestes sont inchangés.

**Reçue comme expérience OFF par défaut, sur le périmètre Linux mesuré.**
Le test `tests/godot-match-gestes.cjs` a été exécuté sur la copie isolée de ce
head avec Node 22.23.4 et Godot 4.7.2 Linux, headless, audio Dummy, sous mutex
`/tmp/rg27-godot-sdk.lock` : **2/2 tests, 129 contrôles Godot, aucun échec,
aucun saut, 8,193 s**. La fixture du moteur est régénérée et comparée exactement.
Le test exerce les vraies vues OFF puis ON par setter ; la preuve distincte du
trajet d'environnement du reçu précédent reste historique, elle n'est pas
présentée comme une nouvelle exécution à ce head.

Mesures de cette exécution :

- Coupe sur l'alignement à 1,37 s, et sur le renvoi à 14,17 s.
- 30 joueurs mis en place, derniers pas après coupe de 1 s et pointe planifiée
  de 1,500002 m/s ; pointe visible maximale de 7,5 m/s.
- Aucun pas rapide hors écran signalé par le compteur du pilote.
- Caméra TV : taille minimale touche 11,72293 m, maul/essai 11 m ; pas maximal
  de visée 0,02981 m, de taille logarithmique 0,002558, de rotation
  0,00000006323 rad. Taille touche de la caméra action : 11,16689 m.

[Journal TAP complet](../qa/experimental-flags-20261111/554-a244814-gestes.tap).
L'ancienne réserve chiffrée sur les départs à 41,56 m et les courses à 8,94 m/s
décrit b25 ; elle ne doit plus être attribuée à ce head après ces changements.
La nouvelle recette ne constitue toutefois pas un jugement de confort visuel
des coupes, du pivot ou de leur rythme.

Le blob `dist/match2d.js` est exactement celui déjà reçu pour 555,
`20859e027a760ed71d508e6c918f74f147e0c378`. Les six suites et les 80 matchs de
ce reçu sont réutilisés par identité du blob, sans nouveau lot redondant.
Cela couvre la logique et les placements numériques, pas une capture du rendu.

Le GPU, la qualité visuelle, Windows natif et la recette
`godot-match-action-review` ne sont pas qualifiés ici. Aucun résultat sportif
ni règle officielle supplémentaire n'est certifié. Aucune parole Gabi n'est
comptée par cette recette ; le pilote gestes ne crée pas de coach.
