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
- ~~L'onglet Staff garde l'ancienne mise en page~~ : repris le 20/11/2026 (section ci-dessous).
- À 1280, quelques textes secondaires finissent en « … » (rôle du leader, bilan vide) avec infobulle ou texte complet ailleurs.

## Onglet Staff — auto-relecture (20/11/2026, après-midi)

Sources : `staff_view.gd`, `staff_career_view.gd`, `club_canvas.gd` (`_staff_detail`) ; captures `staff-1920.png`, `staff-1280.png`
(tour filmé) et `club-staff-*.png` (suite `godot-club-da`, bureau séparé). Maquette : variante 3 « Onglet Staff en tableau ».

### A. Cliquabilité (Staff)

| Élément | Effet du clic | Verdict |
|---|---|---|
| Nom d'un membre (tableau), ligne du tableau | fiche du membre dans l'onglet (Précédent / Suivant) | OK |
| Visage et nom des 4 responsables (gauche) | fiche du membre | OK |
| Lignes du diagnostic, « Travail du club → » | Travail du club | OK |
| Contrats et engagements : en poste, fins de contrat / candidats / mentorat / budget | tableau (équipe) / tableau (candidats) / sous-page Mentorat / sous-page Engagements | OK |
| « Recruter un membre → » (pilule secondaire) | tableau des candidats | OK |
| « Prolonger → », « Recruter → » | sous-page « Contrat du staff » | OK |
| « ✕ Libérer », « ✕ Retraite », « Rémunérer → », « Activer les contrats rémunérés → » | confirmation EN PLACE (coût écrit), Annuler n'envoie rien | OK |
| « Mentorat des jeunes · … → », « Budget du staff · … → » | sous-pages Mentorat / Engagements | OK |
| Cases des délégations, « Demander une sélection → », « Recrutement → » | réglage / commande / écran Recrutement | OK |
| Fiche : « Prolonger <nom> » (pilule vert franc), « ✕ Libérer <nom> » (doré), « ← Retour à l'annuaire » | sous-page contrat / confirmation en place / tableau | OK |
| En-têtes de colonnes, compteur, note de bas de tableau | texte gris en petites capitales, sans flèche | non cliquables, n'en ont pas l'air |

### B. Petites fenêtres (Staff)

Aucune ouverte par un clic. Restent les menus déroulants (club, équipe/candidats/archives) — exception « menus déroulants ».

### C. Fidélité (Staff)

BLOQUANT : aucun.
À CORRIGER (corrigé dans ce tour) : titres de la colonne gauche coupés (« Diagnostic de la sem… ») ; colonne Contrat et lignes des responsables tronquées ou serrées à 1280 ; texte du diagnostic qui chevauchait « Travail du club → » à 1280 ; placeholder de recherche coupé.
AVIS : pas de « poste vacant » (le moteur ne le publie pas) ; pas de note /20 ni « effet mesuré » de la maquette 3 (données absentes : le niveau du moteur est affiché) ; la phrase d'information des carrières du staff finit en « … » à 1280 ; tri par colonne non repris (la maquette l'esquisse, le tableau suit l'ordre du moteur).

Charte finale (reprise du 20/11/2026, soir) : ardoise, panneaux 18 sans bordure, pilules, lignes 26 px sans bandes, liens gris-vert, aucun aplat doré dans l'onglet ; captures `club-staff-1920x1080.png`, `club-staff-1280x720.png`, `club-staff-fiche-1920x1080.png`. Écart hors Staff : les onglets du haut et les liens crème de la colonne gauche (« Travail du club → ») suivent encore l'habillage commun du Club, pas encore repris.
