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
