# Mode rapide des PR et batterie horaire sur main (19/11/2026)

Décision de Léo du 19/11/2026 : gagner du temps (avec l'arrêt du train de fusion).

1. PR en brouillon (CI légère), passation dans la description.
2. Prête : passer la PR en prête et activer la fusion automatique en squash. La CI de la PR
   tourne en **mode rapide** : suites JS de poids ≤ 60 s, suites Godot de poids ≤ 20 s (si le
   diff touche Godot) et toutes les suites modifiées par la PR (`ci/shard-tests.cjs`,
   `CD_RAPIDE`). ~10 min au lieu de 35-40. Étiquette `batterie-complete` : batterie complète
   pour cette PR (à poser sur une PR qui change la CI ou un lot sensible).
3. Chaque heure (`tests.yml`, schedule `41 * * * *`), la batterie complète (10 runners JS +
   5 Godot, ~20 min) vérifie `main` ; sautée si ce commit a déjà une batterie horaire verte.
4. Rouge : `main-rouge.yml` relance une fois les seuls jobs en échec ; toujours rouge, il poste
   « MAIN ROUGE » sur #591 (cause : délai dépassé ou assertion, PR fusionnées depuis la dernière
   batterie horaire verte) et, si une seule PR est en cause et que main n'a pas bougé, ouvre sa
   PR de retour arrière avec fusion automatique. Plusieurs PR : pas de retour arrière
   automatique ; corriger main avant toute autre fusion.

Risque accepté : un bug attrapé seulement par une suite longue peut rester jusqu'à une heure sur
main. Poids des suites recalculés le 19/11 sur 8 runs verts (`ci/suite-weights.cjs`, à refaire
quand l'équilibre des shards se dégrade).
