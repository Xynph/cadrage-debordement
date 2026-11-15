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

## Empreinte relue entre deux appels

Un nouveau profil de15s sur les3000expériences de pénalité place derive à21,3%de temps propre, efficiency5,5% et activePlayers8,45%. La portée de sélection ne supprime pas les contrôles entre les appels de projection. Ce chemin continue à comparer les onzequalités et onzebonus ; il consulte leurs objets skills/spécialisation une fois par appel, avec le même calcul version1/bonuses[k]||0 que focusedBonus et roleNote. Aucun champ de clé ni contrôle d’invalidation supprimé, aucune nouvelle durée de cache. Le chemin de référence positionMemo=false garde la boucle originale.

Régression instrumentée rouge2200/2200 puis verte2200→100accèsdev. Les projections restent identiques après mutation surplace, remplacement de bonus, changementde version et suppression ; une spécialisationactive sans objetbonus reste refusée. Revue indépendante du calcul et de l’invalidation : aucun défaut source trouvé. Node22.23.5 :27contrôlesAPI verts et parité complète des deux vraiesWorld/S/store/RNG/feuille après semaine de match,79,4s internes/maxRSS2065704Kio.250sélections ordinaires :1121,3→676,0ms ; échantillon partagé seulement, pas seuil de vitesse ni mesure de saison/FPS. Poids93s (durée interne+1s de réserve de démarrage puis15%), budget300s inchangé.

Cette optimisation devient une dépendance de la réceptionMonde#742 : une campagne de12ans a coûté2929s avant une assertion finale de rejet à corriger. Le portage dans#742 recevra de nouveau la parité sur sa cible exacte. Aucune fusion main ni CI verte revendiquée pour le brouillon#744.

Port complet sur#742 reçu, Node22 : étatWorld/sauvegarde/RNG/feuille identiques et vraie semaine de match,88,86s process/2111968Kio. Le compteur reste2200→100. Sous cette charge,250sélections581,9→744,4ms : aucune accélération chronométrique générale n’est établie par ces échantillons. Le bénéfice prouvé est la réduction des accès à données identiques, avec contrôles exacts conservés. Poids103s et mémoire2624Mo, budget300s. Le code de#744 rejoint le chantier#742 avant sa recette finale ; le brouillon#744 reste une trace de revue, pas une fusion principale indépendante annoncée.
