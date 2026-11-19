# Bibliothèque des motifs d'interaction — Rugby Legacy 27

Décisions de Léo du 19/11/2026 intégrées : règle unique d'Échap (fenêtre, puis retour de fiche, puis menu pause ; pause en match) + bouton « Menu » visible dans la coque ; densité « Football Manager » (voir `design/accessibility-requirements.md`) ; Formation, Centre et Suivi des jeunes fusionnés en une seule page Formation.

> **Statut** : Brouillon d'état des lieux (relevé du code, pas une cible de conception)
> **Auteur** : ux-designer (CCGS), mode autonome, rigueur `minimal`
> **Dernière mise à jour** : 19/11/2026
> **Moteur / UI** : Godot 4.7, nœuds Control construits en GDScript
> **Périmètre** : carrière Monde, PC souris/clavier. Aucune manette dans le code relevé (voir « Motifs manquants »).
> **Documents liés** : `.claude/docs/templates/interaction-pattern-library.md` (gabarit) ; aucune spécification d'écran n'existe encore sous `design/ux/`

## Comment lire ce document

Chaque motif décrit **ce que le code fait aujourd'hui** (fichier cité), pas ce qu'il devrait faire. Les écarts entre écrans sont signalés par **Incohérence** : ce sont des pistes d'amélioration, classées en fin de document. Ce qui n'a pas été lu dans le code est marqué **non vérifié**.

Fichiers de référence (tous sous `native/godot/`) :

| Sigle | Fichier |
|---|---|
| shell | `ui/immersive08/shell.gd` (coque : barre latérale, barre haute, pied de page) |
| C / D | `ui/immersive08/components.gd`, `ui/immersive08/primitives.gd` (boutons, cartes, pastilles, jauges) |
| tableau | `ui/socle/tableau.gd`, `ui/socle/ecran_effectif.gd`, `ui/socle/jetons.gd` |
| clavier | `ui/raccourcis_clavier.gd` (Espace, 1-9, Échap, Ctrl F) et `ui/navigation_controller.gd` (Ctrl K/S/J, F1, Alt+flèches, accès rapide) |
| main | `main.gd` (`confirm`, `notice`, Échap global, `primary_text`) |
| courrier | `ui/immersive08/reception_canvas.gd` |
| compo | `ui/immersive08/tactics_canvas.gd` (fenêtre de candidats, liste hors feuille) ; `ui/lineup_board.gd` (ancien terrain 15 cases) |
| attente | `ui/command_wait_overlay.gd`, `ui/save_indicator.gd` |
| Gabi | `guide/coach_guide.gd`, `guide/coach_bubble.gd`, `guide/gabi_*.gd` |

## Règles communes (valables pour tous les motifs)

- **Échelle** : gabarits dessinés pour 2560 × 1440, mis à l'échelle (`C.px`, `C.density` entre 0,5 et 1). Plancher de texte actuel dans le code 12 px (`C.label`, `D.text`) ; cible (décision de Léo, 19/11/2026) : échelle dense, corps ~13 px, tableaux 12-13 px, en-têtes 11-12 px, jamais sous 11 px réels à 1080p, avec échelle d'interface 90/100/115/130 %. Sous la densité 0,75, les commandes serrées montent à 25 px de cible minimale (`C.reach`, `C.reach_controls`).
- **Focus** : liseré or (`C.GOLD`, `J.OR`) de 2 px autour du contrôle ciblé. Toujours visible au clavier.
- **Info-bulle** : `tooltip_text` natif de Godot, sans délai personnalisé ; sert aussi de nom accessible (`accessibility_name`) sur la plupart des boutons riches.
- **Aucune commande moteur pour trier, filtrer ou sélectionner** : ce sont des états d'interface (commentaire de `ecran_effectif.gd`).
- **Mouvements réduits** : respectés par l'indicateur de sauvegarde et le panneau d'attente (image fixe). Les autres animations : non vérifié.
- **Manette** : aucun code de manette relevé dans les fichiers lus.

---

## Catalogue

| Motif | Catégorie | Où |
|---|---|---|
| Navigation latérale (barre de 248 px) | Navigation | Tous les écrans de carrière |
| Sous-navigation de chapitre | Navigation | Effectif/Vestiaire, Tactique, Club, Compétitions, Formation |
| Barre haute : fil d'Ariane, historique, recherche | Navigation | Tous |
| Accès rapide (Ctrl K / Ctrl F) | Navigation | Tous |
| Bouton Continuer + Jour suivant | Action principale | Tous |
| Raccourcis clavier globaux | Navigation | Tous |
| Bouton (principal / secondaire / compact) | Entrée | Partout |
| Pastille de filtre | Entrée | Réception, Effectif |
| Tableau trié (socle) | Liste | Effectif |
| Liste de courriers (lignes-boutons) | Liste | Réception |
| Carte de réponse | Entrée | Réception (courrier du club) |
| Fenêtre de candidats | Fenêtre | Composition |
| Liste « hors feuille » | Liste | Composition |
| Boîte de confirmation / d'avis | Fenêtre | Global |
| Info-bulle | Retour | Partout |
| Pastille d'état (chip) | Retour | Partout |
| Jauge / barre de niveau | Retour | Effectif, fiche joueur, Bureau |
| Pied de page d'état | Retour | Tous |
| Indicateur de sauvegarde | Retour | Global |
| Panneau d'attente | Retour | Continuer, commandes longues |
| États vide / erreur | Retour | Partout |
| Gabi : bandeau, bulle, aide F1 | Aide | Tous |
| Pastilles V/N/D | Retour | Préparation |

---

## Navigation

### N1 · Navigation latérale

**Quand l'utiliser** : changer de chapitre de la carrière. Toujours visible (rail de 248 px, `shell._sidebar`).

**Souris** : clic sur une entrée (49 px de haut). Info-bulle « Nom (n) » pour les 9 premières. Le logo du club ouvre le menu pause (« Menu, sauvegardes et paramètres »). Pied de rail : Carrière, Réglages, Sauvegarder.

**Clavier** : touches 1 à 9 (rang de l'entrée, tel qu'affiché ; `raccourcis_clavier._menu`). Tab/flèches déplacent le focus entre les boutons nommés `Nav_*`.

| État | Rendu |
|---|---|
| Normal | Texte clair, fond transparent, icône grise |
| Survol / pressé | Styles de bouton, marge gauche conservée |
| Sélectionné | Fond teinté club, barre verticale de 4 px à gauche, icône ivoire |
| Focus | Liseré or, agrandi de 2 px |
| Désactivé | Aucun cas relevé (une entrée n'est jamais grisée) |
| Non lus | Pastille or avec nombre sur Réception |

**Où** : tous les écrans de carrière. En sélection nationale, trois entrées seulement.

**Incohérences** :
- Les touches 1-9 suivent l'ordre du rail, **Réception en 1 et Bureau en 2** ; le pied de page dit « 1 à 9 Menus » sans donner la correspondance. « Sélections » (11e entrée) n'a pas de chiffre.
- Le rail place « Entraînement » et « Tactique » en deux entrées, mais l'accès rapide les nomme « Menu · Entraînement · Équipe » : deux noms pour le même écran.
- Le rail et le fil d'Ariane n'utilisent pas toujours le même libellé (route « Composition » affichée « Tactique » dans le fil, « Composition » dans la sous-navigation).

### N2 · Sous-navigation de chapitre

**Quand** : écrans d'un même chapitre (`shell.GROUPS`) : Effectif/Vestiaire, Composition/Préparation/Plan de jeu/Match, Club/Staff/Travail du club/Stratégie, Classements/Calendrier/Rivalités, Formation (page unique : Centre retiré et Suivi des jeunes fusionné, décision de Léo du 19/11/2026).

**Souris/clavier** : rangée de boutons en MAJUSCULES (`Section_<nom>`), bouton actif surligné. Pas de raccourci dédié ; Tab seulement.

**Incohérence** : masquée pour Composition et pour Effectif dès 1600 px ; absente des écrans « canevas » dédiés (Presse, Finances…), où chaque canevas redessine ses propres onglets (`D.tab_state` : club_sheet, press, rivalry). Trois façons de faire des onglets, aucune ne répond à une touche (pas de Ctrl+Tab ni de chiffre).

### N3 · Barre haute (fil d'Ariane, historique, recherche, date)

**Quand** : se repérer, revenir en arrière, ouvrir un joueur/club, voir la date.

**Souris** : flèches ← → (historique), champ « Rechercher… » (ouvre l'accès rapide, ce n'est pas un vrai champ de saisie), date cliquable (ouvre le Calendrier au jour courant). Info-bulle de la recherche = phrase complète quand le libellé est raccourci (« Rechercher… »).

**Clavier** : Alt + ← / → (historique, sauf si le focus est dans un champ), Ctrl K ou Ctrl F (recherche).

**États** : le libellé de la recherche change selon le contexte (« un joueur, un menu… » / « un joueur, un club… » / « un écran… » en sélection). Pastille « Ctrl K » masquée en petite fenêtre (raccourcis regroupés dans le pied).

**Incohérence** : le fil d'Ariane est du **texte non cliquable** (seul le logo « maison » est une icône) ; il ressemble à un fil d'Ariane web mais ne l'est pas. Les touches dites dans le pied (« Ctrl F ») et dans le champ (« Ctrl K ») diffèrent.

### N4 · Accès rapide (palette)

**Quand** : aller à n'importe quel menu, joueur, club, membre du staff, compétition ou sélection (`navigation_controller.open_palette`).

**Souris** : fenêtre « Ton carnet · accès rapide » ; double-clic ou bouton OUVRIR active le résultat.
**Clavier** : Ctrl K / Ctrl F ouvre ; ↑ ↓ choisissent (le focus reste dans le champ) ; Entrée ouvre ; Échap ferme et **rend le focus** à l'élément d'origine (`_restore_palette_focus`).

| État | Rendu |
|---|---|
| Vide (pas de saisie) | Liste complète limitée à 12 lignes ; compteur « n résultat(s) · les 12 premiers, précise ta recherche » |
| Aucun résultat | « Aucun résultat · essaie un autre nom ou menu. » et OUVRIR désactivé |
| Recherche | Insensible aux accents (`U.fold`) |
| Fiche non accessible | Candidats filtrés par `entity_available` (non affichés, pas grisés) |

**Où** : global. Indice affiché : « ↑ ↓ choisir · Entrée ouvrir · Échap fermer » (le seul endroit où le trio est écrit à l'écran).

**Incohérence** : la ligne de résultat est un texte long « Effectif · Nom · Poste · dossier [id] » : l'identifiant technique `[id]` est visible dans le libellé (à vérifier à l'écran, il apparaît dans le code du libellé).

### N5 · Raccourcis clavier globaux

Table unique `raccourcis_clavier.TABLE` (pied de page, F1, paramètres la lisent) :

| Touche | Effet | Dans le pied de page |
|---|---|---|
| Espace | Ouvre le prochain message non lu ; sinon active Continuer | oui |
| 1 à 9 | Menus de gauche | oui |
| Échap | **Règle unique (décision de Léo, 19/11/2026)** : (1) ferme la fenêtre ouverte ; sinon (2) revient d'une fiche ou d'un sous-écran ; sinon (3) ouvre le menu pause ; **en match : pause** (jamais de sortie, décision du 16/11) | oui (« Échap Menu » sur un écran principal, « Échap Retour » dans une fiche) |
| Ctrl F / Ctrl K | Accès rapide | oui |
| F1 | Gabi, aide de l'écran | oui |
| Ctrl S | Sauvegarder | non |
| Ctrl J | Jour suivant (+1 j) | non |
| Alt ← / → | Historique | non |

**Garde-fous** (`actif()`) : aucun raccourci si champ de saisie focalisé, fenêtre ouverte, réunion ou match immersif, intro, attente, ou barre de progression. Après Tab ou une flèche, Espace appartient au bouton ciblé (`_focus_clavier`).

**Incohérences** :
- **Échap a quatre sens dans le code** : (1) ferme une fenêtre ouverte, (2) revient de la fiche joueur/club, (3) arrête la progression « Continuer » (`main._unhandled_key_input` + `request_stop`), (4) **sinon ouvre le menu pause** de la carrière (`pause_menu`). **Résolu par décision de Léo (19/11/2026)** : la règle unique ci-dessus est la cible ; le comportement (4) est confirmé, il faut seulement annoncer « Échap Menu » au pied de page et ne jamais ouvrir la pause juste après la fermeture d'une fenêtre ou d'une fiche (un appui = une action). L'arrêt de « Continuer » (3) reste prioritaire pendant la progression.
- **Accès au menu pause sans clavier (décision de Léo, 19/11/2026)** : bouton visible dans la coque, soit le logo/écusson du club en haut du rail (déjà ouvre le menu, voir N2 ; à rendre évident par une infobulle et un focus), soit un bouton « Menu » dans la barre haute. Le menu pause ne dépend donc plus d'Échap seul.
- Ctrl J et Alt ← / → ne sont écrits que dans les infobulles et les Réglages, pas dans le pied de page.
- Espace « prochain non lu » ne montre rien à l'écran quand il bascule de la lecture à Continuer sauf dans l'infobulle du bouton (` · Espace : continuer`).

### N6 · Bouton Continuer et Jour suivant

**Quand** : avancer le temps. Seule action principale permanente (barre haute, à droite).

**Souris** : « Continuer » (bouton plein teinté club, flèche), puis « +1 j » (petit bouton, ajouté seulement les jours où l'on peut avancer d'un seul jour). Info-bulle = `primary_tooltip()` (explique pourquoi, ex. « Le moteur du jeu s'est arrêté. Clique pour le relancer »).
**Clavier** : Espace (voir N5), Ctrl J pour +1 j.

| État | Rendu |
|---|---|
| Libellé | Le shell le crée « Continuer » ; `main.primary_text()` renvoie des variantes en capitales avec flèche (« RETOUR AU DIRECT → », « OUVRIR LA CONFÉRENCE DE PRESSE → », « SAISON SUIVANTE → », « RELANCER LE MOTEUR → »). Où le libellé est appliqué : non vérifié |
| Désactivé | Style `disabled` standard ; Espace ne l'active pas |
| En cours | Barre de progression `continue_progress` ; Échap l'arrête |
| Match en direct (Bureau) | Le bouton se décale à gauche (`TOPBAR_MATCH_ACTION_LEFT`) |

**Incohérence** : le bouton est le seul de l'écran qui change de **verbe** selon l'état ; les autres écrans qui avancent (« Valider les 23 », « Valider le résultat ») ne passent pas par lui. Pas de mention du jour dans le bouton.

---

## Entrées

### E1 · Bouton

Deux familles à ne pas confondre :
- **Bouton plat C.button** (`components.gd`) : fond panneau, liseré, pressé vert foncé, focus or ; variante `primary` (fond teinté club, liseré clair, texte garanti lisible par `readable_primary_fill`).
- **Bouton posé D.button** (`primitives.gd`) : mêmes états mais fond dégradé, icône à droite (flèche par défaut), `clip_text`, taille fixée par un rectangle du gabarit ; variante `small` (21 px au lieu de 25).

| État | Rendu |
|---|---|
| Normal | Fond sombre, liseré gris (primaire : vert) |
| Survol | Fond plus clair, liseré ivoire (primaire : menthe) |
| Pressé | Fond vert foncé / assombri |
| Focus | Liseré or de 2 px, agrandi de 2 px pour le primaire |
| Désactivé | Fond et liseré éteints, texte `FAINT` |
| Chargement | **Aucun état propre** : `app.waiting` désactive les boutons concernés (réponses de courrier, conférences, bascules) |

**Comportement** : une commande moteur part au clic ; l'interface ne modifie pas l'état du jeu directement. Les boutons rendus inactifs par `app.waiting` n'expliquent pas pourquoi.

**Incohérences** :
- Pas de style « destructif » : « Libérer ce poste », « Archiver », « Désactiver » (Gabi) ont l'apparence des autres boutons.
- **Le style des boutons de Gabi** (`coach_guide._button`, 32 px, police 12) est distinct de C.button : cinquième variante de bouton avec les boutons du socle (`ecran_effectif._bouton`) et l'ancien thème Legacy.
- Plusieurs écrans redessinent leur propre état de survol (ligne de courrier, carte de réponse, ligne hors-feuille) avec des teintes différentes (`RAISED`, `RAISED.lightened(.08)`, vert `234331`).

### E2 · Pastille de filtre

**Quand** : restreindre une liste à une catégorie (≤ 5-6 choix, un seul actif).

**Réception** (`_list_filters`) : pastilles « Tous / Non lus n / … » + menu **Sujet** (liste de catégories, favoris, archives). Rayon 22, actif = fond teinté club.
**Effectif** (`ecran_effectif`) : pastilles « Tous, 40 / Avants, 20 / Arrières, 20 / Fin de contrat cette saison, n / À surveiller, n » + recherche texte (`LineEdit`, bouton d'effacement, insensible aux accents) + vues.

**Souris** : clic = active ; re-clic ne désactive pas. **Clavier** : Tab / focus, Entrée ou Espace. Pas de raccourci par chiffre.

| État | Rendu |
|---|---|
| Actif | Fond plein (Effectif : ivoire avec texte sombre ; Réception : teinte du club) |
| Focus | Liseré or |
| Compte | Dans le libellé (« Tous, 40 »), sauf Réception où le compte de « Non lus » est entre le libellé |
| Résultat vide | Voir V3 |

**Incohérences** :
- Deux pastilles de rayons et de couleurs actives différentes (ivoire sur Effectif, vert club sur Réception).
- Format du compte différent : « Tous, 40 » (virgule) / « Non lus 3 » (espace).
- Le filtre n'est **pas mémorisé** de la même façon : Effectif garde son état dans `management_ui`, Réception le remet à « Tous » à l'ouverture du prochain non lu (`open_next_unread`).
- Un filtre actif qui masque le message sélectionné est **remis à « Tous » en silence** (`reception_canvas.build`).

### E3 · Tableau trié (socle)

**Quand** : liste dense de plus de 12 lignes comparables (joueurs). Dessiné par `_draw`, lignes virtuelles (40 ou 4 000 coûtent pareil).

**Souris** :
- Clic sur un titre de colonne : tri, un second clic inverse. Flèche or à côté du titre actif. Les colonnes peuvent déclarer `decroissant_d_abord`.
- Clic sur une ligne : la choisit (émet `ligne_choisie`), double-clic : `ligne_activee` (ouvre la fiche).
- Molette : défile de 3 lignes. Barre de défilement verticale à droite, visible seulement si nécessaire.
- Info-bulle par cellule (`infobulle`) et par en-tête (`aide`).

**Clavier** (le tableau prend le focus au clic) : ↑ ↓ (ligne), Pg↑ Pg↓ (page), Début / Fin, Entrée (ouvre). **Pas de tri au clavier.**

| État | Rendu |
|---|---|
| Normal | Filet bas à 55 % |
| Survol | Fond `SURVOL` (`182322`) |
| Choisie | Fond `CHOIX` (`1f2e2b`) ; la sélection suit le clavier et défile pour rester visible (groupe : le titre reste visible) |
| Focus du tableau | Filet de 1,5 px or sous l'en-tête (la ligne choisie n'a pas de liseré propre) |
| Valeur inconnue | Toujours en bas, quel que soit le sens du tri |
| Colonne trop large | Les colonnes les moins prioritaires disparaissent (`priorite`) |
| Groupes | Ligne de titre non cliquable, avec détail (ex. famille de postes) |
| Vide | Texte `message_vide` seul (voir V3) |
| Erreur | Aucun cas |

**Où** : Effectif uniquement (écran socle). Les autres listes sont des piles de boutons (courrier, hors feuille, candidats) ou des tableaux historiques (`ClubViews.tables`, marché de Recrutement).

**Incohérences** :
- **Le seul vrai tableau est Effectif.** Classements, Finances, Recrutement, Formation affichent des listes d'un autre mécanisme, sans tri ni navigation clavier harmonisés (non vérifié écran par écran).
- Le focus du tableau est un simple filet : on ne voit pas que le tableau est « actif » sans regarder l'en-tête.
- Aucun moyen de **trier au clavier** ni d'annoncer le tri aux lecteurs d'écran (tableau dessiné, pas de nœuds par ligne).
- La sélection reste après filtre même si la ligne est masquée (`choisie` conservé, pas de repli).

### E4 · Liste de courriers (lignes-boutons)

**Quand** : liste avec lecture à côté (maître-détail). Chaque courrier est un bouton de 80 px (104 px si « À FAIRE / URGENT »).

**Souris** : clic = sélectionne et marque lu. Bascule de repli pour les fils regroupés (symbole non relevé ; info-bulle « Déplier ou réduire les courriers de la même rencontre… »). Favori, Lu, Archiver dans l'en-tête du mail.
**Clavier** : ↑ ↓ Début Fin (via `_message_key`, active le courrier suivant) ; info-bulle de la liste « ↑ ↓ choisir · Entrée ouvrir le courrier » ; Espace = prochain non lu (N5).

| État | Rendu |
|---|---|
| Non lu | Titre en 700, pastille or à droite, texte ivoire ; lu : titre 500 à 62 % d'opacité |
| Sélectionné | Fond plus clair + liseré or de 5 px à gauche |
| Survol | Fond `RAISED` |
| À faire / Urgent | Étiquette « À FAIRE · avant le … » or ou « URGENT » rouge |
| Fil regroupé | Pastille « ×n » |
| Vide | « Aucun message dans cette vue. / Choisis un autre filtre. » |

**Incohérence** : les flèches changent de courrier ET le sélectionnent aussitôt (le marquent lu) ; dans le tableau d'effectif, flèches = choisir seulement. La **lecture** par défilement n'est pas la même (rien ne marque lu au simple survol, mais tout est marqué dès la sélection par flèche).

### E5 · Carte de réponse (courrier du club)

**Quand** : décision engageante tirée d'un courrier. Chaque réponse est une carte-bouton avec libellé et conséquences (▲ / ▼ / =) tirées des effets réels du moteur.

**Souris/clavier** : clic ou Entrée = envoie la commande **immédiatement** (`_reply_club_mail`), sans confirmation.

| État | Rendu |
|---|---|
| Recommandée (`lead`) | Fond or à 7 %, liseré or |
| Survol | Fond plus clair, liseré or |
| Désactivée | Libellé en `FAINT`, **raison dans l'infobulle** (« Disponible après… ») |
| Après envoi | Bouton désactivé (`_choose_calendar_preparation`) |
| Attente moteur | Désactivée par `app.waiting`, sans message |

**Incohérences** :
- Aucun récapitulatif ni annulation avant l'envoi alors que les conséquences sont chiffrées (coût en euros, moral).
- La raison de l'indisponibilité n'est **visible qu'au survol** ; en lecture au clavier elle n'est visible que si le nom accessible est lu.
- « Libellé » et « conséquences » : les ▲ ▼ sont en couleur ET en symbole (bon), mais le sens positif/négatif n'est pas normalisé avec les pastilles V/N/D (voir F6).

### E6 · Fenêtre de candidats (Composition)

**Quand** : choisir le joueur d'un poste du XV. S'ouvre en cliquant **une seconde fois** sur le poste déjà sélectionné (`_choose_slot`) ; un premier clic ne fait que sélectionner (le focus revient sur le poste après le rendu).

**Contenu** : `AcceptDialog` « Poste 05 · choisir un joueur » (800 × 720), photo, liste défilante d'un bouton par joueur « Nom · Poste · Note · condition % », puis « Libérer ce poste » et « Consignes du joueur ».

**Clavier** : Tab, Entrée, Échap ferme (c'est un `AcceptDialog`).

| État | Rendu |
|---|---|
| Joueur indisponible / non qualifié | Bouton **désactivé**, info-bulle « Indisponible ou qualification incompatible avec ce poste. » |
| Poste vide | « Libérer ce poste » désactivé si la feuille n'est pas modifiable |
| Choix | La fenêtre se ferme et envoie `set_lineup` |

**Incohérence importante** : **deux façons de choisir** :
1. cette fenêtre modale à boutons désactivés (raison unique générique) ;
2. la liste **« hors feuille »** de la page (voir E7) où l'on clique un joueur, **le bouton n'est pas désactivé** et un clic invalide ouvre un avis « Affectation indisponible ».
Les deux n'ont ni le même tri (la liste hors feuille est triée par note, la fenêtre suit l'ordre de l'effectif), ni les mêmes états, ni le même message d'erreur.
Le bouton « OK » du `AcceptDialog` reste affiché sous ses boutons personnalisés (aucune action propre) : non vérifié visuellement.

### E7 · Liste hors feuille (Composition)

**Quand** : voir les joueurs hors du XV/banc et les glisser ou les cliquer.
**Souris** : clic = affecter au numéro sélectionné ; **glisser pour déplacer** (texte d'aide en pied de carte : « Choisir un numéro · clic pour affecter · glisser pour déplacer »). `Selection.wire` branche le glisser-déposer sur le joueur.
**Clavier** : Tab, Entrée (« Clic ou Entrée : affecter à cette cible »).

| État | Rendu |
|---|---|
| Normal | Lignes alternées (zèbre) |
| Survol | Fond vert foncé, liseré menthe |
| Focus | Liseré or |
| Non éligible | Reste actif ; avis modal au clic |
| Vide | « Tous les joueurs figurent sur la feuille. » |

**Incohérence** : même liste de joueurs que la fenêtre de candidats mais deux présentations (ligne portrait + poste + note à droite / bouton long en texte). Le glisser n'a pas d'équivalent clavier.

### E8 · Ancien terrain à 15 cases (`lineup_board.gd`)

Terrain dessiné avec 15 boutons (100 × 50, police 11 px, un clic = sélection + `_render`). **Fichier ancien** : police 11 px (en dessous du plancher de 12 px de la coque), tailles non mises à l'échelle (`C.px` absent). À traiter comme dette ; la Composition actuelle passe par `TacticsCanvas`. Utilisation actuelle non vérifiée.

---

## Fenêtres

### W1 · Boîte de confirmation (`app.confirm`)

**Quand** : action difficile à défaire. `ConfirmationDialog` 650 px, boutons **CONFIRMER / ANNULER** (génériques), option `focus_cancel` pour donner le focus à ANNULER.

**Clavier** : Entrée = CONFIRMER si c'est le bouton par défaut, Échap = annule.

**Incohérences** :
- Le libellé du bouton est toujours « CONFIRMER » : il ne dit pas l'action (ex. « Récupérer le profil »).
- **Le focus par défaut est sur CONFIRMER** sauf demande expresse ; seules quelques actions passent `focus_cancel`. Aucune règle écrite.
- Aucun bouton rouge pour les actions destructives.

### W2 · Boîte d'avis (`app.notice`)

`AcceptDialog` 620 px, un seul bouton OK. Sert d'**erreur** (« Affectation indisponible ») comme d'information : aucune distinction visuelle entre les deux (pas d'icône, pas de couleur).

### W3 · Autres fenêtres

Choix défensifs, consignes individuelles (`TacticsDefenseChoices`, `IndividualInstructions`), paramètres, négociation, délégation : tous des `AcceptDialog` habillés par `ImmersiveDialogs.prepare` (thème, titre or, centrage, taille bornée à l'écran). **Un seul `_clear_dialogs()` ferme toutes les fenêtres avant d'en ouvrir une** : pas de fenêtres empilées, sauf les lecteurs suspendus (`is_suspended_reader`, fiches ouvertes depuis une fenêtre).

**Incohérence** : les fenêtres de choix à boutons (défense, consignes) se ferment au choix et envoient la commande, alors que d'autres (paramètres) valident par un bouton final : deux logiques de validation.

---

## Retour

### F1 · Info-bulle

Infobulle native Godot partout (`tooltip_text`). Sert à trois usages mélangés :
1. **raison d'un bouton désactivé** (candidats, réponses de courrier, conférences) ;
2. **détail** d'une donnée (colonne du tableau, cellule, jauge, pastille « Derby ») ;
3. **raccourci** (« Précédent · Alt + gauche », « Jour suivant : … (Ctrl+J) »).

**Incohérences** : pas d'info-bulle imbriquée (aucune ne contient une info-bulle) ; pas de rendu personnalisé : la boîte est celle du thème Godot, sans délai ni largeur maximale choisie ; la plupart des textes de plusieurs lignes dépendent du retour à la ligne automatique. L'indicateur de sauvegarde a sa propre mini-infobulle (`_tip`) parce qu'il ne reçoit pas la souris.

### F2 · Pastille d'état (chip)

`C.chip` / `D.chip` : fond teinté à 10 %, liseré et texte de la même couleur. Palette : menthe (bon), ambre (à compléter), alerte (rouge), bleu (info), or. Dérivé : pastille « DERBY » (fond ambre, info-bulle).

**Incohérence** : la **couleur seule** distingue souvent l'état (« Composition valide » menthe / « À compléter » ambre) ; le texte aide mais l'icône manque. La couleur « alerte » est `df897d` dans la coque et `e2876f` dans le socle (`jetons.gd`) : deux rouges légèrement différents.

### F3 · Jauge / barre

`C.gauge` (ProgressBar sans pourcentage, 7 px) et `D.bar` (rectangle) : valeur 0-100, couleur du niveau. Colonnes « niveau » et « condition » du tableau dessinent leur propre barre (`_barre_niveau`, `_dessin_condition`). **Pas de valeur numérique systématique** à côté ; pas d'animation de changement ; pas de seuils écrits (« repos conseillé »).

### F4 · Pied de page d'état

Ligne unique sous le contenu : dernier retour du moteur (« Conférence tenue · Moral collectif : 75 → 87 / 100 »), erreurs en rouge (`ALERT`), état de sauvegarde ; à droite, raccourcis (voir N5) et le bouton de retour d'effet des décisions (`DecisionFeedbackButton`). Le texte se resserre (jusqu'à ~11 px) puis se coupe avec « … » (texte complet en infobulle).

**Incohérences** :
- Le pied de page sert de **canal unique de confirmation** après une commande : pas de toast, donc facile à rater (bas d'écran, petite taille).
- Un second canal de stockage vit dans le rail (« Sauvegarde auto » / « Stockage à vérifier », point vert/rouge) : trois endroits parlent de sauvegarde (rail, pied, disquette).
- En petit format, raccourcis et statut s'empilent et le texte descend à ~11 px, sous le plancher de 12 px annoncé.

### F5 · Indicateur de sauvegarde (`save_indicator.gd`)

Disquette de 26 px en bas à droite, **jamais bloquante** (`MOUSE_FILTER_IGNORE`).

| Phase | Comportement |
|---|---|
| Début | Attend 0,35 s : une écriture rapide ne montre rien |
| Affichée | Ivoire, pulsation douce, fondu 0,18 s ; info-bulle « Sauvegarde en cours… » |
| Fin | Reste au moins 1 s (« Carrière sauvegardée ») puis fondu |
| Échec | **Rouge**, reste jusqu'à la prochaine sauvegarde ; « La sauvegarde a échoué : ta dernière action est annulée. » |
| Mouvements réduits | Fixe, sans pulsation, sans fondu |

Info-bulle au survol de la zone (lecture de la position souris, car le nœud ignore la souris). **Aucune interaction** (ni clic « réessayer » ni lien vers les sauvegardes).

**Incohérence** : en cas d'échec le bouton « réessayer » manque ; le message ne dit pas **où** aller (menu → sauvegardes). Le rouge de la disquette (`d43e47`) est un troisième rouge.

### F6 · Pastilles V/N/D

`preparation_canvas` : forme de l'adversaire en pastilles « V / N / D » (menthe / or / alerte), 32 × 30 px, dans l'ordre des rencontres. **La lettre est dans la pastille** (bon pour l'accessibilité) ; seul usage relevé du motif. Les autres écrans (Bureau « frise des matchs », Classements) montrent la forme autrement ; le relevé détaillé n'a pas été fait.

### F7 · Panneau d'attente (`command_wait_overlay.gd`)

**Quand** : Continuer et commandes longues. Panneau centré (≈ 40 % de la largeur), écran assombri, calendrier qui tourne au passage de jour, terrain qui se trace, ballon qui rebondit, ligne d'en-but comme barre de progression, **conseil de Gabi ou fait du club** (notes changées toutes les ~4,6 s).

**Règles** : n'apparaît qu'après un court délai (`present(message, animate, delay_seconds)`) ; **absorbe les clics dès l'appel** (`MOUSE_FILTER_STOP`) même avant d'être visible ; `FOCUS_NONE` (rien à cibler) ; texte d'état annoncé poliment aux lecteurs d'écran (`LIVE_POLITE`) ; mouvements réduits = image fixe.

| État | Rendu |
|---|---|
| Rapide | Rien d'affiché |
| Long | Panneau + conseil |
| Annulation | Échap arrête seulement la barre `continue_progress` (`main.gd`) ; le panneau lui-même n'a pas de bouton |
| Échec | Ferme et laisse le pied de page / avis annoncer |

**Incohérence** : entre l'appel et l'apparition du panneau (le délai), l'interface est **gelée sans retour visible** ; l'annulation par Échap n'est pas annoncée sur le panneau.

### F8 · États vides

| Lieu | Texte |
|---|---|
| Tableau (défaut) | « Aucune ligne ne correspond. » |
| Effectif, recherche | « Aucun joueur ne correspond à cette recherche. » |
| Effectif, filtre « À surveiller » | « Personne à surveiller cette semaine. » |
| Réception | « Aucun message dans cette vue. / Choisis un autre filtre. » |
| Accès rapide | « Aucun résultat · essaie un autre nom ou menu. » |
| Hors feuille | « Tous les joueurs figurent sur la feuille. » |

**Incohérence** : ce sont des phrases seules. **Ni icône, ni bouton de sortie** (« Effacer le filtre », « Tout afficher »). Le ton passe du neutre (« Aucune ligne ne correspond ») au tutoiement (« Choisis un autre filtre »).

### F9 · États d'erreur

| Cas | Rendu |
|---|---|
| Échec de sauvegarde | Disquette rouge + pied de page rouge + point rouge dans le rail + « Stockage à vérifier » |
| Moteur arrêté | Libellé de Continuer = « RELANCER LE MOTEUR → », info-bulle explicative |
| Commande refusée (affectation) | Avis modal (W2) |
| Packs manquants | Bandeau d'alerte au-dessus du contenu (`_pack_warning`) |

**Incohérence** : aucune hiérarchie entre erreur bloquante (modale), erreur de commande (pied de page) et erreur de stockage (trois endroits). Le ton est sain (« ta dernière action est annulée »), mais pas systématique.

---

## Aide : Gabi

### G1 · Gabi dans la barre haute (bandeau)

Visage et remarque du moment entre la recherche et la date (`TOPBAR_GABI_LEFT`). Zone `GabiBandeau`, sans place propre à l'écran. **Au Bureau**, Gabi est « en pied » dans la colonne de droite et **quitte** le bandeau (la recherche s'élargit). Médaillon : `gabi_medaillon.gd` (souris ignorée, signal `pressed`, survol).

### G2 · Aide F1 et bulle

**F1** ouvre le guide de l'écran (`_open_coach`). Bouton compact « Gabi · ? » (info-bulle « Gaston Darroux · Aide de cet écran » ; « Un conseil attend de la place · Ouvrir » si un conseil est différé). Bulle papier ivoire à queue (`coach_bubble.gd`, fond `f4eedf`).

**Boutons du guide** : ‹ (précédente), Suite ›, Ouvrir (va à l'écran), ↻ (réécouter), ■ (arrêter la voix), ··· (voix, vitesse, Muet, Passer l'étape, Désactiver), ↔ (changer de coin), × (réduire), Visite (visite guidée).

| État | Rendu |
|---|---|
| Voix indisponible | Message « Aucune voix système française », menu désactivé ; « Mode texte » |
| Muet | Libellé « Activer la voix » |
| Réduit | Bouton « Gabi · ? » seul |
| Désactivé | Libère la place horizontale (non persistant selon le cas) |

**Incohérences** :
- Un conseil de Gabi apparaît à **quatre endroits** : bandeau, bulle de guide, panneau d'attente (note), colonne du Bureau, sans qu'on puisse dire laquelle est « la » voix.
- Le guide a **son propre jeu de boutons** (32 px, police 12 px : à 0,5 de densité on passe sous le plancher de 11 px) et ses propres symboles (‹ ↻ ■ ···) ; aucune info-bulle sur « Suite › » et « Ouvrir ».
- F1 est un raccourci global mais **absent de la liste des paramètres** ? non vérifié ; il est dans la table de N5 (« F1 Aide »).

---

## Incohérences par priorité (pistes d'amélioration)

| # | Constat | Gravité | Piste |
|---|---|---|---|
| 1 | **Échap** ferme une fenêtre, revient d'une fiche, arrête Continuer, ou **ouvre le menu pause** | Haute | Décidé le 19/11/2026 : règle unique (fenêtre, retour de fiche, sinon menu pause) ; annoncer « Échap Menu » sur les écrans principaux ; bouton « Menu » visible dans la coque ; ne jamais ouvrir la pause si une fiche/fenêtre vient d'être fermée |
| 2 | Deux façons de choisir un joueur en Composition (fenêtre de boutons désactivés / liste hors feuille à avis modal) | Haute | Un seul motif « choisir un joueur » avec états grisés + raison, mêmes colonnes et même tri |
| 3 | Le tableau trié n'existe que sur Effectif ; les autres listes ne trient ni ne se parcourent pareil | Haute | Étendre le socle à Recrutement, Classements, Finances ; ajouter le tri au clavier |
| 4 | Confirmation générique (CONFIRMER/ANNULER), focus par défaut sur CONFIRMER, aucun bouton destructif | Moyenne | Libellé = action, focus sur ANNULER pour tout ce qui supprime ou engage de l'argent |
| 5 | Réponses de courrier envoyées au clic sans récapitulatif ni annulation | Moyenne | Cartes en deux temps (choisir puis « Envoyer ») ou annulation 5 s dans le pied de page |
| 6 | Canal de retour unique et discret (pied de page, 17 px) ; sauvegarde annoncée à trois endroits | Moyenne | Un petit message flottant non bloquant (voir « Motifs manquants ») ; unifier le message de sauvegarde |
| 7 | Vides sans sortie (pas de « Effacer le filtre ») | Moyenne | Vide = message + action |
| 8 | Boutons : cinq variantes visuelles (C, D, socle, Gabi, Legacy) | Moyenne | Un seul gabarit de bouton avec états documentés |
| 9 | Pastilles de filtre (Effectif ivoire / Réception vert club), compte « Tous, 40 » vs « Non lus 3 » | Basse | Même pastille et même format de compte |
| 10 | Fil d'Ariane non cliquable | Basse | Rendre cliquables les niveaux, ou le présenter comme un titre |
| 11 | Numérotation 1-9 invisible (Réception = 1, Bureau = 2) | Basse | Afficher le chiffre dans le rail, ou rendre Bureau = 1 |
| 12 | Trois rouges d'alerte (`df897d`, `e2876f`, `d43e47`) et couleur seule pour certains états | Basse | Un jeton rouge unique + lettre/icône |
| 13 | `lineup_board.gd` : police 11 px, tailles fixes | Basse | Retirer ou migrer |
| 14 | Textes à 11-12 px dans le pied de page et les boutons de Gabi en petite fenêtre | Basse | Plancher 12 px réel, ou regrouper |
| 15 | Aucune entrée manette | À décider | Hors du périmètre actuel (PC souris/clavier) |

---

## Motifs manquants recommandés

1. **Barres face à face** (nous / adversaire) pour la préparation, le « duel en chiffres » de l'entracte et l'après-match : deux barres opposées autour d'une valeur centrale, avec chiffres et écart, pour comparer sans tableau.
2. **Pastilles V/N/D avec lettre** partout où l'on montre une forme (Bureau, Classements, fiche club, après-match) : le motif existe en Préparation (F6), à généraliser avec le même jeton de couleur et la lettre toujours présente.
3. **Info-bulles imbriquées** : survoler un terme (« moral », « JIFF ») dans une info-bulle ouvre sa définition ; aujourd'hui une info-bulle est un bloc de texte plat.
4. **Menu rapide global** : clic droit ou touche sur une ligne (joueur, club, courrier) pour proposer « Ouvrir la fiche, Suivre, Comparer, Proposer un contrat » sans changer d'écran ; aujourd'hui seul le double-clic ouvre la fiche.
5. **Message flottant non bloquant (toast)** avec lien d'annulation : remplace le pied de page comme seul canal de confirmation (voir incohérence 6).
6. **Confirmation d'action destructive** : bouton rouge, libellé précis, focus sur Annuler (voir 4).
7. **État de chargement local** : bouton qui passe en « … » ou squelette de ligne, au lieu de simplement se griser avec `app.waiting`.
8. **État vide avec action** (icône + message + bouton).
9. **Tri et filtre au clavier** sur le tableau (flèche sur l'en-tête, touche pour inverser) et **recherche locale** commune aux listes.
10. **Navigation manette** et **ordre de tabulation documenté** (à décider avec la production : aujourd'hui hors périmètre).
11. **Onglets** : un seul motif, avec raccourci (Ctrl+Tab ou chiffres) et indicateur de position.
12. **Glisser-déposer avec alternative clavier** (déplacer un joueur dans la composition à la touche).

## Questions ouvertes

| Question | Propriétaire | État |
|---|---|---|
| Échap doit-il ouvrir la pause sur un écran racine, ou seulement via un bouton ? | Léo / game-designer | **Résolue le 19/11/2026** : Échap ouvre le menu pause, et un bouton visible dans la coque l'ouvre aussi |
| Les listes de Recrutement et de Classements passent-elles au socle de tableau ? | ui-programmer | Non vérifié : à relever écran par écran |
| La manette est-elle un objectif ? | Léo | Non décidé |
| Le plancher de 12 px est-il tenu en 1280 × 720 dans le pied de page et le guide ? | ui-programmer | Mesure à faire (capture) |

*Limites du relevé* : lecture ciblée de la coque, du socle, des composants, du courrier, de la composition, de la sauvegarde, de l'attente et du guide. Les écrans Bureau, Finances, Club, Formation, Presse, Rivalités, le direct et l'entracte n'ont pas été relus en détail ; leurs motifs propres n'y sont pas inventoriés. Aucune capture ni exécution de Godot : les états décrits sont lus dans le code, pas observés.
