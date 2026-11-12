# Revue visuelle Carnet et lien de date — 12 novembre 2026

Source de recette `303e8a4698bad50066580f06429fa74f7d8da0dd`, communiquée par
l’intégrateur. Le journal brut donne **4346 contrôles, zéro échec**, durée TAP du
cas **154,819474 s**, total runner 154,875506 s. CARNET_SPEECH publie réellement
requested=0, started=0, id=0 ; audio Dummy et mise en sourdine précoce observée
dans le script. Aucun compteur n’est déduit des captures. La limite 180 s du
wrapper Carnet est inchangée. Ce reçu reste une seule suite graphique ciblée.

## Trois résolutions, cinq passages du contrôle

La boucle réelle couvre **1280×800, 1440×900 et 1920×1080**. Les variantes Common 29,
France 0, Fiction 0 et projections sont ensuite rendues à 1440×900. Le relevé
intégrateur compte cinq passages de la cible de date ; ce ne sont ni cinq
résolutions ni cinq nouveaux cas à additionner. Le journal fourni ne sérialise
pas les rectangles individuels. Aucun rapport JSON original n’est produit par
ce wrapper : le manifeste est un index documentaire, pas un rapport SDK inventé.

## Constat visuel et sélection originale

- [Classements 1920×1080, carte du prochain rendez-vous](images/classements-1920.png) :
  date « 12/09/2026 · 15:00» lisible sous le club domicile, sans collision visible
  avec Journée 1/26, le lieu ou Préparer le match. La carte est entièrement
  visible ; le tableau et le calendrier gardent leurs colonnes.
- [Contexte compact 1280×800](images/classements-1280.png) : tableau et pagination
  lisibles, sans débordement évident ; ce gabarit ne montre pas la carte du
  prochain rendez-vous et ne prouve donc pas le lien de date.
- [Projection synthétique 1440×900](images/classements-projection-long-jaune-pack-absent.png) :
  le test remplace la présentation du club par un nom long, un accent jaune et
  une information de pack absent. Les titres tronqués restent dans leur zone,
  bandeau et actions conservés. Ce n’est ni une carrière avec cet état naturel,
  ni une nouvelle direction artistique proposée.

Les sept PNG Classements (trois tailles, Common 29, France 0, Fiction 0 et
projection) ont été inspectés. Les trois variantes 1440×900 sont le gabarit compact,
sans carte/date : elles ne fournissent pas une réception visuelle de cette
cible. Aucun défaut nouveau de débordement/collision n’est visible dans ces
images. Leurs hashes et dimensions, y compris les non publiées, sont indexés.

Les cinq projections synthétiques Effectif, Composition, Club, Calendrier et
Classements ont été inspectées. Les noms longs sont tronqués dans les cellules
et cartes de composition ; les listes, zones de commande et le calendrier
restent contenus. Le titre long de Club est lisible dans sa zone de pied. Aucun
nouveau défaut de géométrie évident relevé. Le bandeau de pack absent et la
couleur jaune sont des injections de projection UI explicitement isolées,
sans preuve de mutation sportive moteur ni de qualité d’une nouvelle palette.

## Portée exacte de la cible transparente

CompetitionNextDateLink est une zone transparente. La capture ne permet pas de
mesurer son rectangle ni de prouver un clic. Le code du produit fixe sa hauteur
au maximum du minimum 18 px, de la hauteur prévue, de la date visible et de la
police héritée. Le test bounds vérifie séparément taille de cible/hauteur du
texte, focus clavier et concordance du libellé visible avec le nom accessible.
Le passage 4346/0 reçoit ces assertions ; ce rapport visuel ne leur substitue
aucune mesure inventée et ne revendique aucun clic depuis un PNG.

Les trois PNG sélectionnés sont les originaux, sans retouche ni recadrage.
Aucun profil ou export complet n’est copié. Le manifeste consigne les sources,
SHA256, tailles et dimensions. Vérification : `sha256sum --check SHA256SUMS`.
Aucun SDK, compilation, input ou nouvelle capture lancé pour cette revue.
Pas de verdict global, Windows ou animation déduit de ces images.
