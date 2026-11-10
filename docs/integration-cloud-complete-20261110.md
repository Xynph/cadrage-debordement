# Réception cumulative Oval Legacy —10novembre2026

## Autorisation et source

Léo demande de réunir les passations et les six chantiers, recevoir la version commune en1440p, exécuter les validations globales, passer le portail officiel et fermer les PR intermédiaires réellement remplacées. La PR cumulative est [539](https://github.com/Xynph/cadrage-debordement/pull/539).

| Référence | SHA réservé | Rôle |
| --- | --- | --- |
| main |5c19a27d4d79cca10813a7a4340383865ff2a9c2 | Base, scènes contextuelles525 et règle critique537 |
| Cloud538 |de8c070c09981e693dc09cd564d28d1c11555282 | Passations, six chantiers, gestion1440, tactique, observation, postes et progression |
| PC527 |b0421b719f9f7f721fe557384d592760d0edb5fe | Trois salles, rendez-vous, staffs complétés, présentation naturelle et CI mesurée |
| Gabi507 |a9963e6f49cf8b7f658216f8dfc1e1556822e9a4 | Modèle V2, manches/carnet, carrure, doigts et articulation |

Les branches sources sont préservées. L’intégration travaille dans `/workspace/work/oval-integration`, séparée de la copie de développement et des fichiers d’assets non suivis qui y étaient déjà présents.

## Inventaire de reprise

Audit indépendant des ancêtres, patch-id et différences sémantiques :

- Ancêtres réels de538 :505,506,508,510,520,529,535.
- Aucun patch produit unique restant :509,511–515,517–519,521–523,526,528,530,532,533,536.
- 524 : de67920→b44da21 et8901a6c→f5bea34 ne diffèrent que par le raccord de présentation salariale. Tri, défilement et rapports non datés conservés.
- 531 : produit repris ; réservation documentaire et ancienne réception enrichies ensuite par la réception canonique.
- 516 : produit repris ; récupérer sa passation `docs/reception-decisions-20261110.md` de bafb81989407010e5adc68ca7816b67e96f56833.
- 534 :3eb3e0e→e7de6d0 est identique ;670bd9b hors règle AGENTS→3f84ba8 a le même patch-id. La règle est conservée puis étendue par527.
- 525 et537 sont déjà fusionnées.527 et GabiV2 contiennent de vrais ajouts absents de538.

Après reçu main et CI post-fusion vérifiés, les PR505–524,526–536 et538 pourront être fermées comme reprises. Aucune suppression de branche n’est prévue.

## Décisions d’intégration

- Conserver les gardes, observations et reçus des trois domaines contextuels, ainsi que le `finally` qui rétablit la délégation. Conserver simultanément les hooks Cloud de connaissance, potentiel, attributs, sauvegardes et calendrier.
- Le résultat post-causerie doit utiliser la même confirmation que l’action publique `finish_round` ; un calendrier quotidien conserve ses jours restants au lieu de clore immédiatement la semaine.
- Une vraie feuille légale de22 reste compatible avec les causeries ; les numéros du banc conservent leur place réelle malgré la place vide17 ou18.
- Conserver l’écran de match contextuel PC avec le Journal, les statuts, motifs et focus du banc Cloud ; ne pas laisser les deux parcours diverger.
- Reprendre les textes naturels PC avec les coûts, risques, inconnues et erreurs utiles ; ne pas restaurer les badges de provenance dans les menus.
- CI : conserver les cinq shards, la limite globale30minutes Cloud et les marges ciblées mesurées PC ; garder la marge délégation300s déjà nécessaire au cumul Cloud. Aucun test n’est retiré pour obtenir un verdict vert.

## État de la réception

En cours : fusion et corrections des raccords. Aucun succès global ni intégration main n’est encore revendiqué. Les commandes, résultats exacts, captures et reçus seront consignés ici avant livraison.
