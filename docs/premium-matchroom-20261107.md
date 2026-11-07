# Salle de match Premium — 7 novembre 2026

## Intention
Poursuivre la refonte autorisée sur le vrai jeu PC. Sur main f1bd6c6, les quatre boutons du direct ne changent que l'accent visuel ; un ensemble de 2 864 px repousse le terrain sous les conseils. Le terrain, le score et la pause doivent être immédiatement visibles à 1440×900 et 1920×1080. Les autres outils doivent devenir des pages utiles et accessibles.

## Composition retenue
Adapter la couche premium-editorial, sans modifier le générateur natif ni le moteur. Terrain : rendu 2D/3D existant et commentaire natif côte à côte. Effectif : les deux listes natives avec leurs remplacements et fiches. Statistiques : compteurs, lecture du match et observatoire spatial. Consignes : conseil V61, réglages et toutes les commandes détaillées natives restantes. Les quatre boutons natifs gardent leur onclick et leur variable de présentation ; clavier gauche/droite/Home/End et focus après rendu. Les nœuds sont déplacés, jamais clonés. Les portraits du groupe fictif sont réutilisés ; aucun visage fictif pour LNR.

Une simple réduction de toutes les polices laisserait les données empilées ; une nouvelle page réécrite dupliquerait les actions métier. La réorganisation des mêmes éléments est retenue par l'intégrateur dans la direction déjà autorisée par Léo.

## Contrats
Aucun changement de S, du RNG ou de la sauvegarde par changement de vue. Aucun élément retiré : les outils non reconnus vont dans les consignes détaillées. Les modes 2D/3D et caméra conservent leurs contrôles et conteneurs natifs. Chaque page a un défilement local si nécessaire, aucun scroll global PC. Les profils, pause, sauvegardes et retour au match restent utilisables. Données et décisions rugby natives exclusivement. Petites fenêtres : accès maintenu, sans certification mobile.

## Validation
Test Chromium natif RED puis GREEN : terrain entièrement visible, quatre pages distinctes, carrière/disque invariants, clavier et focus, listes réelles, fiches et commandes présentes, thèmes et tailles PC, captures. Suites pures éditoriales et cockpit ; revue indépendante ; PR/CI sur SHA exact puis gate officiel si admissible. Windows non certifié. MATCH3D/DATA/moteur non modifiés.


## Revue et validation locale
La première exécution a échoué sur l'absence de pages, puis la géométrie du terrain a été corrigée sur le vrai DOM (le module 3D enveloppe aussi la 2D). Revue indépendante : canvas 3D dépassant son host de 156 px et perte de focus d'onglet au rendu périodique reproduits. Corrections : host 16/9 borné par son conteneur et canvas entièrement mesuré ; restauration du seul onglet précédemment focalisé, sans capturer le focus d'autres commandes. Rôle tab sans aria-pressed, libellé Consignes et conseils avec compteur de recommandations natives applicables. Les contrastes des listes, numéros et panneaux clairs sont contrôlés ; aucune statistique rognée, défilement local de la page.

Les tests exercent également le vrai remplacement, la vraie consigne et leur sauvegarde valide, le retour 3D→2D sans mutation de S, l'absence de portraits en LNR et les deux thèmes natifs. Aucun nouvel asset nécessaire : les portraits existants sont réutilisés. Les résultats finaux de CI seront consignés dans la PR et #73, sans commit cosmétique de documentation.
