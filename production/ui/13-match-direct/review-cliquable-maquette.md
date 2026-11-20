# Relecture adverse : 13 Match en direct (cliquabilité, petites fenêtres, fidélité maquette)

Lecture seule (code `live_view.gd`, `match_temps_forts.gd`, `club_sheet_canvas.gd`, `preferences_dialog.gd` + captures 1920 et 1280). Rien n'a été lancé : les « RIEN » sont établis par le code ; un point marqué (à vérifier) demande un essai dans le vrai Godot.

## A. Cliquabilité

| Élément | Effet du clic (code) | Verdict |
|---|---|---|
| Plaque d'un club (×2, sigle + nom) | `ouvrir_fiche_club` : pause + page « Fiche du club », « ← Retour au direct » relance. Souligné au survol/focus, curseur main, infobulle. | OK |
| Plaque : nom tronqué (« MEADOWBRID… », 1280) | Même clic ; l'infobulle donne le nom complet | OK (voir C5) |
| Score, minute, période (« 1re MT ») | Rien, et n'a pas l'air d'un lien (pas de souligné, pas de curseur) | OK |
| Journal : nom d'un de NOS joueurs (souligné) | Survol : mini-fiche ; clic : fenêtre Équipe sur lui (pas la fiche complète du joueur) | À CORRIGER (A1) |
| Journal : minute, texte, noms adverses | Rien ; non soulignés | OK. Mais l'adversaire n'a ni mini-fiche ni fiche : acceptable seulement car non souligné |
| Bannière ESSAI / MI-TEMPS / FIN | `MOUSE_FILTER_IGNORE`, rien, aspect non cliquable. Le nom du marqueur n'est pas un lien | OK / AVIS |
| Phrase « X a le ballon… » | Rien, non soulignée | OK |
| Météo (aux arrêts) | Infobulle seule | OK |
| Pause · Espace | Pause/Reprendre | OK, sauf menu ouvert (A2) |
| Échap · Pause et menu | `ouvrir_menu` | OK |
| ÉQUIPE / PARAMÈTRES / PLUS | Viennent de `match_between.gd` (hors périmètre) ; ÉQUIPE ouvre la fenêtre Équipe | Hors périmètre |
| Menu : Reprendre, Réglages, Quitter | Reprise ; page Réglages ; 1er appui arme (texte change), 2e ferme le jeu | OK |
| Menu : « ◂ Normale ▸ » | Tout clic, même sur ◂, avance d'un cran (`_changer_vitesse(1)`) ; ←/→ au clavier seulement | À CORRIGER (A3) |
| Menu : fond noir | Voile `MOUSE_FILTER_STOP` : un clic dessus ne fait rien ni ne ferme | AVIS |
| Fiche club : onglets Vue d'ensemble / Effectif / XV type / Statistiques | Agissent en place | OK |
| Fiche club : **Calendrier** | `_calendar()` crée un `AcceptDialog` (petite fenêtre) ; liens des adversaires via `Link.button`. Pendant un match : indisponibilité non écrite | BLOQUANT (A4) |
| Fiche club : **Comparer** | `_compare()` crée un `AcceptDialog` | BLOQUANT (A4) |
| Fiche club : **Recruter** et clic sur un joueur de l'effectif (`_open_dossier` → `_recruit`) | `interclub_market_view.open` = `AcceptDialog`/Window, qui appelle `_clear_dialogs()` | BLOQUANT (A4) |
| Fiche club : **Suivre le club / Ne plus suivre** | `club_follow` ; sur NOTRE club (plaque de gauche ou de droite selon le cas) le bouton n'a pas de sens | À CORRIGER (A5) |
| Fiche club : « Meadowbridge Rovers » (Prochain match), titres de cartes | Selon `Link.available` ; non vérifié ici | À vérifier |
| Réglages (page) : **Championnats suivis…** | `leave` est vide dans la page ; `league_detail_view.open_career` ne fait RIEN si `leagueDetail.available` est faux, sinon ouvre un dialogue | BLOQUANT (A6) |
| Réglages : **Importe un pack personnalisé** | `app.pack_manager.open(...)` : dialogue ; la page du direct reste ouverte dessous | BLOQUANT (A6) |
| Réglages : **Aide du coach** | `call_deferred("_open_coach")` ; `if is_instance_valid(coach)`, sinon RIEN ; sinon dialogue | BLOQUANT (A6) |
| Réglages : Plein écran / Fenêtré, curseurs, bascules | Agissent en place | OK |
| « ← Retour au direct / au menu du match » | Ferme la page | OK |

**A1.** Règle Léo : clic sur un nom de joueur = fiche complète. Ici : fenêtre Équipe (composition). Faire ouvrir la fiche du joueur dans une page du direct (comme la fiche club), « Retour au direct » ; ou à défaut assumer et le dire dans la mini-fiche (« Clic : voir dans l'équipe »).

**A2.** Le bandeau haut (z_index 1) est au-dessus du voile du menu : le bouton Pause (libellé « Reprendre » sur la capture) relance le match sous un menu resté ouvert (`_pause` ne ferme pas le menu). Soit le menu se ferme (`fermer_menu(false)`) quand on appuie sur Pause, soit Pause est désactivé tant que le menu est ouvert. Même question pour PARAMÈTRES/PLUS au-dessus du voile.

**A3.** Rendre ◂ et ▸ deux zones cliquables distinctes (sens −1 / +1), ou ne montrer les flèches que si elles agissent.

**A4.** Ces trois liens ouvrent des fenêtres, donc B, et d'après le brief n'aboutissent à rien d'utile pendant le match. Solution : sur la fiche ouverte depuis le direct, les passer en lien désactivé (`disabled`, ivoire 3, infobulle/ligne « Disponible après le match »), ou ouvrir un contenu dans la page (calendrier en liste sous l'onglet, comparaison en carte). Idem la ligne d'effectif : curseur main et clic → mini-fiche au survol + « Disponible après le match ».

**A5.** Sur notre propre club : masquer Suivre / Comparer / Recruter (ou les désactiver avec la raison).

**A6.** Dans la page Réglages du direct, griser ces trois boutons avec « Disponible après le match » (le reste de la page est utilisable). Ne jamais laisser un clic sans réponse.

## B. Petites fenêtres

- BLOQUANT : Calendrier, Comparer, Recruter (fiche club) et les trois boutons des Réglages (A4/A6) créent des `AcceptDialog` / Window hors exceptions. Même cause, même correction.
- Hors périmètre à confirmer : PARAMÈTRES de la bande ouvre-t-il `preferences_window()` (AcceptDialog) pendant le match ? Sinon OK.
- Conformes : menu Échap (exception de Léo), « Confier la fin à l'adjoint » dans le menu, mini-fiche au survol, bannière sans fenêtre.
- AVIS : `echap()` ferme la page sous une fenêtre ouverte (le dialogue reste orphelin) ; disparaît avec la correction de A4.

## C. Fidélité à la maquette (variante 1, bannière de -2, menu de -3)

BLOQUANT
- Aucun écart d'or dans le périmètre : plaques et bannière évitent l'or (`fond_plaque`, `fond_bandeau`). Mais la capture montre **ÉQUIPE en jaune doré plein** dans la bande des commandes (1920 et 1280). Hors périmètre (`match_between.gd`) mais visible sur CET écran : à faire passer au chantier Entracte (ivoire plein, « un seul bouton plein »).

À CORRIGER
- C1. Fiche club depuis le direct : une donnée incohérente. Elle affiche « Aucun match prévu entre ces deux clubs cette saison » et « Aucune confrontation » alors que le match entre ces deux clubs est en cours (et « Prochain match : Meadowbridge Rovers »). Prendre le match en cours comme confrontation (ou masquer la carte).
- C2. Titre doublé : la page dit « FICHE DU CLUB » et la fiche répète « FICHE DU CLUB » ; les boutons Suivre / Calendrier / Comparer / Recruter et les onglets sont des boîtes entièrement encadrées avec icône (charte §3 : aucun cadre complet ; §7 : liens texte + flèche). À convertir avec le style « lien » commun (immersive08/components.gd).
- C3. Animations réduites : `_montrer_jeu` fait un fondu de 0,5 s (voile et entracte) sans regarder `reduced_motion`. La bannière, elle, est posée d'emblée (conforme). Passer le fondu à 0 si `_calme()`.
- C4. Le menu : la maquette -3 montre une icône par option (▶, réglages). Absentes : écart mineur, mais « Vitesse du match » n'a pas de repère d'interactivité à part ◂ ▸ (voir A3).
- C5. 1280 : « MEADOWBRID… » tronqué sur la plaque ET « Meadowbridge Rove… » tronqué dans la bande ; il reste de la place sous le bandeau. Donner un seuil plus large au plafond (`plafond`) ou abréger sur le nom court du club (abbr + nom court) plutôt que « … » ; le journal en 1280 (600 px, deux lignes de texte coupées) passe à 3 lignes : garder la hauteur fixe de deux faits.
- C6. Plaque visiteur : fond rose délavé (capture 1920) à peine plus sombre que l'ivoire ; vérifier le rapport 4,6:1 de l'ivoire sur ce rose (`readable_primary_fill`). Dans la maquette, couleurs franches. La couleur est celle du club : pas d'invention, mais l'assombrissement semble insuffisant.
- C7. La phrase « X a le ballon… » en haut à gauche chevauche le bord de l'écran et la bande publicitaire du stade (capture 1) ; sur la bannière d'essai elle double l'info (« Essai — Alder Fen XV ») : la masquer pendant la bannière.

AVIS
- Le focus du menu est un cadre complet ivoire 2 px (comme la maquette) : accepté comme indicateur de focus, seul cadre complet de l'écran.
- La bannière suit la maquette (ESSAI italique, filet, nom, « Club · 9e minute », +5, score ; 600 ms ; aucun flash). Le « ESSAI — nom » du marqueur pourrait être un lien vers sa mini-fiche (survol) : cohérent avec la règle des noms.
- Pause garde son libellé seul (sans icône), écart déclaré §6.
- Données : aucun nom de club ni de championnat figé relevé dans les fichiers du périmètre (noms lus dans le modèle). Les valeurs de la maquette (Alder Fen, Northmere) n'apparaissent pas dans le code.

## Suivi : auto-relecture après corrections (20/11/2026, après-midi)

Vérifié dans le vrai Godot (suite `godot-match-direct-da`, 56 contrôles, 0 échec, sur le commit des corrections) et sur les captures `film1920b` / `film1280b` (bureau séparé) :

| Point | État |
|---|---|
| A1 fiche joueur | Clic sur un nom du journal : fiche complète du joueur dans le direct, « ← Retour au direct », liens hors match grisés. Corrigé. |
| A2 voile du menu | Le voile passe au-dessus des commandes ; la plaque est inactive tant que le menu est ouvert. Corrigé. |
| A3 ◂ / ▸ | Deux boutons distincts : ◂ ralentit, ▸ accélère (contrôlé). Corrigé. |
| A4 / A5 fiche club | Calendrier, Comparer, Recruter absents ; « Calendrier : disponible après le match » écrit ; pas de « Suivre » sur notre club ; aucun clic muet, aucune fenêtre. Corrigé. |
| A6 Réglages | Championnats suivis, pack, aide du coach grisés « · disponible après le match ». Corrigé. |
| B petites fenêtres | Aucune fenêtre ouverte par un clic (contrôlé sur plaque, nom, menu, réglages, confier la fin). Reste : menu Échap (exception de Léo). |
| C1 confrontation | « Match en cours · 18e minute » et le score du direct dans Tes confrontations et Saison en cours (capture `fiche-club.png`). Corrigé. |
| C2 titre doublé | Un seul « FICHE DU CLUB » ; la page n'a plus que « ← Retour au direct ». Les cartes et la pastille « Riche » de la fiche club restent celles de l'écran Club (hors périmètre). |
| C3 mouvement réduit | Coupe franche si mode calme (`_montrer_jeu`). Codé ; suite temps-forts verte (tous modes). |
| C5 nom court 1280 | « MEADOWBRIDGE » (nom court) au lieu de « MEADOWBRID… » (capture 1280). Corrigé. |
| C6 plaques | Contraste ivoire ≥ 4,5:1 contrôlé sur les deux plaques. Corrigé. |
| C7 phrase du ballon | Masquée pendant la bannière d'essai (capture du menu). Corrigé. |

Reste hors périmètre : « ÉQUIPE » en or plein et « PARAMÈTRES » dans la bande des commandes (`match_between.gd`, chantier Entracte).

## Relecture adverse 20/11 après-midi

Lecture seule (code `live_view.gd`, `match_temps_forts.gd`, `match_journal.gd`, `match_action_review.gd`, `match_between.gd`, `club_sheet_canvas.gd` + captures 1920/1280, maquette 13-1 et 13-3). Rien lancé. Ce qui suit ne reprend pas la relecture interne ni les écarts déjà connus (ÉQUIPE or, cartes de la fiche club).

### A. Cliquabilité (éléments que la relecture interne n'a pas passés)

| Élément | Effet du clic (code) | Verdict |
|---|---|---|
| PLUS ▾ → « Journal du match » → ligne « 12 min · Essai ↗ » (`JournalActionLink`, souligné/or, curseur main) | `_review` → `match_action_review.gd` qui `extends AcceptDialog` : petite fenêtre au-dessus du match | BLOQUANT (B1) |
| Tiroir Journal : champ de recherche, filtre catégorie (`OptionButton`), « Dernier » / « Relire » | Agissent en place ; « Relire » ouvre la même fenêtre | BLOQUANT (B1) ; filtre = exception OK |
| Tiroir Journal : noms de joueurs dans le texte des faits | Texte simple, ni lien ni mini-fiche (alors que le journal du bas lie nos joueurs) | À CORRIGER (C3) |
| PARAMÈTRES (bande) | `_ouvrir_parametres` : `PopupPanel` (cadre or 40 %, coins arrondis) posé sous le bouton, vitesse + temps forts montrés | BLOQUANT (B2) |
| PLUS ▾ | `MenuButton` : menu déroulant (Statistiques, Journal, Confier, 3 caméras) | OK (exception menu déroulant) |
| ÉQUIPE | Page plein écran `MatchTeamWindow` (un `Control`, pas une fenêtre) ; pose le match en pause | OK sur le principe |
| Pause · Espace / Échap · Pause et menu | Pause ; ouvre le menu | OK |
| Puce « T » de la maquette sur ÉQUIPE | Absente à l'écran : le raccourci T existe (`_input`) mais n'est écrit nulle part | À CORRIGER (C4) |
| Bannière ESSAI : nom du marqueur (notre joueur) | `MOUSE_FILTER_IGNORE`, rien ; c'est un nom de joueur | AVIS (C3) |
| Tiroir Statistiques | Texte seul, FERMER × en lien | OK |
| Fiche club de NOTRE club, onglet Effectif : lignes de joueurs | `neutraliser` grise tout bouton hors onglets/suivi/tri : les lignes (`ClubSheetRow`, noms `_player_link`) deviennent « Disponible après le match » alors que la fiche complète de NOS joueurs existe (`ouvrir_joueur`) | À CORRIGER (C2, à vérifier dans Godot) |
| Menu : clic sur la ligne « Vitesse » | +1 cran, boucle de Éclair à Posée sans prévenir | AVIS |
| Voile du menu | Avale le clic, ne ferme rien | AVIS (déjà vu) |

### B. Petites fenêtres

- B1 BLOQUANT : tiroir Journal → « ↗ » / Relire ouvre un `AcceptDialog` (`match_action_review.gd`) pendant le match, hors exceptions. Même famille que A4 de la relecture interne, mais sur le tiroir, non couvert. Correction : ouvrir le relecteur dans une page du direct (`_ouvrir_page("relecture")`, « ← Retour au direct »), ou retirer le « ↗ » (et l'aspect lien) pendant le match.
- B2 BLOQUANT (confirme le doute laissé par la relecture interne) : PARAMÈTRES ouvre un `PopupPanel` avec cadre or et coins arrondis. Ce n'est ni mini-fiche, ni menu déroulant, ni menu Échap. Correction : le faire ouvrir la page « Réglages » du direct (celle du menu), ou en faire un menu déroulant de choix simples (vitesse de l'horloge : Posée/Normale/Rapide/Éclair, comme `_changer_vitesse`) ; en tout cas supprimer le cadre or et les coins arrondis. À traiter avec le chantier Entracte, mais à décider ici puisque l'écran en dépend.
- Conformes : menu Échap, mini-fiche, PLUS (menu), plaques, menu « Confier la fin ».

### C. Fidélité à la maquette et à la charte

BLOQUANT
- C0. Même contenu que B1 et B2 (fenêtres hors exception). Pas d'autre écart bloquant dans le périmètre : aucun nom de club ni de championnat figé relevé.

À CORRIGER
- C1. Tiroir Journal (PLUS → Journal du match, `match_journal.gd`) resté dans l'ancien style : liens « ↗ » en OR, champs avec cadre or complet de 2 px et coins arrondis (`G.T.box(..., 3, G.GOLD)`), texte `G.INK`/`G.MUTED` sur fond PAPIER. L'or est réservé à Continuer et à l'héritage ; aucun cadre complet. À convertir en jetons Charte (ivoire, ivoire 2, lien souligné) comme le tiroir Statistiques.
- C2. Tiroir (Stats et Journal) : `live_view.gd::_construire_tiroir` pose un cadre complet de 1 px (`set_border_width_all(1)`, FILET) ; charte §3 : aucun cadre complet. Remplacer par un filet gauche seul (ou aucun filet, panneau à 85 % comme le journal du bas).
- C3. Règle des noms de joueurs non tenue partout : dans le journal du bas seuls NOS joueurs sont liés ; les noms adverses, le marqueur de la bannière d'essai et ceux du tiroir Journal sont du texte. Pour nos joueurs au moins (bannière, tiroir), mini-fiche au survol + clic = fiche (réutiliser `liens_joueurs`). Pour les adversaires : à décider avec Léo (fiche inexistante, `fiche_commune.trouver` ne cherche que `squad`).
- C4. Maquette 13-1 : « ÉQUIPE » avec la puce « T » et « Pause » avec « Espace » ; à l'écran la puce « T » manque (la puce Espace est là). Ajouter « T » (travail de `match_between.gd`, à porter au chantier Entracte, ou à défaut dans l'infobulle).
- C5. Puces de touche (`_touche`) et toutes les puces du menu : rayon de 2 px, charte §3 : rayons 0 (maquette : angles droits). Mettre 0.
- C6. Fiche ouverte depuis le direct, onglet Effectif de notre club : lignes grisées au lieu de mener à la fiche du joueur (voir A, à vérifier dans Godot). Les rediriger vers `ouvrir_joueur`.

AVIS
- Repli sans régie (`CD_MATCH_TEMPS_FORTS=0`) : barre du bas avec `OptionButton` « Cadence » et « Niveau » non habillés, absente des captures ; à photographier si ce mode doit vivre.
- Fenêtre Équipe (`match_equipe.gd`) : encore or, pastilles arrondies, cadres complets (C.GOLD, `_boite(..., 10, 2, 0)`) ; chantier Entracte/Équipe, à signaler à Léo car c'est le premier clic de la bande.
- Menu : « Quitter le match » ferme le jeu au 2e clic ; le texte prévient bien, mais la ligne n'est pas distinguée des autres (aucun signe que c'est irréversible).
- Les captures montrent le journal à deux lignes de hauteur fixe et la bannière d'essai de 744 px comme la maquette ; bannière à la couleur du club conforme.
### Suivi des corrections (20/11/2026, soir)

Vérifié dans le vrai Godot (`godot-match-direct-da` : 76 contrôles, 0 échec ; `godot-match-journal`, `godot-match-action-review` mis à jour, verts) et sur les captures `film1920c` / `film1280c` (`journal.png`, `relecture.png`).

| Point | État |
|---|---|
| B1 « Relire » / « → » du tiroir | Page « RELIRE LES ACTIONS » du direct, match en pause, « ← Retour au direct » ; aucune fenêtre (contrôlé). Hors du direct (ancien écran Match), la fenêtre reste. Corrigé. |
| C1 tiroir Journal | Jetons de la Charte : champs sur panneau 3 soulignés d'un filet, focus en filet ivoire, liens texte « Relire → », « Dernier fait ↓ », aucun or, rayons 0, liste déroulante à angles droits. Corrigé. |
| C2 cadre du tiroir | Filet à gauche seul ; anneaux de focus des défilements retirés. Corrigé. |
| C3 noms | Tiroir : nos joueurs soulignés, mini-fiche au survol, fiche complète au clic ; bannière d'essai : notre marqueur souligné et cliquable. Adversaires : pas de fiche complète dans les données (effectif adverse non chargé) → texte inerte, sans soulignement. Corrigé. |
| C5 puces | Rayons 0 sur les puces de touche et du menu (contrôlé). Corrigé. |
| C6 effectif de notre club | Les lignes de nos joueurs restent actives et ouvrent leur fiche dans le direct ; les autres liens restent grisés. Corrigé. |
| AVIS voile / Quitter | Clic sur le voile : menu fermé, match relancé. « Quitter le match » écrit « Ferme le jeu » à droite. Fait. |

Laissés au chantier Entracte : B2 (PARAMÈTRES en PopupPanel), C4 (puce « T »), fenêtre Équipe.