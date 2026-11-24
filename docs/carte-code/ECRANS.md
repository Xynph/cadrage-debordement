# Carte des écrans (chemins sous `native/godot/`)
Usage : 1. ce fichier ; 2. `node scripts/carte-code.cjs <fichier>` (func + lignes) ou `--cherche <motif>` ; 3. Read avec offset/limit sur la plage.
Numéros de ligne approximatifs (au 24/11/2026) : relancer carte-code.cjs avant de s'y fier.

## Navigation et coque
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Coque : état, noms publics (façades) | `main.gd` (NAV_CHAPTERS ~L59, variables ~L67) | façades d'une ligne vers les modules `main_*.gd` |
| Routes, historique | `main_navigation.gd` | `navigate` L9 (façade `main.gd` `_navigate`) |
| Rendu d'un écran, rail, en-tête | `main_rendu.gd` | `render_screen` L37, `build_sidebar` L271, `update_live_bar` L343 |
| Bouton principal « Continuer » | `main_navigation.gd` | `primary_text` L133, `primary_action` L150 |
| Commandes et réponses du moteur | `main_moteur.gd` | `receive` L23, `send_command` L161, `failed` L290, `live_tick` L354 |
| Panneau d'attente, ligne d'état | `main_etat.gd` | `command_wait_context` L109, `settled_status_text` L170 |
| Démarrage de la coque | `main_demarrage.gd` | `ready` L14 |
| Coque : rail + barre haute | `ui/immersive08/shell.gd` | `render` L85, `_topbar` ~L910, `_dedicated_page` L322 |
| Page par route | `ui/immersive08/shell.gd` | `_existing_page` ~L1505 (match sur `app.route`) |
| Raccourcis clavier | `ui/navigation_controller.gd`, `ui/raccourcis_clavier.gd` | `handle_shortcut` |
| Menu pause, réglages | `ui/preferences_dialog.gd`, `main_dialogues.gd` | `pause_menu` L60, `confirm` L39, `file_selected` L96 |
| Recherche (Ctrl K) | `ui/immersive08/search_canvas.gd` | `build` L17 |
| Calendrier du mois | `ui/immersive08/training_mois.gd`, `calendar_agenda.gd` | `ouvrir` L75 |

## Bureau, réception
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Bureau (dessiné) | `ui/immersive08/office_canvas.gd`, `office.gd` | `build` L169 / L278 |
| Gabi adjoint (bandeau, bulle, Bureau) : fichier public (contexte : moments clés, première visite, humeur, alertes ; `_process`, `refresh`) | `ui/immersive08/coach_canvas.gd` ← sa chaîne ci-dessous (`coach_guide.gd` ← socle ← bulle ← bandeau ← bureau ← canvas) | `consider_context` L20, `_process` L275 |
| Gabi : socle (consts, état, portraits, habillage des boutons, placement portrait/voile/bulle, fil de la remarque, indice, petites classes de dessin) | `ui/immersive08/coach_socle.gd` | `_maj_remarque` L249, `_layout_bulle` L324, `_position_libre` L403 |
| Gabi : bulle qui descend du bandeau (construction, affichage, fermeture, « Suivre le conseil ») | `ui/immersive08/coach_bulle.gd` | `_build_adjoint` L16, `_montrer` L87, `suivre_conseil` L200 |
| Gabi : bandeau du haut (pose, clic) et règles de parole (bulle ou indice) | `ui/immersive08/coach_bandeau.gd` | `installer_bandeau` L11, `_clic_bandeau` L151, `_dans_le_bandeau` L185 |
| Gabi : chez lui au Bureau (zone en pied, carnet, premiers pas) | `ui/immersive08/coach_bureau.gd` | `installer_bureau` L11, `carte_premiers_pas` L148 |
| Réception (courrier) : fichier principal (états, ordre des courriers, `build`, `heading`, consts) | `ui/immersive08/reception_canvas.gd` ← ses morceaux ci-dessous | `build` ~L470 |
| Réception : liste de gauche (filtres, jours, ligne d'un courrier) | `ui/immersive08/reception_liste.gd` | `_list_filters`, `_list`, `_row` |
| Réception : lettre ouverte (texte à liens, fil de lecture, mesures) | `ui/immersive08/reception_lettre.gd` | `_detail`, `_letter`, `entities` |
| Réception : coupure de presse et infirmerie | `ui/immersive08/reception_coupure_infirmerie.gd` | `_clipping`, `_infirmary`, `infirmary_rows` |
| Réception : panneau « Concerné » et pièces jointes | `ui/immersive08/reception_concerne.gd` | `_concerned_row`, `_attachments` |
| Réception : cartes d'action (réponses, ouvertures, politique de presse) | `ui/immersive08/reception_reponses.gd` | `_actions` |
| Réception : tuiles de réponse, statuts de lecture | `ui/immersive08/reception_messages.gd`, `reception_reading.gd` | `bande`, `status` |
| Compte rendu de match (carte) | `ui/immersive08/compte_rendu_carte.gd` | `carte` L28 |
| Presse, conférence | `ui/immersive08/press_canvas.gd`, `conference_presse.gd` | `build` L65 / `construire` L75 |

## Équipe
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Effectif (liste) | `ui/immersive08/squad_canvas.gd` (fichier public : `build`, `_build`, redéfinitions des statiques lus ailleurs, pastilles de poste), `ui/socle/ecran_effectif.gd`, `panneaux_effectif.gd` | `build` L19 / L41 |
| · socle de l'Effectif | `ui/immersive08/squad_socle.gd` (constantes, état, outils de dessin, lecture et tri des joueurs en statiques : `primary_caption`, `sort_value`, `ordered_players`) | chaîne d'héritage socle ← filtres ← entête ← lignes ← tableau ← canvas |
| · Puces, recherche, menus | `ui/immersive08/squad_filtres.gd` | `_filtres`, `_appliquer_puce`, `_choix_menu` |
| · Titre, tuiles, onglets | `ui/immersive08/squad_entete.gd` | `_entete_page`, `_tuiles`, `_onglets` |
| · Ligne d'un joueur | `ui/immersive08/squad_lignes.gd` | `_row`, `_cellule_joueur`, `_statut` |
| · Tableau, tri, totaux | `ui/immersive08/squad_tableau.gd` | `_tableau`, `_colonnes`, `_refresh`, `_totaux` |
| Fiche joueur | `ui/immersive08/player_canvas.gd`, `fiche_page.gd`, `fiche_commune.gd`, `fiche_*.gd` | `build` L97 |
| Composition / tactique | `ui/immersive08/tactics_canvas.gd` + `tactics_*.gd` | `build` L44 |
| Préparation (semaine) | `ui/immersive08/preparation_canvas.gd` (fichier public : `build`, `compact`, `ouvrir_sous_page`, en-tête, onglets, `_dossier`), `preparation_adversaire.gd`, `preparation_consignes.gd` | `build` L6, `compact` L15 |
| · socle de Préparation | `ui/immersive08/preparation_socle.gd` (constantes, état, marque, panneaux, boutons, zones, fiches club/joueur) | chaîne d'héritage socle ← dossier ← xv ← canvas |
| · Dossier : panneaux | `ui/immersive08/preparation_dossier.gd` (danger, rapport, à faire, forme, face-à-face) | `_rapport`, `_a_faire`, `_forme` |
| · Dossier : bas et sous-pages | `ui/immersive08/preparation_xv.gd` (à surveiller, leur XV probable, repères, conseils, planning, reprise) | `_surveiller`, `_xv_bande`, `_sous_reperes` |
| Plan de jeu | `ui/immersive08/playbook_canvas.gd` | `build` L56 |
| Entraînement | `ui/immersive08/training_canvas.gd`, `training_*.gd` | `build` L56 |
| Vestiaire | `ui/immersive08/locker_canvas.gd` | `build` L20 |
| Comparateur | `ui/immersive08/comparateur_canvas.gd` | `build` L50 |

## Club et finances
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Club, staff, stratégie, travail du club | `ui/immersive08/club_canvas.gd`, `club_pages.gd`, `staff_services.gd` | `build` L93 |
| Fiche d'un club | `ui/immersive08/club_sheet_canvas.gd` | `open` L54, `build` L68 |
| Finances : fichier principal (onglets, accès depuis les autres écrans, verdict, `build`, consts) | `ui/immersive08/finance_canvas.gd` ← ses morceaux ci-dessous | `build` ~L163 |
| Finances : pièces graphiques communes (panneaux, textes, boutons, zones) | `ui/immersive08/finance_briques.gd` | `_panneau`, `_bouton`, `_zone` |
| Finances : tracés (courbe des mouvements, solde, pictogramme) | `ui/immersive08/finance_traces.gd` | `LedgerPlot`, `SoldePlot`, `Symbole` |
| Finances : colonne de verdict fixe (verdict, trésorerie, budget de transferts, marge, vigilances) | `ui/immersive08/finance_colonne.gd` | `_colonne`, `_verdict_panneau`, `_watch` |
| Finances : Synthèse (bandeau, listes) et courbe « Solde sur 12 mois » | `ui/immersive08/finance_synthese.gd`, `finance_solde.gd` | `construire`, `_solde`, `_fenetre_semaine` |
| Finances : Trésorerie (courbe, journal des flux, pagination) | `ui/immersive08/finance_journal.gd` | `_cash`, `_ledger`, `_chart` |
| Finances : Salaires, Transferts, Classement des clubs | `ui/immersive08/finance_listes.gd`, `finance_health.gd` | `_wages`, `_transfers`, `_clubs` |
| Finances : Budget (engagements, leviers, budget de saison, charges, échéances) | `ui/immersive08/finance_budget.gd` | `_budget`, `_season_budget`, `_allocation` |
| Carrière du manager | `ui/immersive08/career_canvas.gd` | `build` L14 |

## Recrutement, transferts
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Recrutement (marché) | `ui/immersive08/recruitment_canvas.gd` (fichier public : `build`, `_build`, `target_available`, `open_report`, redéfinitions des statiques lus ailleurs), `recruitment_pages.gd`, `rapport_recruteur.gd` | `build` L57 / L65 |
| · socle du Recrutement | `ui/immersive08/recruitment_socle.gd` (constantes, état, aides en statiques, actions de navigation, stub `_refresh`) | chaîne d'héritage socle ← entête ← filtres ← coût ← lignes ← tableau ← canvas |
| · Titre, tuiles, besoins, onglets | `ui/immersive08/recruitment_entete.gd` | `_header`, `_tuiles`, `_needs`, `_tabs`, `fenetre_courte` |
| · Filtres, pastilles de poste | `ui/immersive08/recruitment_filtres.gd` | `_filters`, `_choice`, `_pastilles_postes` |
| · Coût de l'offre, observation | `ui/immersive08/recruitment_cout.gd` | `_cout`, `_confirmer_observation`, `_observer` |
| · Ligne d'une piste | `ui/immersive08/recruitment_lignes.gd` | `_row`, `_cellule`, `_observation_text` |
| · Tableau, tri, rafraîchissement | `ui/immersive08/recruitment_tableau.gd` | `_table`, `_columns_for`, `_entetes`, `_filtered`, `_refresh`, `_input` |
| Fiche piste / Espoir | `ui/immersive08/fiche_page.gd` | `build` L19 |
| Négociation contrat, offres | `ui/contract_negotiation.gd`, `negociation_agent.gd`, `offre_guidee.gd`, `offre_visuelle.gd` | `open` L71 |
| Marché inter-clubs | `ui/interclub_market_view.gd` | `open` L44 |
| Budget transferts | `ui/transfer_budget.gd` | — |

## Formation
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Formation (développement) | `ui/immersive08/academy_canvas.gd`, `formation_pages.gd` | `build` L68 |
| Centre de formation | `ui/immersive08/centre_canvas.gd`, `centre_*.gd` | `build` L21 |
| Centre de formation, affichage compact (fenêtre sous 1280 × 720, parcours actifs) : fichier public (`build`, `_remplir`) ← sa chaîne ci-dessous | `ui/immersive08/centre_compact.gd` | `build` L13, `_remplir` L39 |
| Centre compact : socle (préchargements, consts, toile des petites fenêtres, petites pièces de dessin) | `ui/immersive08/centre_compact_socle.gd` | `_preparer`, `_fenetre`, `_zone` |
| Centre compact : pièces composées (pilule, panneau, jauges, blason), tuile, en-tête, onglets | `ui/immersive08/centre_compact_pieces.gd` | `_pilule` L7, `_panneau` L39, `_entete` L184, `_onglets` L210 |
| Centre compact : listes à lignes et chemin en étapes | `ui/immersive08/centre_compact_listes.gd` | `_liste` L10, `_chemin` L163 |
| Centre compact : onglet Centre (détection, centre, rencontres, équipe première) | `ui/immersive08/centre_compact_page_centre.gd` | `_centre` L6 |
| Centre compact : onglets Parcours et Centres | `ui/immersive08/centre_compact_parcours_centres.gd` | `_parcours` L7, `_centres` L73 |
| Centre compact : onglets Filières, Passerelle pro, Générations | `ui/immersive08/centre_compact_filieres_passerelle.gd` | `_filieres` L6, `_passerelle` L106, `_generations` L171 |
| Suivi des jeunes | `ui/academy_follow_up_view.gd` | — |

## Compétition
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Calendrier, classements | `ui/immersive08/competition_canvas.gd` (fichier public : `build`, en-tête, sous-pages rencontre et archives), `standings_zones.gd` | `build` L6 |
| · socle de Compétitions | `ui/immersive08/competition_socle.gd` (constantes, état, cibles `open_target`/`target_available`, outils partagés) | chaîne d'héritage socle ← classement ← calendrier ← colonne ← canvas |
| · Classements (tableau) | `ui/immersive08/competition_classement.gd` (tri, tableau, menu de compétition, zones, plaque) | `_classement` |
| · Calendrier, phases, stats | `ui/immersive08/competition_calendrier.gd` | `_calendar`, `_playoffs`, `_stats` |
| · Colonne de droite, bande du bas | `ui/immersive08/competition_colonne.gd` | `_colonne_droite`, `_bas_gauche` |
| Rivalités | `ui/immersive08/rivalry_canvas.gd` | `build` L35 |
| Europe | `ui/immersive08/europe_canvas.gd` | `build` L40 |
| Sélections / nationale | `ui/international_view.gd`, `ui/national_sheet.gd` | `build`, `calendar` |

## Match
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Match en direct (3D, HUD) | `ui/contextual/live_view.gd`, `match_view.gd` (état, `apply_frame`, façades), `match_vue_camera.gd` (caméra suivie), `match_vue_visee.gd` (bornes, poteaux, regroupement), `match_vue_joueurs.gd` (acteurs, animation, sortie), `match_vue_ballon.gd` (port, passe, trajectoire), `match_vue_stade.gd` (décor, public, ballon), `match_ambiance.gd` (foule vivante, confettis, fumigènes, pluie), autres `match_*.gd` (racine) | `_ready` L141 ; vue `_ready` L171, `apply_frame` L427, `_process` L699 ; `_fit_camera` (caméra) L115, `animer_acteur` (joueurs) L214 |
| Avant-match | `ui/immersive08/match_avant.gd` (fichier public : `_construire`, `_verifications`, `overflows`) ; chaîne d'héritage `match_avant_socle.gd` (constantes, variables, outils de texte/date, `setup`, navigation, `refresh`) ← `match_avant_outils.gd` (pastilles, phrases et icônes météo, jauge arbitre, cadre des tuiles) ← `match_avant_bandeau.gd` (bandeau, coup d'envoi) ← `match_avant_affiche.gd` (fond, plaques, centre, classements, pied) ← `match_avant_verifications.gd` (feuille, conditions) ← `match_avant_adversaire.gd` (adversaire, mini-fiche, Gabi) ; + `avant_match_pages.gd`, `avant_match_bilan.gd`, `avant_match_terrain.gd` | `setup` (socle) L124, `_construire` (match_avant) L16 |
| Temps forts (régie) | `ui/contextual/match_temps_forts.gd` | `setup` L231 |
| Gestes du match 3D (touche, ballon porté, essai) | `match_gestes.gd` (interface, recadrage) ← `match_gestes_essai.gd` (ballon porté, essai, après-essai) ← `match_gestes_placement.gd` (mise en place, touche, coupes) ← `match_gestes_corps.gd` (poses) ← `match_gestes_etat.gd` (constantes, état) : chaîne d'héritage | `observe` L56, `advance` L176, `pose` L320 |
| Entre-deux (2D) | `ui/contextual/match_between.gd` (écran : `_ready`, `_construire`, colonnes, `update_frame`) ← chaîne d’héritage, du bas vers le haut : `match_between_constantes.gd` (préchargements, constantes) ← `_widgets.gd` (Domination, Momentum, Jauge…) ← `_etat.gd` (signaux, variables, Compo, Cumul) ← `_outils.gd` (échelle, cases, boutons, textes) ← `_fiche.gd` (fiche joueur, état du terrain, phase, légende) ← `_joueurs.gd` (visages, noms, lignes) ← `_multiplex.gd` (écussons, cartes de match) ← `_journee.gd` (classement en direct, journée, météo, vue de droite) ← `_xv.gd` (Mon XV, banc, changements) ← `_fil.gd` (fil, chiffres, bonus, tableau FM) ← `_adjoint.gd` (Gabi, pourquoi, arrêts) ; `match_terrain_2d.gd` | `_ready` L18 |
| Consignes / banc / équipe en direct | `ui/contextual/match_consignes_fenetre.gd`, `match_banc_fm.gd`, `match_equipe.gd` | `ouvrir_fenetre_consignes` (live_view L1861) |
| · Fenêtre Équipe (composition, consignes, rôles) | `ui/contextual/match_equipe.gd` (fichier public : `_ready`, `ouvrir`, `update_frame`, `_rafraichir`, `debordements`) ← chaîne d’héritage, du bas vers le haut : `match_equipe_socle.gd` (préchargements, constantes, état, accès au modèle, actions `remplacer`/`crier`/`choisir_role`) ← `_outils.gd` (échelle, cadres, textes, boutons, portraits, en-tête, pied) ← `_terrain.gd` (médaillons, terrain, glisser-déposer) ← `_composition.gd` (cris, banc, « Dans 10 minutes », conseil de Gabi) ← `_cartes.gd` (cartes de l’onglet Consignes : match, staff, plan de jeu, arbitre, adversaire) ← `_consignes.gd` (page des cinq axes) ← `_roles.gd` (onglet Rôles) | `ouvrir` L31 |
| Après-match | `ui/contextual/apres_match.gd` | `_ready` L71 |
| Chef de scène (pièces, direct) | `ui/contextual/director.gd` | `open_room` L254 |
| Presse après match | `ui/immersive08/conference_presse.gd` | `main_navigation.gd` `open_postmatch_press` L72 |

## Hors coque
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Accueil, création, packs | `ui/entry_screens.gd`, `ui/immersive08/entry_canvas.gd`, `creation_canvas.gd`, `ui/pack_views.gd` | `build` |
| Intro, crédits | `intro/intro_sequence.gd`, `ui/credits_view.gd` | — |
