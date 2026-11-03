# Accélération intégrée — réception technique, 3 novembre 2026

## Périmètre
Lot coordonné sur une seule branche et PR : optimisation du chemin post-fusion dans le gate historique **et** rééquilibrage des cinq shards, avec tests de sécurité et traces GitHub Actions. Ne touche pas à auto-release (ni ses variables), DATA/LNR, V62, MATCH 3D, moteur ou sauvegardes. Les workflows et le ruleset obligatoires restent inchangés.

## CI post-fusion : supprimer un déclenchement inutile sans supprimer la preuve
Le workflow `tests.yml` démarre automatiquement sur un `push` de `main`. Le gate `ci/chat-release.cjs` déclenchait systématiquement en plus un `workflow_dispatch` après fusion. Désormais, une fois le SHA fusionné obtenu par le gate officiel et vérifié sur `main`, le contrôleur :
1. recherche pendant un maximum de six contrôles espacés de 6 secondes le run `push` de `Tests JavaScript` associé au **SHA exact** et au workflow attendu ;
2. s'il existe, surveille ce run et exige ses **sept jobs terminaux SUCCESS** ; un `push` rouge/annulé/ambigu ne déclenche aucun repli destiné à masquer l'échec ;
3. si aucun run `push` n'a été observé, conserve le lancement `workflow_dispatch` de secours et la vérification exhaustive existante ;
4. revérifie le SHA de `main` avant et après la réception.

Tests positifs/négatifs : SHA et workflow exacts, refus run rouge, repli, absence de second déclenchement quand un push existe, protections et modes check/merge historiques. Aucun nouveau privilège ni contournement du gate officiel.

**Limite** : les deux déclenchements initiaux existaient par configuration ; l'économie effective en minutes de runner doit être confirmée avec les exécutions post-fusion d'une livraison réelle. Si le run push est retardé au-delà de la fenêtre bornée, le repli peut toujours créer une exécution supplémentaire. Une CI rouge bloque la livraison.

## Pondération des shards : deux jeux de 220 suites
Répartition greedy et garantie d'exécution exhaustive conservées. Les pondérations ont été recalculées d'après les durées PASS de deux runs terminaux : CI PR `41708215803` et post-fusion `41709297149`, maximum observé par suite puis marge 15 %, pour les suites dépassant trois secondes. Les tests de rejouabilité contiennent les **440 mesures de suites**, vérifient la couverture complète et comparent la charge critique avec les anciens poids.

Rejeu des mêmes traces, **prédiction** (somme des durées PASS, pas temps réel) :
- run PR : chemin critique ancien 169 s → nouveau environ 141 s ;
- run post-fusion : ancien 170 s → nouveau environ 142 s.

Ces deux traces sont des données d'entraînement : ces gains théoriques ne sont **pas** des gains de CI mesurés indépendamment. Il faut comparer plusieurs runs ultérieurs, sans modifier la couverture ou le niveau d'exigence.

## À mesurer après intégration
- Temps total CI (run_started_at → updated_at) ; temps critique des shards ; somme des durées de suites et P90.
- Nombre de runs `push` et `workflow_dispatch` créés pour un même SHA fusionné, minutes runner et efficacité du fallback.
- Délai création PR → fusion → 7/7 post-fusion.

## Prochaines pistes (non modifiées dans ce lot)
- Distinguer queue runner et calcul réel à partir des timestamps complets ; considérer image Chromium préinstallée / runner éphémère isolé seulement après preuve et étude de sécurité.
- Profiler les simulations longues en gardant scénarios, graines, sauvegardes et règles identiques.
- Évaluer la mutualisation Chromium hors périmètres réservés sans supprimer de réception.
