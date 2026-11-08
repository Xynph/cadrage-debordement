# Améliorations repérées pendant la mission autonome

Audit de l'interface native du 8 novembre 2026, après reprise du lot en cours. La présence d'une idée dans un ancien prototype web ne suffit pas à la rendre disponible dans le jeu Windows. Les pistes ci-dessous ont été confrontées aux vues et commandes actuelles ; aucune n'est annoncée livrée par cet audit.

| Piste | Absence ou limite constatée dans le natif | Bénéfice joueur | Coût estimé | Risque | Décision |
|---|---|---|---|---|---|
| N01 Palette de navigation/recherche au clavier | `main.gd` ne traite globalement qu'Échap ; recherche limitée aux listes Effectif/Recrutement | Atteindre un écran ou un vrai joueur en quelques touches | Moyen | Faible, lecture/navigation seules | Retenue |
| N02 Historique précédent/suivant | `chapter_routes` retient une rubrique mais ne permet pas de revenir au dossier précédent | Explorer sans perdre le chemin suivi | Petit | Faible ; filtrer routes de carrière devenues indisponibles | Retenue avec N01 |
| N03 Chronologie du club actuel | `club_views.gd:club` affiche le territoire ; archives en liste, rivalités dans un autre écran | Donner une mémoire au club avec ses vrais titres, rangs et mouvements | Moyen | Faible si aucun passé non enregistré n'est inventé | Retenue |
| N04 Comparer deux saisons conservées | Archives affichées successivement ; aucun comparatif | Voir l'évolution du rang/division et les titres | Moyen | Moyen : points/scores historiques absents | Retenue dans N03, limitée aux faits conservés |
| N05 Journal complet filtrable du match | `match_screen.gd` n'affiche que les cinq derniers événements dans Direct | Relire les essais, sanctions et changements sans perdre les faits | Moyen | Faible, aucun retour temporel du moteur | Retenue |
| N06 Préférences durables de qualité/caméra | Qualité et caméra sont des réglages locaux de scène reconstruits | Garder le confort choisi entre deux matchs | Petit à moyen | Faible, préférences séparées de la carrière | Retenue avec N07 |
| N07 Réglages de confort et son du jeu | Paramètres limités à fenêtre/plein écran, packs et Gabi ; pas de volume général ou réduction des mouvements | Adapter le jeu au joueur et éviter les animations gênantes | Moyen | Moyen : appliquer sans cacher d'information ni changer le moteur | Retenue |
| N08 Favoris de navigation | Aucun favori d'écran enregistré | Revenir aux trois écrans les plus utilisés | Petit | Faible mais doublonne en partie N01/N02 | Différée pour éviter les boutons superflus |
| N09 Notes personnelles par dossier | Aucun carnet éditable de notes personnelles | Conserver une intention de recrutement ou un rôle envisagé | Moyen | Moyen : rattachement correct à la carrière et export des notes | Différée ; besoin de contrat de stockage distinct |
| N10 Retours de décisions non modaux | Statut générique de sauvegarde ; plusieurs décisions ne rappellent pas clairement ce qui vient de changer | Comprendre le résultat d'un clic sans ouvrir une fenêtre | Moyen | Moyen : distinguer action acceptée et effet réellement produit | À recevoir après les corrections, priorité secondaire |
| N11 Prévisions financières interactives | Engagements et simulations existent déjà dans Stratégie/Carrière ; pas de comparaison de scénarios libre | Préparer un investissement | Moyen | Élevé si recettes manquantes ou calcul dupliqué | Non retenue dans ce lot ; enrichissement du dispositif existant à étudier |
| N12 Échelle typographique globale | Tailles explicites dans les composants, aucun réglage de lecture global | Améliorer le confort de lecture | Élevé à qualifier | Moyen : risque de débordement à1280×720 | Différée après mesure ; ne pas annoncer un faux zoom qui coupe l'UI |

## Choix de réalisation

Trois domaines distincts sont retenus d'abord : **navigation**, **mémoire du club**, **lecture du match**. Les réglages durables de confort constituent un quatrième lot. Ils complètent les systèmes déjà portés sans ajouter de nouveaux calculs sportifs, de seconde base de données ou de menu principal inutile.

La comparaison des saisons utilise exclusivement division, rang, titre et mouvements réellement archivés. Les points, profits, affluences ou attributs historiques absents restent indiqués comme non conservés. Le journal de match filtre les événements existants ; il ne remonte pas le temps et ne rejoue pas une décision du moteur.

Ces choix sont faits par l'intégrateur dans l'autonomie explicitement accordée par Léo. Chaque lot doit encore être développé, critiqué et reçu sur le véritable jeu Windows avant d'être qualifié comme livré.
