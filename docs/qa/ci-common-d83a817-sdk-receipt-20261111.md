# Reçu SDK et petites fenêtres du commit commun

Tête associée : `d83a81747416080abd7be49ef4472c060cacd879`, [PR 566](https://github.com/Xynph/cadrage-debordement/pull/566). [Run SDK réel 43050364671](https://github.com/Xynph/cadrage-debordement/actions/runs/43050364671) : **SUCCESS**, de 15:39:40 à 16:05:44 UTC, le 11 novembre 2026. Les treize étapes de préparation, exécution et clôture sont vertes.

- Douze enregistrements `SDK_RESULT`, tous `passed=true`, sans SKIP accepté. Art07 : 1 516 contrôles / 0, X11 ; contexte : 1 114 contrôles de flow/0 et les cinq sous-suites réussies.
- Matrice P1 principale : **4 337 contrôles, 0 échec**, fin 15:57:05.
- Complément P1 : **1 660 contrôles, 0 échec**, fin 16:04:25.
- Contrats : **3 tests TAP, 3 PASS, 0 échec, 0 SKIP**. Les nombres 169 / 21 des anciens reçus locaux ne sont pas réattribués à cette CI : le journal TAP ne les affiche pas.

Les compteurs locaux 4 330 / 1 648 de la PR géométrie restent des reçus distincts, sur profil préparé. La CI crée son profil frais. Les différences de nombres ne sont pas interprétées comme une cause supplémentaire prouvée ; chaque harnais contrôle son rapport et l’absence d’écriture du profil. Les bornes demeurent180 s par ancien cas SDK ; seule la nouvelle matrice principale CI reçoit480 s, complément720 s et contrats90 s par processus.

Le [JSON voisin](ci-common-d83a817-sdk-receipt-20261111.json) conserve les douze résultats et durées, extraits P1/TAP, l’empreinte du journal décodé complet et la réception API des étapes. Le journal complet a été récupéré avec le connecteur GitHub natif après refus réseau des redirections CLI. Aucun paramètre réseau ni GitHub modifié.

Au gel de ce reçu, les cinq shards JavaScript du [run 43050364420](https://github.com/Xynph/cadrage-debordement/actions/runs/43050364420) sont encore actifs : aucun verdict global JavaScript n’est déduit de ce succès SDK.

Limites inchangées : guide limité au cas layout/native dans le manifeste commun ; autres suites et contextes P1 non couverts explicités dans les rapports source ; aucun EXE Windows reçu sur cette tête. Aucune fusion ni nouveau ZIP/Release.
