# Sélection des joueurs : calculs réutilisés pendant un seul appel

Le profil CPU d’une recette Monde place `position-aptitudes.derive` parmi les principaux coûts. Pendant `buildSheet` et `managerSheet`, les mêmes qualités et qualifications sont relues à chaque essai de poste. Ces sélections synchrones ne modifient pas les qualités des joueurs.

Une WeakMap locale à la sélection garde le résultat par objet joueur. Les appels imbriqués partagent ce cadre ; `finally` le libère, même en cas d’erreur. Les contrôles d’invalidation existants restent actifs entre deux appels : entraînement, spécialisation, qualification ou remplacement d’objet. Les poids, règles JIFF, inscriptions japonaises, priorités et algorithmes d’affectation ne changent pas. L’option de comparaison `createBridge({positionMemo:false})` est interne, pas une commande du protocole.

## Vérification et mesure locale

`tests/world-selection-memo.cjs` crée deux vraies carrières world-champ, tous championnats détaillés. Avec et sans cache, il exige les mêmes titulaires/remplaçants, le même état complet après une semaine, la même sauvegarde et le même curseur RNG. Les lectures de qualités sont comptées avec un Proxy retiré avant le chronométrage. Le chronométrage porte sur 250 sélections d’objets ordinaires après 50 échauffements ; il n’est pas un seuil de test.

Recette Node24.22.1, Linux local sous charge :

- 6489 →912 lectures pour une sélection, soit7,1fois moins ; régression rouge avant correction, verte après.
- Dernier échantillon de250sélections ordinaires :1063,4→423,6ms. L’échantillon initial était691,5→483,3ms ; ces mesures partagées varient et ne fixent aucun seuil de vitesse.
- Réception renforcée : le cache est effectivement rempli avant une erreur tardive ; une modification de qualités après l’erreur doit changer la projection. Aucune qualité de joueur World n’est modifiée par ce cas isolé.
- Les deux variantes avancent ensuite jusqu’au vrai match du club et clôturent sa semaine, tous championnats détaillés. Un résultat du club est exigé ; état complet, sauvegarde et RNG restent strictement identiques.
- Durée par variante après création, contrôles de sélection et préparation/match compris :20926,9 et14065,9ms. Ce reçu partagé ne démontre ni un gain garanti de saison ni un gain de FPS.
- Suite complète renforcée :78,08s mesurées jusqu’à la sortie du processus ; maxRSS1935284Kio. Poids90s (+15%), réservation2624Mo (maximum2111236Kio d’une réception intermédiaire +25%), budget300s.

Le premier reçu ne jouait qu’une semaine de préparation sans match : il reste archivé et n’est plus présenté comme preuve de parité après match. Une revue indépendante de la portée du cache, de ses wrappers synchrones et du `finally` n’a trouvé aucun défaut de production ; sa réserve sur l’erreur précoce a conduit au cas tardif ci-dessus.

Provenance et empreintes : `ci/world-selection-memo-mesures-20261115.json`. Les durées sont une mesure locale, pas un run GitHub ; Node 22 et la CI finale restent à recevoir.

Autres contrôles locaux verts sur la source finale : API/positions/qualifications/qualités mutées et projections détachées (27 contrôles), quota japonais réel (9 contrôles), remplacement en direct avec replay exact, sélection du staff Monde (4 cas, dont quelques journées, déterminisme et JIFF). La garde Monde et le rejeu des shards passent. La PR dépend de la migration #742 ; aucune fusion avant mise à jour de main et Validation CI verte.
