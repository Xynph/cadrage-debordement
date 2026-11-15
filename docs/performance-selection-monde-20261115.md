# Sélection des joueurs : calculs réutilisés pendant un seul appel

Le profil CPU d’une recette Monde place `position-aptitudes.derive` parmi les principaux coûts. Pendant `buildSheet` et `managerSheet`, les mêmes qualités et qualifications sont relues à chaque essai de poste. Ces sélections synchrones ne modifient pas les qualités des joueurs.

Une WeakMap locale à la sélection garde le résultat par objet joueur. Les appels imbriqués partagent ce cadre ; `finally` le libère, même en cas d’erreur. Les contrôles d’invalidation existants restent actifs entre deux appels : entraînement, spécialisation, qualification ou remplacement d’objet. Les poids, règles JIFF, inscriptions japonaises, priorités et algorithmes d’affectation ne changent pas. L’option de comparaison `createBridge({positionMemo:false})` est interne, pas une commande du protocole.

## Vérification et mesure locale

`tests/world-selection-memo.cjs` crée deux vraies carrières world-champ, tous championnats détaillés. Avec et sans cache, il exige les mêmes titulaires/remplaçants, le même état complet après une semaine, la même sauvegarde et le même curseur RNG. Les lectures de qualités sont comptées avec un Proxy retiré avant le chronométrage. Le chronométrage porte sur 250 sélections d’objets ordinaires après 50 échauffements ; il n’est pas un seuil de test.

Recette Node 24.22.1, Linux local :

- 6 489 → 912 lectures pour une sélection, soit 7,1 fois moins ; régression rouge avant correction, verte après.
- 250 sélections : 691,5 → 483,3 ms, environ 30 % de temps en moins sur cet échantillon.
- Sélection + semaine dans les variantes : 7 035,8 et 7 097,3 ms. Ce reçu ne démontre pas un gain sur une semaine entière, une saison ou les FPS.
- Suite complète : 52,8 s ; maxRSS kernel 1 977 772 Kio. Poids 61 s (+15 %), réservation mémoire +25 %, budget 300 s.

Provenance et empreintes : `ci/world-selection-memo-mesures-20261115.json`. Les durées sont une mesure locale, pas un run GitHub ; Node 22 et la CI finale restent à recevoir.

Autres contrôles locaux verts sur la source finale : API/positions/qualifications/qualités mutées et projections détachées (27 contrôles), quota japonais réel (9 contrôles), remplacement en direct avec replay exact, sélection du staff Monde (4 cas, dont quelques journées, déterminisme et JIFF). La garde Monde et le rejeu des shards passent. La PR dépend de la migration #742 ; aucune fusion avant mise à jour de main et Validation CI verte.
