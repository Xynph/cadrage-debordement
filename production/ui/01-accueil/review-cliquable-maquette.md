# Auto-relecture de l'écran 01 Accueil (20/11/2026)

Méthode : liste A (cliquabilité), B (petites fenêtres), C (fidélité à la maquette 1 « Affiche et carnet », état « première fois » de la 2, ligne du lieu de la 3) faites à partir des captures 1920×1080 et 1280×720 et du code (`accueil_canvas.gd`, `accueil_pages.gd`). Preuve exécutable : `tests/godot-accueil-da.gd` (74 contrôles, Godot réel + worker réel).

## A. Cliquabilité

| Élément | Effet du clic | Verdict |
|---|---|---|
| Reprendre la carrière (or) | ouvre la carrière (Réception) ; Entrée valide, focus à l'ouverture | OK |
| Nouvelle carrière (état première fois, ivoire) | ouvre le choix du club (Création) ; grisé avec raison écrite si aucun club | OK |
| Nouvelle carrière (lien, avec une carrière) | range la carrière en cours puis ouvre le choix du club | OK |
| Mes carrières | sous-page « Mes carrières » (ouvrir, supprimer avec confirmation en place, nouvelle) | OK |
| Importer une carrière | sélecteur de fichier système | OK (exception : fichier) |
| Paramètres | sous-page « Paramètres » (mêmes onglets que les réglages) | OK |
| Quitter | ferme le jeu (confirmation en cours de match) | OK |
| Identités et packs | écran Packs ; grisé avec raison tant que le profil s'ouvre | OK |
| Crédits | sous-page « Crédits et licences » | OK |
| Classement (« 4e · 25 pts ») | écran Classements | OK |
| Prochain match | Calendrier | OK |
| ← Accueil / Échap (sous-pages) | retour au menu | OK |
| Écusson, nom du club, saison, ligne de sauvegarde, accroche, logo | texte ou image, rien de souligné ni de fléché | OK (non cliquables, sans apparence de lien) |
| Récupérer le profil, Réessayer la connexion | actions existantes, visibles seulement dans le cas concerné | OK |

## B. Petites fenêtres

Aucune. Paramètres, Crédits et Mes carrières, qui ouvraient des AcceptDialog, sont des sous-pages ; la suppression d'une carrière se confirme en place. Reste le sélecteur de fichier système d'« Importer une carrière » (fenêtre du système, hors charte). Le menu de pause en carrière (Échap) garde ses fenêtres d'origine : il n'appartient pas à l'Accueil.

## C. Fidélité à la maquette

- BLOQUANT : aucun.
- À CORRIGER (corrigé) : division répétée dans la ligne « Saison · division · journée » quand le libellé de journée la porte déjà ; interligne de l'accroche trop ouvert ; rappel « Entrée » absent du bouton ivoire de la première fois.
- AVIS : pas de portrait de Gabi en bas à gauche (c'est le guide 3D flottant du jeu, placé par la coque) ; pas de lien « Visite guidée » (la visite appartient au guide) ; le bord droit du bouton or n'est pas incliné (rectangle franc) ; la photo vient de la banque d'images (titre-principal) et non de la photo du stade de la maquette ; ligne du lieu = stade du club lu des données, absente avant la première carrière.
- Données : classement, points, prochain match, saison, division, stade, nombre de clubs et de joueurs sont lus du modèle et du pack chargé ; aucune valeur de maquette figée.
- Or : uniquement le bouton de reprise (testé).
