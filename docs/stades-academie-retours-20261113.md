# Stades, Académie de l'écran Club, retours des internationaux

Demandes de Léo du 13 novembre 2026 (trois corrections). Carrière Monde uniquement ; rien dans les anciens modes.

## 1. Capacité des stades (116 clubs)

- Données : `native/engine/world-stadium-capacities.json`, une capacité par identifiant de club (0 à 115), sans aucun nom
  propre. Elle est lue au démarrage d'une carrière (`world-career.cjs`, champ `stadiumCapacity` du club), et par
  `club-strategy.cjs` pour une ancienne sauvegarde qui ne l'a pas (le module supporters retombe sur 12 000 sinon).
- Le dépôt public garde les noms inventés des clubs (hors France, aussi ceux des stades) : la correspondance avec les vrais
  clubs, les vrais stades, la base de chaque chiffre et les sources sont dans le dépôt privé
  `Xynph/rugby-reel-donnees`, `pack/stades-capacites.json` (branche `claude/stades-capacites-20261113`).
- Origine des chiffres : 67 capacités réelles (Top 14 : affichage LNR relayé par RugbyPass ; Pro D2 : LNR via RugbyPass ;
  Premiership : Wikipédia, liste des stades anglais ; URC : JetPunk, stades 2023-24 ; Super Rugby et Japon : capacités
  publiées), 18 estimées sur la taille de la ville et le niveau (Nationale et quelques clubs étrangers), 23 créées, crédibles
  pour le niveau (règle du projet : créées comme si elles étaient réelles). Ernest-Wallon : 19 500.
- Règle de plafond : un stade de plus de 40 000 places compte 30 000 (le club ferme ses tribunes hautes en championnat). Sans
  elle, les grands stades sud-africains, néo-zélandais et australiens donneraient 25 000 à 30 000 abonnés.
- Effet : abonnés de départ = capacité × (25 % + 50 % × popularité) (PR #676), affluence prévue, recette de billetterie
  prévue (projection de gestion, jamais encaissée), effet des campagnes d'abonnés. **Aucun effet sur la trésorerie** : le
  budget (`club-budget.cjs`) calcule la billetterie à partir des recettes du championnat et ne lit pas la capacité (test).
  Mesure sur la recette prévue par match (prix équilibré, moral neutre) : Toulouse 144 000 € → 234 000 € (12 000 → 19 500
  places), Pro D2 moyen environ 220 000 €, Championship 42 000 €, grand club sud-africain 360 000 €.
- Une saison non commencée (ni campagne, ni match) recalcule ses abonnés à la capacité réelle : les anciennes sauvegardes
  prennent le bon chiffre à la première ouverture.

## 2. Académie, bloc Infrastructures de l'écran Club

En Monde, le niveau 0-3 des installations n'existe pas (pas de compétitions Espoirs) mais le centre existe. La ligne affiche
désormais son état réel, lu dans la même projection que la page Formation (`clubLife.academyFollowUp`) :
« 30 Crabos · 30 Espoirs » et « 60 / 75 » (jeunes au centre, plafond). Plus de « Non ouverte ».

## 3. Dates de retour des internationaux : une source

Cause : le panneau « Absences internationales » de la Préparation calculait ses absents à la date du moteur (ouverture du
calendrier, 17/08, d'où « premier retour 24/08 » : 4 convoqués d'une fenêtre de tests du 26/07 au 23/08), pas à la date
affichée (13/07), et ignorait les 14 internationaux de la tournée de la fenêtre « La reprise » (retour le 10/08).

- `reprise.cjs` est la source unique. Un international convoqué pour une fenêtre déjà connue qui finit après les congés ne
  rentre qu'au lundi qui suit la fenêtre (24/08 pour ces joueurs) ; les autres gardent fin de tournée + 3 semaines (10/08).
- `CDReprise.absentees(S)` donne la liste des absents du club ; `international-native.cjs` la fusionne dans
  `availability` (mêmes joueurs, mêmes dates, premier retour = plus petite date).
- Date gardée : la plus réaliste est la plus tardive pour chaque joueur. Un joueur dont la sélection joue jusqu'au 23/08 ne
  peut pas être au club avant le 24/08 ; l'ancien 10/08 des fenêtres ignorait ce calendrier. Le « premier retour » du groupe
  est donc 10/08 (internationaux de tournée) et le dernier 24/08, identiques dans les deux panneaux : 18 absents pour le
  club 0.

Tests : `tests/world-stades-retours.cjs` (capacités, abonnés, mêmes dates), `tests/godot-ecran-club.gd` (Académie).
