# Auto-relecture · 02 Création de carrière, étape « 1 Club » (20/11/2026)

Rôles : ux-designer puis art-director (CCGS). Base : captures `02-creation-1920.png`, `02-creation-1920-championnat.png`, `02-creation-1280.png` (suite `godot-creation-da`, bureau séparé) et code `ui/immersive08/creation_canvas.gd`.

## A. Cliquabilité

| Élément | Effet du clic | Verdict |
|---|---|---|
| Logo (barre haute) | rien, infobulle « Rugby Legacy 27 », pas de survol | OK (marque, pas un lien) |
| « ← Accueil » | écran Accueil (Échap aussi) | OK |
| Pastilles « Échap », « Ctrl F », « Entrée » | rien : indications de touche, sans soulignement ni survol | OK (AVIS : forme de pastille) |
| « 1 CLUB » | rien (étape en cours, soulignée) | OK |
| « 2 CARRIÈRE → » | écran Options de carrière (lien seulement quand un club est choisi ; sinon texte gris + infobulle) | OK |
| Menus Rôle / Sélection | menu déroulant, page mise à jour | OK (exception menus déroulants) |
| « Identités et packs » | écran Packs (retour vers la création) | OK |
| Recherche | filtre la grille en place ; état vide + « Effacer la recherche » | OK |
| Onglets pays | premier championnat du pays | OK |
| Onglets championnats | grille du championnat | OK |
| Liens « Défis de départ » | choisit le défi et son club (pays et championnat suivent) ; « ou [club] » change de club | OK |
| Boutons de tri | trient la grille (état + « ▾ ») | OK |
| Carte de club (nom, écusson, chiffres, « Rival ») | choisit le club ; double-clic ou Entrée sur la carte choisie : étape suivante | OK |
| Chiffres du panneau Niveau / Trésorerie | trient la grille par cette mesure | OK |
| Chiffre Joueurs, lignes Conseil / Fondé en / Ville | texte simple (ni soulignement ni survol) | OK |
| « Continuer avec [club] » | écran Options de carrière | OK |
| Rivaux (liens soulignés) | choisit le rival (sa division s'ouvre) ; rival non jouable : texte gris | OK |
| « Format de la division et enjeux → » | ouvre le format en place ; « ← Revenir au club » | OK |
| Bloc Gabi (portrait, conseil) | texte, pas de survol | OK |
| Pied | texte | OK |

Aucun nom de joueur sur cet écran (pas de fiche / mini-fiche à brancher).

## B. Petites fenêtres

- Supprimée : la fenêtre « Ton rôle » (ConfirmationDialog) devient deux menus déroulants dans la page (`Entry.role_controls`).
- Plus aucune Window ouverte par un clic de l'étape Club (vérifié par la suite). La confirmation « Une nouvelle histoire » (carrière existante remplacée) appartient à l'étape 2.

## C. Fidélité à la maquette

BLOQUANT : aucun.

À CORRIGER (fait) :
- « Continuer avec … » coupé à 1920 : police réduite, « Entrée » retiré sous 1600 px de large.
- Pied : la consigne de droite était invisible : corrigé.
- Carte choisie à 1280 : « ✓ Choisi » et « Rival » ne s'effacent plus ; filet, jauge et conseil s'effacent d'abord.

AVIS (écarts assumés) :
- « Budget » → **Trésorerie de départ** (seule donnée réelle) ; « Masse salariale » et « dont N du centre de formation » omis (absents du catalogue).
- Carte choisie sans cadre complet (charte §3) : fond plus clair, marqueur incliné, « ✓ Choisi ».
- Bandeau : voile uni, pas de dégradé (charte §3).
- 14 à 16 clubs : la grille passe à 4 rangs, la ligne « Conseil » des cartes s'efface à 1080 quand la place manque (elle reste dans le panneau du club choisi).
- Classement de l'an passé : affiché seulement quand l'historique du club le donne (peu de clubs du jeu de base).
- Défis de départ (absents de la maquette, fonction existante) : une ligne de liens sous les championnats.
