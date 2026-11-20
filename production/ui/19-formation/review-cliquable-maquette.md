# Auto-relecture — 19 Formation, 20/11/2026

Rôles : ux-designer puis art-director (CCGS). Sources : `native/godot/ui/immersive08/academy_canvas.gd`, `formation_pages.gd`,
`youth_development_view.gd`, `academy_pathways_view.gd` ; captures `formation-1920.png`, `formation-1280.png` (carrière Monde,
J2, `scripts/ecrans-filmes.ps1`). Maquette : `apercus/19-formation-retouche.png` (variante 1 « Tableau et fiche du jeune »,
règle fiche joueur, raisons écrites de la file empruntées à la 3).

## A. Cliquabilité

| Élément | Effet du clic | Verdict |
|---|---|---|
| Compteurs Espoirs / Pépites / À décider | filtrent le tableau (aucun filtre, pépites, à décider) | OK |
| Compteur Places pro libres | Effectif | OK |
| « Suivre les objectifs et gains observés → » | sous-page Suivi des jeunes (retour, Échap, Précédent/Suivant) | OK |
| Onglets Effectif / Progression / Passerelles / Encadrement | changent d'onglet | OK |
| Puces Tous / À décider / Pépites / Blessés | filtrent le tableau | OK |
| Puces de groupe U21 / U18 / Tous / Jeunes pros | changent le groupe (avant : liste déroulante) | OK |
| Listes Poste, Tri | menus déroulants (exception admise) | OK |
| En-têtes de colonnes (sauf « Saisons passées », texte gris sans flèche) | trient | OK |
| Ligne d'un jeune | place la décision sur ce jeune | OK |
| Nom d'un jeune (tableau, bande de décision, Passerelles, revue d'effectif) | clic = fiche complète ; survol ou « i » = mini-fiche | OK |
| « Promouvoir », offres « n saisons · salaire → » | confirmation EN PLACE (`confirmation_en_place.gd`) avec salaire, puis commande | OK |
| « Voir l'effectif et les places → » (sans place pro) | Effectif | OK |
| « Nouvelle génération : n à examiner → » | sous-page revue d'effectif ; « Valider » confirmé en place | OK |
| Cartes « À décider » | placent la décision sur ce jeune (filtre levé si besoin) | OK |
| « Compléter les centres de formation → » | confirmation en place | OK |
| Passerelles : tuiles Académie / Passerelles / Équipe première | onglet Effectif / Centre / Effectif | OK |
| Passerelles : « Ouvrir les parcours du centre → », compétition junior, « Suivre les objectifs → » | Centre / Centre / sous-page Suivi | OK |
| Encadrement : tuiles Éducateurs / Installations / Cohésion | Staff / Club / Centre | OK |
| Encadrement : lignes du staff, « Gérer le centre → », « Suivi des jeunes → », « Ouvrir le staff → » | Staff / Centre / Suivi / Staff | OK |
| Touches « I aperçu », « Échap menu » du pied | rappels de touches, pas d'aspect de lien | non cliquables, n'en ont pas l'air |

## B. Petites fenêtres

Aucune fenêtre ouverte par un clic de l'écran (test `godot-formation-da`). Le suivi des jeunes et le prêt d'un jeune
professionnel sont construits dans leur ancienne fenêtre puis ADOPTÉS dans une sous-page (fenêtre masquée) ; leurs
confirmations passent en place (`Pages.confirmer`). Hors page (vue compacte de secours), la confirmation d'origine reste.

## C. Fidélité à la maquette

Corrigé dans ce tour :
- BLOQUANT corrigé : valeurs du tableau décalées d'une colonne (niveau sous « ÂGE », potentiel sous « NIV. ») ; test de
  régression ajouté (vu rouge avant le correctif).
- À CORRIGER corrigé : groupe U21 / U18 / Tous en puces comme la maquette (au lieu d'une liste déroulante).
- À CORRIGER corrigé : « i » collé au nom (largeur réelle mesurée).

Restant (AVIS) :
- La bande de décision n'a que « Promouvoir » : « Garder en espoir » et « Libérer » de la maquette n'ont pas de commande
  moteur hors parcours actifs ; à ajouter avec le moteur, pas inventés ici.
- « Prog. depuis juillet » et « Fin du contrat » affichent « — » en début de saison quand la donnée manque (pas de
  valeur inventée).
- L'écran « Suivi des jeunes » adopté garde le style de l'ancienne vue (potentiels orangés, cartes encadrées) : refonte
  à part.
- Pas de mini-fiche épinglée au survol de la ligne entière (maquette) : elle s'ouvre au survol du nom ou du « i ».
