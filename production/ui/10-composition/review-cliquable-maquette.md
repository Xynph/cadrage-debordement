# Relecture adverse, écran 10 Composition (cliquabilité, petites fenêtres, fidélité à la maquette)

Branche `claude/da-composition-20261119`. Lecture seule : code (`tactics_*.gd`, `shell.gd`, `lineup_cover.gd`) et captures 1920 / 1280.
Maquette : `10-composition-1.png` + encart « règle de la première ligne » de `10-composition-3.png`. Godot non lancé.

## A. Cliquabilité

| Élément (ce qui a l'air cliquable) | Effet du clic (lu dans le code) | Verdict |
|---|---|---|
| « Proposition du staff → » | commande `auto_lineup` (en place) | OK |
| « Tireurs et lanceur → » | sous-page « Tireurs et lanceur » (page, pas fenêtre) | OK |
| « Valider la feuille » + Ctrl Entrée | feuille valide : écran Préparation ; invalide : bouton grisé, info-bulle, focus sur « Corriger → » | OK |
| Puce « Ctrl Entrée » | texte seul, non cliquable, a l'air d'une touche | OK |
| « ✓ Feuille valide · 15 titulaires… » | rien, mais c'est un constat, pas de soulignement | OK |
| « ! 14 avertissements » (rouge gras) | RIEN (simple label). Dans la maquette c'est un menu « ! 1 avertissement ▾ » qui liste les avertissements | À CORRIGER (C1) |
| « B. OLLERENSHAW (n° 2) à 76 % de condition → » | `choisir(slot)` : candidats du poste en dessous. Le nom du joueur n'ouvre ni fiche ni mini-fiche | À CORRIGER (A1) |
| « Corriger → » / « Appeler un espoir → » / « Renforts… → » / « Jour de match · feuille à 22 → » (feuille incomplète) | focus sur le poste ; sous-page espoir ; sous-page renforts ; écran Match | OK |
| Quota JIFF à droite | texte + info-bulle, non cliquable, pas de soulignement | OK |
| Onglets Composition / Consignes / Phases arrêtées / Entraînement | Composition : sélection ; Consignes : Préparation onglet 1 ; Phases arrêtées : Plan de jeu ; Entraînement : écran d'entraînement | OK (onglet actif = ré-sélectionne le poste, inoffensif) |
| « Modifier → » (Plan · Défense) | Préparation, onglet Consignes | OK |
| Texte « Plan : Équilibré · Défense : Équilibrée » | rien, lisible comme un texte | OK |
| Carte de poste (ovale, note, « au poste ») | `choisir(slot)` : candidats du poste ; Espace prend / pose ; glisser-déposer | OK |
| Nom du joueur sur carte, banc, candidats | clic = fiche complète (`open_entity`), survol ou I = mini-fiche | OK |
| Ovale « 33 » et pastille « ! » (avis du staff) sur les cartes | enfants non cliquables (la carte reçoit le clic), info-bulle seulement | OK (voir C5) |
| En-têtes du banc N° / Joueur / Couvre / Cond. | tri en place + flèche ▲▼ | OK |
| Ligne du banc | `choisir(slot)` | OK |
| Marque « 1re ligne », titre « Banc 8/8 », « 1RE LIGNE 6/6 » | rien (étiquettes, pas soulignées) | OK |
| Cases « Doublures » 1 à 15 (×2…) | `choisir(poste-1)` | OK |
| « Sans doublure de métier : n° 15. » | rien ; le n° 15 est cité mais pas cliquable | AVIS (A3) |
| Lignes de duels (Mêlée 53 / 57 ▼ −4…) | RIEN, ni survol. Les six chiffres ressemblent à des liens vers le dossier adverse | À CORRIGER (A2) |
| Ligne « Vigilance : ! 14 joueurs sous 80 % : B. OLLERENSHAW, S. AT… » | RIEN. Noms de joueurs en texte brut, sans fiche ni mini-fiche | BLOQUANT (A4) |
| « Au près » / « Au large » | rien (texte) | OK |
| « Voir le dossier adverse → » | Préparation, onglet dossier adverse | OK |
| Bulle de Gabi : « Edward BREWER plutôt que Darcy BROOK… » | RIEN (info-bulle seulement). Deux noms de joueurs en texte brut, phrases coupées par « … » | BLOQUANT (A5) |
| Portrait de Gabi | rien | OK |
| Case « Hors feuille seulement » | filtre en place. Aucune case visible (tous les styles vidés) : on ne voit ni qu'on peut cliquer ni l'état | À CORRIGER (C4) |
| Champ « Nom… » | recherche en place | OK |
| En-têtes Joueur / Postes / Note / Condition des candidats | tri en place | OK |
| « Statut » (en-tête) | simple étiquette, non souligné | OK |
| Ligne candidat (hors action) | `activer` : affecte, échange, ou LIBÈRE le titulaire actuel, sans confirmation | À CORRIGER (A6) |
| « Choisir → » / « Échanger → » / « Libérer » | `activer` (même effet) ; pas de confirmation sur « Libérer » | À CORRIGER (A6) |
| Candidat grisé (non qualifié, blessé) | clic = message sous le tableau, aucune action. Cohérent (grisé) | OK |
| Bandeaux Bleus / Nationale | texte + info-bulle ; « Faire souffler → » commande `set_lineup` | OK |
| Encart « Première ligne formée » : « 1 · L. SIMMONS », « 17 · D. BLAKELEY »… | `choisir(slot)` ; nom du joueur sans fiche ni mini-fiche | À CORRIGER (A1) |
| Encart : « 2 ✓ », « Poste », « Formés » | rien (texte) | OK |
| Sous-page : « ← Retour à la composition » + Échap | revient à la composition (étape d'historique) | OK |
| Sous-page Tireurs : listes déroulantes (OptionButton) | menu déroulant, commande `set_tactics` | OK (exception menu déroulant) |
| Sous-page Espoir : choix radio, « Appeler le jeune », « Annuler » | commande `espoir_appeler` ; retour | OK |
| Sous-page Renforts : « Signer les renforts », « Annuler » | `promote_cover` confirmé ; retour. Pas de fenêtre de confirmation, le texte de la page sert de confirmation | OK |

## B. Petites fenêtres

Aucun clic de l'écran ne crée de Window / AcceptDialog / ConfirmationDialog / PopupPanel. Tireurs, espoir et renforts sont des sous-pages. La mini-fiche est un Control posé dans la coque. Seules fenêtres restantes :

- **BLOQUANT (hors écran 10, mais le code est dans cette branche)** : `TacticsCanvas._individual` (`tactics_canvas.gd` l. 427-446) ouvre un `AcceptDialog` « Consignes · nom » avec photo et 4 boutons de charge. Il est appelé par « Régler la charge individuelle » de la fiche joueur (`player_canvas.gd` l. 478 et 640), pas par la Composition. À convertir en sous-page ou section de la fiche ; la recette `godot-immersive08` « charge par la fiche » en dépend.
- `Cover.confirm` (`lineup_cover.gd`, `app.confirm`) et `Espoir.ouvrir` (ConfirmationDialog) restent dans le code. La Composition ne les appelle plus ; `Espoir.ouvrir` sert encore au coup d'envoi. À vérifier sur l'écran Match (hors périmètre), et à supprimer si plus aucun appelant.
- Info-bulles système : posées sur beaucoup d'éléments (chaque lien reprend son propre libellé en `tooltip_text`, ovales, cases de doublures, bandeaux, quota, validité). Le projet les compte comme des fenêtres (voir `mini_fiche.gd`), seule « Équilibre par poste » est une exception. AVIS : retirer celles qui répètent le libellé ; garder celles qui apportent une information.
- Menus déroulants des listes de la sous-page Tireurs : exception autorisée.

## C. Fidélité à la maquette (variante 1 + encart de la variante 3)

### BLOQUANT
- **A4** Ligne « Vigilance » du bloc Impact : noms de joueurs en texte brut, tronqués (« B. OLLERENSHAW, S. AT… »). Correction : lister les joueurs par `Kit.nom` (fiche + mini-fiche) sur plusieurs lignes ou un seul lien « ! 14 joueurs sous 80 % → » vers un menu. Impossible de les lire en entier aujourd'hui.
- **A5** Bulle de Gabi : noms de joueurs en texte brut, phrases tronquées (« Darcy BROOK… », « (arriè… »). Correction : retour à la ligne (2 lignes max par conseil) et chaque nom en `Kit.nom`, ou conseil entier cliquable vers le poste concerné (`choisir(slot)`).

### À CORRIGER
- **A1** Noms dans la ligne de validité (« B. OLLERENSHAW (n° 2)… ») et dans l'encart « première ligne » : le clic ouvre les candidats, pas la fiche, et pas de mini-fiche. Correction : séparer le nom (`Kit.nom`) du lien « Voir le poste → ».
- **A2** Duels du bloc Impact (53 / 57 ▼ −4…) sans survol ni clic. Correction : ligne entière = lien vers le dossier adverse, ou carte visiblement non cliquable (sans survol, ce qui est le cas ; donc pas de curseur main). À défaut garder tel quel et l'assumer.
- **A6** Cliquer n'importe où sur la ligne du titulaire actuel dans les candidats le LIBÈRE, sans confirmation (même chose avec Suppr sur une carte). La maquette montre « Libérer → » seulement à droite. Correction : ligne du titulaire actuel = sélection seulement ; « Libérer » demande une confirmation en place (bandeau « Libérer ? Oui · Non ») ou reste réversible par « Annuler ».
- **C1** « ! 14 avertissements » est une étiquette ; la maquette a un menu déroulant « ! 1 avertissement ▾ » qui liste chaque joueur sous 80 % (avec lien vers son poste). Correction : en faire un menu déroulant (exception autorisée).
- **C2** Noms de cartes tronqués à 1920 (« A. BLOOMFIE… », « B. OLLERENS… », « K. DANGERFI… ») et à 1280 (nom collé au numéro, cartes sans fond lisible). Maquette : noms complets, en casse normale (« I. Okonedo »), cartes plus larges. Correction : carte plus large (≥ 200 u.), nom en casse normale, ou sous 1400 px abréger en « Initiale. Nom » sans majuscules forcées.
- **C3** Capture 1280 : dans les candidats, « Hors feuille seulement » chevauche le champ « Nom… » et le compteur « 2 candidats… » touche l'encart. Le bloc Impact tronque « Projection du staff · se recalcule à chaque chan… ». Correction : replier le filtre sous le titre, ou raccourcir le libellé (« Hors feuille ») sous 1400 px.
- **C4** Case « Hors feuille seulement » sans case visible (styles vidés) : état invisible, rien n'indique que c'est cliquable. Correction : dessiner une case carrée (rayon 0, trait ivoire, remplie si cochée) comme dans la maquette.
- **C5** Pastilles « ! » (avis du staff) et « 33 » : rectangles arrondis (rayon 5) à cadre complet via `D.chip`, contraire à l'art bible (rayons 0, aucun cadre complet). Idem pastille DERBY (cadre or). Correction : puces pleines rayon 0 sans cadre, ou ovale charte.
- **C6** Sous-pages Tireurs / Espoir / Renforts : thème historique (`Legacy.apply`) avec boutons arrondis encadrés (rayon 6), focus or, couleurs MUTED / AMBER / ALERT / MINT (aucune de la charte), cases radio génériques. Correction : listes et boutons dans le style de l'écran (liens ivoire + flèche, un seul bouton ivoire plein, jetons §4.2).
- **C7** Aperçu de glisser (`PlayerButton._get_drag_data`) : cadre arrondi C.MINT, couleur hors charte. Correction : fond PANNEAU_3, rayon 0, texte ivoire.
- **C8** Liens `Kit.lien` : trois états sont partagés avec le style « lien » commun de la branche Réception. Quand `components.gd` l'aura, remplacer `Link.styled_button` pour que le souligné au survol, la flèche et le focus soient identiques.

### AVIS
- **A3** « Sans doublure de métier : n° 15 » : rendre « n° 15 » cliquable (`choisir(14)`).
- Maquette : lien « Enregistrer comme modèle » et phrase « Brouillon conservé si tu quittes l'écran » absents. Choix assumé dans la fiche UX (en-tête réduit) ; la phrase du brouillon rassure, à reprendre si la donnée existe.
- Maquette : un seul avertissement ; la capture en montre 14 parce que la saison débute (pastilles « ! 6x % » sur presque toutes les cartes). Correct, mais le rouge sur 14 cartes dilue le signal. Option : n'afficher « ! » que sous 70 %, le reste en ivoire-2.
- Onglets : « Entraînement » est un 4e onglet absent de la maquette. Cohérent avec la fiche UX, à confirmer par Léo.
- Fonds : pas de zébrure sur le tableau de candidats aussi marquée qu'au banc ; la sélection (fond clair + marqueur) reste lisible. RAS.
- Données : club, adversaire, compétition, stade, date, JIFF viennent du moteur (`_affiche`, `_adversaire`) ; aucun nom figé trouvé dans les fichiers de l'écran. « Gabi » est un personnage du jeu.
