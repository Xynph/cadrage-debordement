# Relecture adverse — 15 Après-match (cliquabilité, petites fenêtres, fidélité maquette)

## Auto-relecture du lot 4 de la charte finale (20/11/2026)

**A. Cliquabilité** : inchangée par le lot ; leviers, liens « Voir plus », noms et classement agissent (`godot-apres-match`, `godot-apres-match-jeu`).

**B. Petites fenêtres** : aucune ; menu « Plus » = liste déroulante (exception).

**C. Fidélité à la charte**
- Corrigé : score dans un panneau sombre (écusson en case 6, plus de plaque teintée du club) ; pastilles V/N/D en pilule (V plein vert clair, N demi gris-vert, D contour doré, lettre écrite) ; classement sans bandes, notre club en ligne choisie 6 ; panneaux 18, cartes 12 ; « Plus » en pilule à contour ; « Valider le résultat » seul aplat doré ; titres droits.
- AVIS : bandeau photo ≈ 24 % de la hauteur (art-bible : 30 %) ; menu « Plus » habillé par le thème global.


Lecture seule : code (`apres_match.gd`, `director.gd`, `live_view.gd`, `main.gd`, `match-direct.cjs`, `match-multiplex.cjs`, `match-pourquoi.cjs`, `navigation_controller.gd`) et captures 1920/1280 (`captures2`). Godot non lancé. Les captures ne montrent ni survol ni mini-fiche : ces effets sont jugés d'après le code.

Mécanisme commun : `_lien()` -> `ouvrir(cible)` -> `director.consulter(cible)` -> `navigation_controller.open_entity(cible)`. Il renvoie `false` sans rien afficher si le moteur attend (`app.waiting`), si l'entité n'est pas disponible (`entity_available`) ou si la route est interdite (`_allowed_route`). Le clic est alors **silencieux** (voir C-4).

## A. Cliquabilité

| Élément | Effet du clic (code) | Verdict |
|---|---|---|
| Pastille V/N/D, mot « VICTOIRE », « FIN », ligne compétition · J9 · stade · date | Rien ; texte simple, aspect non cliquable | OK |
| « Plus ▾ » | `MenuButton` : menu déroulant (Statistiques/notes/journal en place ; Classements de la compétition ; Calendrier du jour) | OK (exception menu déroulant). Style : aplat panneau encadré, pas un lien texte (AVIS) |
| Plaque club (nom en grand) | Fiche du club (`club`) | OK ; seul le nom est actif, pas la plaque ni le sigle (AVIS) |
| Score « 32 – 27 » | Rien, aspect non cliquable | OK |
| « Classement 13e → 12e +1 place » | Rien, texte simple. On pourrait attendre le classement | AVIS : en faire un lien vers la compétition |
| Homme du match (nom) | Notre joueur : fiche complète + mini-fiche au survol (`MiniFiche.lier`). Joueur adverse : fiche du **club** adverse, infobulle « Fiche de … » | OK si des nôtres ; adverse voir C-2 |
| « (9,5) » note, « Essais 4 – 5 », « Point de bonus … » | Rien | OK |
| Rang `1 2 3`, pastille ▲/▼ + « POINT FORT / À CORRIGER », libellé du levier | Rien (Labels) | OK |
| Texte de la raison | Rien | OK |
| « Travailler la discipline → » (et les autres leviers) | `menu` + route du moteur : discipline, tactique et composition ouvrent **Composition** ; condition **Effectif** ; préparation **Préparation** | OK mais voir C-3 |
| « Voir plus : statistiques, notes, journal → » | Sous-page en place (`detail`) avec « ← Retour au pourquoi » | OK |
| Sous-page : lignes de stats, journal | Rien, texte | OK |
| Sous-page : noms des notes de ton XV | Fiche complète + mini-fiche | OK |
| Fil du score : sigle, minute, score | Rien ; infobulle de l'événement sur toute la marque | OK |
| Fil du score : nom du marqueur | Notre joueur : fiche + mini-fiche. Adverse : fiche du club | Voir C-2 |
| Titre « CLASSEMENT APRÈS LA J9 », « Division … · 14 clubs » | Rien, texte simple | OK |
| En-têtes J V N D DIFF. PTS FORME | Rien (non triables, aspect de simple en-tête) | OK |
| Ligne de classement : nom du club (`ApresMatchClubLigneN`) | Fiche du club (le sien : écran Club) | OK |
| Ligne de classement : rang, J V N D, diff., pts, forme, sigle | Rien : seul le nom est actif, la ligne ressemble à une ligne entière cliquable et n'a pas de survol | AVIS : rendre la ligne entière cliquable avec survol |
| Symbole de zone (étoile, point) | Infobulle du libellé de zone | OK |
| Légende (« 1er à 2e · Demi-finale directe ») | Rien | OK |
| « Ta place » : trois cases | Fiche du club voisin (`club`), infobulle nom et points | OK. Mais « 0 sur le 11e » est ambigu (C-5) |
| « Les autres matchs de la J9 » : chaque ligne | Calendrier du jour (`date`), sinon la compétition ; infobulle « … · le calendrier du jour » | OK, mais C-6 |
| Titre « LES AUTRES MATCHS DE LA J9 » | Rien | OK |
| Carte de Gabi (portrait, phrase) | Rien | OK |
| « VALIDER LE RÉSULTAT » | `finish_round` | OK (seul or, exception admise) |
| Texte d'aide « Valide le résultat · la suite… » | Rien | OK |
| Bouton « Après-match » / « Continuer » de la coque | Retour à l'après-match | OK |

Aucun élément « RIEN » sur un aspect cliquable : pas de BLOQUANT de cliquabilité, hors C-2 et C-4 à trancher.

## B. Petites fenêtres

Aucun `Window`, `AcceptDialog`, `ConfirmationDialog` ni `PopupPanel` créé par `apres_match.gd`. Seuls usages : menu déroulant « Plus ▾ » (exception), mini-fiche au survol (`MiniFiche.lier`, exception ; `mini_fiche.gd` n'ouvre pas de Window), infobulles natives. **Aucun écart.** Point à vérifier en jeu : la mini-fiche reçoit `z_index = 200` au survol, donc elle doit passer devant le fil du score.

## C. Fidélité à la maquette et données

### BLOQUANT

- **C-1. Forme des clubs fausse en cas de nul.** `match-multiplex.cjs` envoie `r.form.slice(-5)` : valeurs moteur `W` / `D` / `L` (`champ-rugby.cjs` l.165 : `W`, `D` = **drawn**, `L`). `apres_match.gd` (`_ligne_club`) fait la correspondance `{"V","N","D","W","L"}` : un `D` du moteur (nul) s'affiche donc **D rouge = défaite**. Les captures ne le montrent pas (aucun nul : colonne N à 0 partout). Une donnée fausse présentée comme réelle. Correction : `W` donne V, `D` (moteur) donne N, `L` donne D. Ne garder `V`, `N`, `D` directs que si le moteur les émet ; sinon convertir côté moteur en `V`/`N`/`D` et ajouter un test avec un nul dans la forme.

### À CORRIGER

- **C-2. Noms de joueurs adverses (fil du score, homme du match adverse).** Ils ont l'aspect d'un nom de joueur (souligné au survol) mais ouvrent la fiche du **club**. Ni fiche de joueur ni mini-fiche : la règle « nom de joueur = fiche + mini-fiche » n'est tenue que pour notre effectif. À trancher : soit ouvrir la fiche de l'adversaire (si le jeu en possède une : `market` / adversaire de la rencontre) avec mini-fiche, soit afficher ces noms en texte non cliquable et garder le sigle du club comme lien. Dans le fil à 1920, 5 marques sur 10 sont adverses.
- **C-3. Leviers qui mènent au même endroit.** « Travailler la discipline → », « Ajuster la tactique → » et « Revoir la composition → » ouvrent tous Composition (routes de `match-pourquoi.cjs` l.17-21). Le clic n'est pas « rien », mais le joueur qui clique sur « discipline » arrive sur un écran sans rubrique discipline apparente. À régler : ouvrir directement l'onglet ou la section concernée, ou ajuster le libellé (« Ouvrir la composition »).
- **C-4. Clic silencieux possible.** Si le moteur attend, ou si `entity_available` / `_allowed_route` refuse, `consulter()` renvoie `false` et l'écran ne change pas, sans retour visuel. Cas probables : un club hors des classements chargés, la période où `app.waiting`. À faire : griser le lien avec infobulle de la raison, ou n'afficher un lien que si `entity_available(cible)` est vrai (sinon texte simple).
- **C-5. « Ta place ».**
  - Disparaît à 1280 (`_ajuster`). L'ordre de repli est discutable : les autres matchs passent d'abord en deux colonnes (noms tronqués), puis « Ta place » s'efface. À 1280 il reste visuellement environ 60 px libres sous les autres matchs, et une fois « Ta place » masquée la grille reste en 2 colonnes. Relancer la mesure après le masquage et repasser à une colonne si cela tient, ou condenser « Ta place » en une ligne (« 12e · 11 pts · −20 sur le 1er · 0 sur le 11e · 0 sur le 13e ») qui reste à 1280.
  - Valeurs : « −20 sur le 1er », « 0 sur le 11e » : le signe se lit mal (« 0 » ne dit pas si c'est un écart de points). Écrire « à 20 pts du 1er », « à égalité avec le 11e ».
- **C-6. Autres matchs : noms tronqués « … ».** À 1920, deux colonnes avec « Blackthorn Borou… », « Hawthorn Colleg… », « Forge Valley Tita… », « Trentwood Arche… », « Meadowbridge R… » ; à 1280 presque tous (« Greycliff Ra… », « Severn Cro… »). Le panneau a de la place verticale à 1920 (environ 40 px libres) et le fil du score laisse deux grands vides à gauche. Correction : une colonne à 1920 (6 × 24 px) en rognant les vides ; à 1280, utiliser l'abréviation du club (`G.club_abbr`, déjà affichée dans le sigle) plutôt qu'une coupe « … », ou retirer le second sigle. Tous les clics des 6 lignes mènent au même calendrier du jour : si le moteur donne un identifiant de rencontre (`fixture`), mieux vaut ouvrir cette rencontre.
- **C-7. Fil du score : nature de la marque absente.** Une marque de 3 points (pénalité, ex. Abbott 24', Boothroyd 76') ressemble à un essai ; seul le texte d'infobulle le dit. Les essais « transformés » (7 pts) sont un seul item et l'auteur de la transformation n'apparaît pas. Ajouter une lettre ou un mot (« essai », « pén. », « drop ») : `kind` est déjà fourni (`try` / `goal`), le libellé « Essai » / « Pied » n'est utilisé que sans nom. L'écran dit « Essais 4 – 5 » mais on ne peut pas compter les essais dans le fil (5 marques AFN, dont deux pénalités).
- **C-8. Cadre de focus du bouton or.** Le bouton « VALIDER LE RÉSULTAT » a le focus à l'ouverture : un **cadre rectangulaire ivoire complet** de 2 px entoure l'aplat incliné (visible sur les deux captures). Contraire à la charte (aucun cadre complet) et incohérent avec la forme en parallélogramme. Remplacer par un soulignement ou un liseré incliné ; garder un focus visible.

### AVIS

- Maquette : « Note du match 7,2 / 10 » absente (le moteur n'en calcule pas : ligne omise, accepté) ; « et 2 autres raisons » absent (3 raisons seulement) ; ligne « Échap Pause et menu · Reprendre ramène ici » absente (décision du 16/11 : Échap ne quitte pas). Cohérent avec la fiche UX.
- Bandeau : la photo du vestiaire est plus colorée et plus claire que dans la maquette (verts saturés), le voile (`C.veil`, 0,35) devrait être plus appuyé pour la densité de la maquette ; « Plus ▾ » se superpose au visage.
- Vide à gauche à 1920 : environ 100 px entre « Voir plus » et le fil du score, environ 80 px entre le fil et Gabi ; la maquette est plus serrée. Répartir ou densifier.
- Pastilles de forme à 1280 : 24×16 réduits à ~16×11 px avec lettre à 12 px (`_f` plancher) : lettres coupées. Garder une taille minimale de 20×14.
- Typographie : « 32 – 27 » (demi-cadratin) dans le bandeau, « 0-5 » (trait d'union) dans le fil : unifier.
- Gabi : « On a gagné malgré la préparation » à côté d'un « À surveiller : touche 9 sur 15 » (levier préparation) se lit un peu à côté ; mentionner la touche. Les chiffres cités viennent bien de `hommeDuMatch` (essais, plaquages, mètres) : pas de donnée inventée.
- Plaque club : seule la zone du nom est cliquable.
- Données moteur ajoutées (cohérentes, vérifiées sur la capture 1920) : V+N+D = J pour chaque club (9) ; V/D de la forme finissent par le résultat du jour (Alder Fen XV : 2 V 7 D, forme `D D D D V` après la victoire) ; points, différence et rang sont triés de façon cohérente (27 pts : +109 / +60 / +30) ; essais 4-5 cohérents avec le fil (marques de 5 ou 7 pts = essais) ; classement et zones (« 1er à 2e · Demi-finale directe », « Pas de descente ») lus des données de la ligue ; aucun nom de club ni de championnat figé dans `apres_match.gd`. Seule anomalie : C-1 (nul).

## Liste fusionnée BLOQUANT / À CORRIGER

1. BLOQUANT C-1 : un nul du moteur (`D`) s'affiche en défaite dans la forme ; mapper `D` en `N`.
2. C-2 : noms de joueurs adverses (fil, homme du match) = fiche du club, ni fiche ni mini-fiche ; à trancher.
3. C-3 : discipline, tactique et composition ouvrent le même écran Composition.
4. C-4 : clic silencieux si `open_entity` refuse ou moteur occupé ; griser ou rendre non cliquable.
5. C-5 : « Ta place » disparaît à 1280 ; réordonner le repli ou le condenser ; écarts « 0 sur le 11e » ambigus.
6. C-6 : noms « … » des autres matchs (1920 et 1280) ; une colonne ou abréviations ; ouvrir la rencontre plutôt que le calendrier.
7. C-7 : le fil du score ne distingue pas essai, pénalité et drop.
8. C-8 : cadre de focus rectangulaire autour du bouton or (charte : aucun cadre complet).
