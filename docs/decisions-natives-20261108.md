# Décisions et formation dans Godot — 8 novembre 2026

Le jeu natif expose les aides déjà calculées par le moteur commun : dossier du
prochain adversaire, préparation collective, besoins par poste, missions de
recrutement, progression et bilan de match. `native/engine/decisions.cjs` construit
une projection de lecture ; les commandes passent par les contrôleurs existants.
La navigation ne tire aucun nombre aléatoire et n'écrit pas la carrière.

## Ce qui devient jouable

- **Préparation** : six domaines de comparaison, joueurs adverses pressentis,
  menaces, faits récents et conseils avec leur justification. Le plan proposé
  s'adopte explicitement ; charge collective et comportement adverse restent
  des choix du joueur.
- **Recrutement** : couverture des quinze postes, échéances contractuelles,
  missions et rapports du recruteur. Une mission annonce ses 5 000 € de coût
  avant confirmation. Les besoins sont des aides de jeu, sans prétendre décrire
  une réglementation d'effectif.
- **Formation** : quinze nouveaux espoirs générés par saison, promotion avec
  salaire annoncé et confirmé, jeunes professionnels et historique des minutes.
  La spécialisation est disponible seulement pour les profils réellement gérés
  par ce système ; elle reste désactivée sur les profils initiaux LNR.
- **Match** : conseils du direct et notes du dernier rapport, interprétation du
  plan utilisé et indicateurs réellement enregistrés. Une corrélation entre plan
  et résultat ne constitue pas une démonstration de causalité.

La page Staff ajoute les responsabilités de sélection et d'entraînement. Les
changements sont refusés pendant un direct incompatible, comme les autres
décisions de gestion. Les estimations de potentiel, salaires et finances restent
des valeurs de simulation.

## Capacité professionnelle

Le plafond historique de 42 empêchait certains effectifs communs, initialement
plus grands, de recruter ou de promouvoir un jeune. La capacité du mode commun
est désormais **l'effectif initial immuable du club + 6, avec minimum 42 et maximum
100**. Les modes historiques conservent 42. Ce choix est une abstraction de jeu,
pas une règle officielle de Top 14 ou Pro D2.

Le même calcul est utilisé par les aperçus, signatures, promotions, besoins et
simulations de relève. Une offre préparée avant la dernière place disponible
revérifie la capacité au moment de sa confirmation. Les prix et barèmes ne sont
pas modifiés. La régénération commune conserve les trente clubs et les 1 592
profils à l'identique ; seule l'empreinte du code de progression change.

## Vérification et limites

Les tests ciblés couvrent les nouvelles commandes, l'invariance de lecture,
les bornes de capacité, la confirmation d'offres devenues périmées, les anciennes
carrières et la reprise. La recette graphique Staff/Formation/Préparation/
Recrutement exerce les vrais contrôles à trois tailles, dont le salaire d'une
promotion. Une campagne de cinq saisons dans chacune des deux divisions reçoit
vingt points de sauvegarde/import/reprise, avec mouvements des clubs et unicité
des joueurs.

La campagne prouve la continuité technique, pas l'équilibrage définitif des
finances ou la difficulté sur cinq ans. Elle ne renouvelle pas chaque joueur
comme le ferait un humain. Le monde reste fermé sans Nationale et la saison
conserve ses 34 semaines abstraites. Aucune nouvelle loi de match n'est ajoutée.

Le [récapitulatif GitHub](idees-github-20261108.md) distingue les fonctions déjà
actives, les écrans nouvellement raccordés et les modules encore absents du
natif. Presse, vestiaire vivant, rivalités et Espoirs avancés demandent encore
des adaptations et validations propres aux trente clubs ; leur présence dans
l'ancien moteur web ne vaut pas intégration Godot.
