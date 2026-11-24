# Carte des écrans (chemins sous `native/godot/`)
Usage : 1. ce fichier ; 2. `node scripts/carte-code.cjs <fichier>` (func + lignes) ou `--cherche <motif>` ; 3. Read avec offset/limit sur la plage.
Numéros de ligne approximatifs (au 24/11/2026) : relancer carte-code.cjs avant de s'y fier.

## Navigation et coque
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Routes, historique | `main.gd` (NAV_CHAPTERS ~L101) | `_navigate` L815, `_render_screen` L904 |
| Coque : rail + barre haute | `ui/immersive08/shell.gd` | `render` L85, `_topbar` ~L910, `_dedicated_page` L322 |
| Page par route | `ui/immersive08/shell.gd` | `_existing_page` ~L1505 (match sur `app.route`) |
| Raccourcis clavier | `ui/navigation_controller.gd`, `ui/raccourcis_clavier.gd` | `handle_shortcut` |
| Menu pause, réglages | `ui/preferences_dialog.gd`, `main.gd` | `pause_menu` |
| Recherche (Ctrl K) | `ui/immersive08/search_canvas.gd` | `build` L17 |
| Calendrier du mois | `ui/immersive08/training_mois.gd`, `calendar_agenda.gd` | `ouvrir` L75 |

## Bureau, réception
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Bureau (dessiné) | `ui/immersive08/office_canvas.gd`, `office.gd` | `build` L169 / L278 |
| Réception (courrier) | `ui/immersive08/reception_canvas.gd`, `reception_messages.gd`, `reception_reading.gd` | `build` L469 |
| Compte rendu de match (carte) | `ui/immersive08/compte_rendu_carte.gd` | `carte` L28 |
| Presse, conférence | `ui/immersive08/press_canvas.gd`, `conference_presse.gd` | `build` L65 / `construire` L75 |

## Équipe
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Effectif (liste) | `ui/immersive08/squad_canvas.gd`, `ui/socle/ecran_effectif.gd`, `panneaux_effectif.gd` | `build` L66 / L41 |
| Fiche joueur | `ui/immersive08/player_canvas.gd`, `fiche_page.gd`, `fiche_commune.gd`, `fiche_*.gd` | `build` L97 |
| Composition / tactique | `ui/immersive08/tactics_canvas.gd` + `tactics_*.gd` | `build` L44 |
| Préparation (semaine) | `ui/immersive08/preparation_canvas.gd`, `preparation_*.gd` | `build` L34, `compact` L43 |
| Plan de jeu | `ui/immersive08/playbook_canvas.gd` | `build` L56 |
| Entraînement | `ui/immersive08/training_canvas.gd`, `training_*.gd` | `build` L56 |
| Vestiaire | `ui/immersive08/locker_canvas.gd` | `build` L20 |
| Comparateur | `ui/immersive08/comparateur_canvas.gd` | `build` L50 |

## Club et finances
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Club, staff, stratégie, travail du club | `ui/immersive08/club_canvas.gd`, `club_pages.gd`, `staff_services.gd` | `build` L93 |
| Fiche d'un club | `ui/immersive08/club_sheet_canvas.gd` | `open` L54, `build` L68 |
| Finances | `ui/immersive08/finance_canvas.gd`, `finance_*.gd` | `build` L499 |
| Carrière du manager | `ui/immersive08/career_canvas.gd` | `build` L14 |

## Recrutement, transferts
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Recrutement (marché) | `ui/immersive08/recruitment_canvas.gd`, `recruitment_pages.gd`, `rapport_recruteur.gd` | `build` L113 |
| Fiche piste / Espoir | `ui/immersive08/fiche_page.gd` | `build` L19 |
| Négociation contrat, offres | `ui/contract_negotiation.gd`, `negociation_agent.gd`, `offre_guidee.gd`, `offre_visuelle.gd` | `open` L71 |
| Marché inter-clubs | `ui/interclub_market_view.gd` | `open` L44 |
| Budget transferts | `ui/transfer_budget.gd` | — |

## Formation
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Formation (développement) | `ui/immersive08/academy_canvas.gd`, `formation_pages.gd` | `build` L68 |
| Centre de formation | `ui/immersive08/centre_canvas.gd`, `centre_*.gd` | `build` L21 |
| Suivi des jeunes | `ui/academy_follow_up_view.gd` | — |

## Compétition
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Calendrier, classements | `ui/immersive08/competition_canvas.gd`, `standings_zones.gd` | `build` L173 |
| Rivalités | `ui/immersive08/rivalry_canvas.gd` | `build` L35 |
| Europe | `ui/immersive08/europe_canvas.gd` | `build` L40 |
| Sélections / nationale | `ui/international_view.gd`, `ui/national_sheet.gd` | `build`, `calendar` |

## Match
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Avant-match | `ui/immersive08/match_avant.gd` (+ `avant_match_pages.gd`, `avant_match_bilan.gd`, `avant_match_terrain.gd`) | `setup` L134, `_construire` L261 |
| Match en direct (3D, HUD) | `ui/contextual/live_view.gd`, `match_view.gd`, `match_*.gd` (racine) | `_ready` L141 |
| Temps forts (régie) | `ui/contextual/match_temps_forts.gd` | `setup` L231 |
| Gestes du match 3D (touche, ballon porté, essai) | `match_gestes.gd` (interface, recadrage) ← `match_gestes_essai.gd` (ballon porté, essai, après-essai) ← `match_gestes_placement.gd` (mise en place, touche, coupes) ← `match_gestes_corps.gd` (poses) ← `match_gestes_etat.gd` (constantes, état) : chaîne d'héritage | `observe` L56, `advance` L176, `pose` L320 |
| Entre-deux (2D) | `ui/contextual/match_between.gd` (5500 l.), `match_terrain_2d.gd` | `_ready` L983 |
| Consignes / banc / équipe en direct | `ui/contextual/match_consignes_fenetre.gd`, `match_banc_fm.gd`, `match_equipe.gd` | `ouvrir_fenetre_consignes` (live_view L1861) |
| Après-match | `ui/contextual/apres_match.gd` | `_ready` L71 |
| Chef de scène (pièces, direct) | `ui/contextual/director.gd` | `open_room` L254 |
| Presse après match | `ui/immersive08/conference_presse.gd` | `main.gd` `_open_postmatch_press` |

## Hors coque
| Écran | Fichier(s) | Entrée |
|---|---|---|
| Accueil, création, packs | `ui/entry_screens.gd`, `ui/immersive08/entry_canvas.gd`, `creation_canvas.gd`, `ui/pack_views.gd` | `build` |
| Intro, crédits | `intro/intro_sequence.gd`, `ui/credits_view.gd` | — |
