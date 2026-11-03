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

## Pondération des shards : trois profils de CI
La stratégie greedy et la couverture exhaustive restent inchangées. Les poids proviennent désormais de **trois** runs terminaux : CI PR `41708215803` (220 suites), post-fusion `41709297149` (220 suites), nouvelle PR `41715682628` (221 suites, dont le test de profilage). Le maximum par suite est majoré de 15 %. Le test de rejeu compare les 220 suites communes sur trois profils.

Le premier recalibrage fondé sur deux exécutions était **suradapté** : sur la nouvelle PR, le shard critique réel a duré 221 s, contre 189 s sur le run précédent. Une suite V63 est passée de 62 à 109 s. Cette régression observée ne démontre pas à elle seule un défaut d'ordonnancement, car charges et runners varient ; elle invalide en revanche toute annonce de gain durable fondée sur deux traces.

Le deuxième recalibrage inclut le troisième profil. Simulation de charge (somme des durées des suites, hors overhead, **pas un gain mesuré**) avec les ensembles de 221 suites : anciens poids → nouveaux poids : environ 167→151 s, 167→163 s, 179→164 s, selon le run. Les mesures doivent être reproduites sur de nouveaux runs indépendants.

## À mesurer après intégration
- Temps total CI (run_started_at → updated_at) ; temps critique des shards ; somme des durées de suites et P90.
- Nombre de runs `push` et `workflow_dispatch` créés pour un même SHA fusionné, minutes runner et efficacité du fallback.
- Délai création PR → fusion → 7/7 post-fusion.

## Prochaines pistes (non modifiées dans ce lot)
- Distinguer queue runner et calcul réel à partir des timestamps complets ; considérer image Chromium préinstallée / runner éphémère isolé seulement après preuve et étude de sécurité.
- Profiler les simulations longues en gardant scénarios, graines, sauvegardes et règles identiques.
- Évaluer la mutualisation Chromium hors périmètres réservés sans supprimer de réception.
