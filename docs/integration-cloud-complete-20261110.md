# Réception cumulative Oval Legacy — 10 novembre 2026

## Autorisation et source

Léo demande de réunir les passations et les six chantiers, recevoir la version commune en 1440p, exécuter les validations globales, passer le portail officiel et fermer les PR intermédiaires réellement remplacées. La PR cumulative est [539](https://github.com/Xynph/cadrage-debordement/pull/539).

| Référence | SHA réservé | Rôle |
| --- | --- | --- |
| main |5c19a27d4d79cca10813a7a4340383865ff2a9c2 | Base initiale, scènes contextuelles525 et règle critique537 |
| Cloud538 |de8c070c09981e693dc09cd564d28d1c11555282 | Passations, six chantiers, gestion1440, tactique, observation, postes et progression |
| PC527 |b0421b719f9f7f721fe557384d592760d0edb5fe | Trois salles, rendez-vous, staffs complétés, présentation naturelle et CI mesurée |
| Gabi507 |a9963e6f49cf8b7f658216f8dfc1e1556822e9a4 | Modèle V2, manches/carnet, carrure, doigts et articulation |

Le main `de8e3a962625fa828388dc48eb73344695f3b67d` a ensuite été reçu : squashPC527 `a741f98196b5f9a604915d21ea1df381d68b56c8`, puis registre540. Le delta PC final par rapport àb042 concerne uniquement trois fichiers (budget/poids CI et transaction atomique). Les résolutions Cloud sont conservées ; les derniers correctifs PC et le registre partagé sont reçus. CI main42902362083 : sept jobs complets réussis, vérifiés.

Les branches sources sont préservées. L’intégration travaille dans `/workspace/work/oval-integration`, séparée de la copie de développement et des fichiers d’assets non suivis qui y étaient déjà présents.

## Inventaire de reprise

Audit indépendant des ancêtres, patch-id et différences sémantiques :

- Ancêtres réels de538 :505,506,508,510,520,529,535.
- Aucun patch produit unique restant :509,511–515,517–519,521–523,526,528,530,532,533,536.
- 524 : de67920→b44da21 et8901a6c→f5bea34 ne diffèrent que par le raccord de présentation salariale. Tri, défilement et rapports non datés conservés.
- 531 : produit repris ; réservation documentaire et ancienne réception enrichies ensuite par la réception canonique.
- 516 : produit repris ; passation récupérée `docs/reception-decisions-20261110.md` de bafb81989407010e5adc68ca7816b67e96f56833.
- 534 :3eb3e0e→e7de6d0 est identique ;670bd9b hors règle AGENTS→3f84ba8 a le même patch-id. La règle est conservée puis étendue par527.
- 525,527 et537 sont désormais fusionnées.527 et GabiV2 contiennent de vrais ajouts absents de538.

Après reçu main et CI post-fusion vérifiés, les PR505–524,526,528–536 et538 pourront être fermées comme reprises. Aucune suppression de branche n’est prévue.

## Décisions d’intégration

- Conserver les gardes, observations et reçus des trois domaines contextuels, ainsi que le `finally` qui rétablit la délégation. Conserver simultanément les hooks Cloud de connaissance, potentiel, attributs, sauvegardes et calendrier.
- Le résultat post-causerie doit utiliser la même confirmation que l’action publique `finish_round` ; un calendrier quotidien conserve ses jours restants au lieu de clore immédiatement la semaine.
- Une vraie feuille légale de22 reste compatible avec les causeries ; les numéros du banc conservent leur place réelle malgré la place vide17 ou18.
- Conserver l’écran de match contextuel PC avec le Journal, les statuts, motifs et focus du banc Cloud ; ne pas laisser les deux parcours diverger.
- Reprendre les textes naturels PC avec les coûts, risques, inconnues et erreurs utiles ; ne pas restaurer les badges de provenance dans les menus.
- CI : conserver les cinq shards et toutes les suites découvertes. Après les dépassements du run42891746395 et les campagnes locales complètes, recalibrer les poids de planification et les délais finis de chaque campagne. Les nouvelles réserves provisoires sont distinguées des durées mesurées ; aucune erreur ni expiration ne devient un succès.

## Corrections de réception

- Un mandat exclusivement national ne reçoit plus de rendez-vous du club. Les anciennes files restent lisibles sans mutation, les reçus sont conservés et les obligations expirent à la prochaine mutation acceptée.
- La salle de presse transmet l’identifiant réel de son invitation. Le règlement de toutes les salles dans les fixtures passe par les mêmes commandes publiques que le jeu.
- Le renfort des effectifs mesure la couverture par spécialistes, avec les qualifications strictes de première ligne. L’aptitude de dépannage hors poste ne suffit plus à considérer chaque poste couvert.
- Les politiques de progression v2 décident sur le niveau visible et la borne basse de la fourchette de potentiel, sans accéder au potentiel caché. Les archives v1 conservent leur méthode historique.
- La validation des sauvegardes rejette à nouveau une racine nulle dans l’ordre historique, sans accès prématuré à `live`.
- La connaissance calcule le recruteur une fois par projection. Le worker ne répète plus son filtre final après chaque projection intermédiaire ; les modèles bruts restent privés et tous les chemins publics terminent par la frontière de connaissance.

Les fixtures historiques ont été raccordées aux rendez-vous, causeries, qualifications et fourchettes actuels. Les cas de confirmation hebdomadaire redondants de la suite cumulative restent couverts dans les suites contextuelles et causeries. Aucun fichier de suite n’est exclu de la découverte CI.

Les réceptions visuelles ont également corrigé les derniers raccords de présentation : Contrats réutilise les postes principaux canoniques3E L/8 pour ses lignes, filtres, tris et couvertures ; le Bureau affiche les années de fin de contrat. Les anciens libellés source restent recherchables et les données de carrière ne sont pas réécrites.

## Vérifications locales obtenues

Les vérifications suivantes utilisent Node22.23.4 et des profils jetables hors du projet. Elles ne constituent pas encore un verdict global GitHub.

| Périmètre | Résultat constaté |
| --- | --- |
| Parité worker/moteur direct | État/RNG, délégation, refus atomiques, reprises et protocole JSON-lines passent |
| Calendrier et résultat | Deux scénarios cumulatifs common/Monde passent ; 11 contrôles de suites quotidiennes passent sans skip |
| Feuille légale de22 | Parcours réel complet avec numéros de banc, causeries et reprises : PASS237,6s |
| Mandat national | 4/4 : création, ancienne file, changement de mandat, reprise et octets du profil |
| Connaissance/variation pures | 28/28 ; filtre public worker et rapports payants également rejoués |
| Sécurité et compatibilité | Sauvegardes hostiles/hot paths, copies, rollback disque et attributs rejoués |
| Renouvellements v2 | 9/9 avec invitations presse ; politique vérifiée contre des getters cachés qui lèvent une erreur |
| Population, postes et prêts | Profondeur, groupes académie, éditions Monde, benchmark, feuille fiction, effectifs communs, prêts/retours et import/reprise passent |
| Support saison complète | 34semaines,31matchs,90rendez-vous,8contrôles de pureté,9reprises et intersaison : PASS625,906s |
| Optimisations de lecture | Même carrière, tous les stores, RNG3508888936 et horloge1700000000000 que le témoin940,652s ; gain combiné33,46% |
| Interface réelle1440p | Connaissance209/0, Contrats196/0, Calendrier71/0, Bureau59/0, Gabi42/0 et Copies47/0 sous X11 ; Tactique457/0 en headless avec vrais événements et captures graphiques réelles |
| Revue indépendante | Aucun nouveau constat Critical/Important dans les corrections examinées ; réception SDK et CI globale restent des préconditions séparées |

Les poids CI sont des réserves de planification, pas un compte rendu de performance GitHub. La campagne support a réellement dépassé son ancien cap240s. Le nouveau plafond global60minutes garde un délai fini par suite et le verdict bloquant sur toute erreur ou expiration. Les limites de sécurité de la VM restent inchangées.

## Images et limites de réception

[Captures originales et provenance](integration-cloud-complete-20261110/README.md). La longue recette graphique Tactique a dépassé son délai de 300 s au passage en scène3D sous rendu logiciel ; les captures du terrain sont réelles, mais la fin de ce parcours graphique n’est pas déclarée réussie. Son contrat complet de déplacements et verrouillage passe en Godot headless457/0.

La campagne locale académie2saisons a été interrompue par la limite VM15000ms àS1w20, puis une reprise àS2w12. Les rejeux isolés sur copies passent sans modifier la limite : `finish_round`2,955s (VM1,654s), conférence4,107s (VM maximale1,607s). Ces preuves partielles ne remplacent pas la campagne entière ; le verdict complet reste attendu de la CI isolée.

Les postes principaux reflètent actuellement le catalogue ; la famille naturelle des numéros6–7–8 partage ses pondérations. Une inférence plus fine du principal entre aile et centre demanderait des critères sportifs distincts et un versionnement cohérent des couvertures. Aucun badge ou joueur artificiel n’a été ajouté pour satisfaire une fixture.

## État de la réception

En cours : dernières scènes et CI complète sur la tête finale. Aucun succès global ni intégration main n’est encore revendiqué. Le reçu du portail officiel et les sept jobs post-fusion seront consignés dans la description de la PR539 après leur vérification.
