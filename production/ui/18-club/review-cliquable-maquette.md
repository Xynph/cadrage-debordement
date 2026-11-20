# Auto-relecture — 18 Club (vue d'ensemble), 20/11/2026

Rôles : ux-designer puis art-director (CCGS). Sources : `native/godot/ui/immersive08/club_canvas.gd`, `club_pages.gd`,
`staff_career_view.gd`, `support_view.gd`, `main.gd` (`_confirmation_club`) ; captures `club-1920.png`, `club-1280.png`,
`staff-1920.png`, `staff-1280.png` (carrière Monde, J2, `scripts/ecrans-filmes.ps1`). Maquette : `apercus/18-club-1.png`
(+ tableau des bilans de la 2).

## A. Cliquabilité

| Élément | Effet du clic | Verdict |
|---|---|---|
| Onglets Vue d'ensemble / Direction / Infrastructures / Staff / Histoire (← → aussi) | changent d'onglet (Direction = Stratégie, Staff = Staff) | OK |
| Bandeau du club (écusson, nom, « Voir le stade → ») | onglet « Le stade » (territoire) | OK |
| Lignes de l'objectif (classement, promesses, jalons) | Stratégie, onglet objectifs | OK |
| « Suivre les objectifs → », « Tous les bilans du conseil → » | Stratégie, onglet objectifs | OK |
| Lignes du tableau des bilans | le match de la journée (lecture du score) s'il est connu, sinon les objectifs | OK |
| Lignes des installations (centre, cellule médicale, académie, stade) | Infrastructures / Travail du club / Centre / Le stade | OK |
| « Projets et devis des installations → » | Infrastructures | OK |
| À décider : « Fixer un jalon » ou « Suivre les objectifs » (ivoire plein), « Voir le devis → », « Présenter la demande → » | Stratégie (objectifs) ou Infrastructures | OK |
| « Trésorerie · … → », « Salaires et cotisations · … → » | Finances, onglet trésorerie / salaires | OK |
| « Entrer au vestiaire → », tuiles Moral et Disponibles, « + n autres absents → » | Vestiaire | OK |
| Nom du leader, noms des absents | clic = fiche complète, survol = mini-fiche (`Kit.nom`) | OK |
| Libellés « clic : détail et devis », « premier bilan à venir », compteur « 3 » d'À décider | texte gris, sans soulignement ni flèche | non cliquables, n'en ont pas l'air |
| Staff : contrat, mentorat (2 pages), engagements | sous-pages avec « ← Retour au staff », Échap, Précédent/Suivant | OK |

## B. Petites fenêtres

- Confirmations d'argent sur Club, Staff, Travail du club, Stratégie (devis, rallonge, libérer, retraite, signature d'agent, activation des contrats ou du mentorat) : EN PLACE (`ClubConfirmHote`, `confirmation_en_place.gd`). Ailleurs, `confirm()` garde son comportement.
- Contrat du staff, mentorat, « Un mentor, un jeune », engagements du staff : sous-pages (plus d'AcceptDialog).
- Restent : listes déroulantes du Staff (club, équipe, durée du contrat, mentor/jeune/qualité) — exception « menus déroulants ».

## C. Fidélité à la maquette

BLOQUANT : aucun.

À CORRIGER (corrigé dans ce tour) :
- À décider : titres sur deux lignes qui chevauchaient le détail (1280 et devis à 1920) → titre et détail sur une ligne, texte complet en infobulle ; coût du devis passé dans le détail.
- Installations : coût « 750 000 … » et statut « Devis disp… » tronqués → colonnes Coût (130) et Statut (196) élargies, « Prochaine amélioration » réduite.
- Or sur « Excédents réinvestis » (onglet du stade) → ivoire.
- Hauteur de clic des boutons du Travail du club perdue après l'habillage de la charte → plancher rétabli.

AVIS (écarts restants, non bloquants) :
- Début de saison : le tableau des bilans est vide (« Aucun bilan du conseil pour l'instant ») et la colonne gauche du conseil garde un vide ; la maquette montre J1-J8. Données réelles seulement, rien d'inventé.
- Sous-titre : « fondé en » et « conseil présidé par » n'apparaissent que si les données du club les publient (absents dans la carrière de test).
- Barre de confiance ordonnée de 0 à 100 (Menacé, Fragile, Solide) au lieu de Solide en premier dans la maquette : lecture d'échelle conservée.
- L'onglet Staff garde l'ancienne mise en page (cadres, numéros « 09 », « 10 », boutons en capitales) : hors maquette 18-1, à reprendre dans un chantier Staff.
- À 1280, quelques textes secondaires finissent en « … » (rôle du leader, bilan vide) avec infobulle ou texte complet ailleurs.
