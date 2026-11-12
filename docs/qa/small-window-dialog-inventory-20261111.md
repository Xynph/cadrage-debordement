# Inventaire des fenêtres natives — 11 novembre2026

36 appels directs de constructeurs et8 sous-classes de fenêtre sont relevés dans le code. Ce sont44 sites de construction ou de déclaration, pas44 dialogues distincts ni une preuve que tous leurs états ont été ouverts. La recette précise les états couverts.

| Source | Fabrique | Statut |
| --- | --- | --- |
| [native/godot/main.gd:153](../../native/godot/main.gd#L153) | `_ready` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/main.gd:384](../../native/godot/main.gd#L384) | `_failed` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/main.gd:894](../../native/godot/main.gd#L894) | `confirm` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/main.gd:916](../../native/godot/main.gd#L916) | `pause_menu` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/main.gd:1002](../../native/godot/main.gd#L1002) | `notice` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/main.gd:1038](../../native/godot/main.gd#L1038) | `_credits` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/pack_manager.gd:12](../../native/godot/pack_manager.gd#L12) | `_ready` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/academy_pathways_view.gd:236](../../native/godot/ui/academy_pathways_view.gd#L236) | `open_professional` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/club_views.gd:522](../../native/godot/ui/club_views.gd#L522) | `season_archives` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/coach_notes_view.gd:171](../../native/godot/ui/coach_notes_view.gd#L171) | `_confirm_remove` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/competition_editor_view.gd:219](../../native/godot/ui/competition_editor_view.gd#L219) | `_choose_import` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/competition_editor_view.gd:242](../../native/godot/ui/competition_editor_view.gd#L242) | `_choose_export` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/competition_editor_view.gd:295](../../native/godot/ui/competition_editor_view.gd#L295) | `_launch` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/contract_negotiation.gd:57](../../native/godot/ui/contract_negotiation.gd#L57) | `open` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/decision_feedback.gd:190](../../native/godot/ui/decision_feedback.gd#L190) | `_open` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/decision_preview.gd:56](../../native/godot/ui/decision_preview.gd#L56) | `open` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/decision_views.gd:45](../../native/godot/ui/decision_views.gd#L45) | `dialog` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/development_view.gd:140](../../native/godot/ui/development_view.gd#L140) | `open_player` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/entry_screens.gd:582](../../native/godot/ui/entry_screens.gd#L582) | `_choose_role` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/immersive08/academy_canvas.gd:152](../../native/godot/ui/immersive08/academy_canvas.gd#L152) | `_group_upgrade_reason` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/immersive08/academy_canvas.gd:641](../../native/godot/ui/immersive08/academy_canvas.gd#L641) | `_create_dialog` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/immersive08/fatigue_overview.gd:244](../../native/godot/ui/immersive08/fatigue_overview.gd#L244) | `open_adjustment` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/immersive08/squad_canvas.gd:460](../../native/godot/ui/immersive08/squad_canvas.gd#L460) | `_advanced` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/immersive08/tactics_canvas.gd:365](../../native/godot/ui/immersive08/tactics_canvas.gd#L365) | `_candidates` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/immersive08/tactics_canvas.gd:408](../../native/godot/ui/immersive08/tactics_canvas.gd#L408) | `_defense` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/immersive08/tactics_canvas.gd:421](../../native/godot/ui/immersive08/tactics_canvas.gd#L421) | `_individual` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/immersive08/training_canvas.gd:508](../../native/godot/ui/immersive08/training_canvas.gd#L508) | `_dialog` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/interclub_market_view.gd:216](../../native/godot/ui/interclub_market_view.gd#L216) | `_confirm_auction` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/manager_career_view.gd:16](../../native/godot/ui/manager_career_view.gd#L16) | `_confirm` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/match_screen.gd:482](../../native/godot/ui/match_screen.gd#L482) | `_confirm_reduced_bench` | Non couvert : état conditionnel / périmètre réservé |
| [native/godot/ui/navigation_controller.gd:165](../../native/godot/ui/navigation_controller.gd#L165) | `_build_palette` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/preferences_dialog.gd:10](../../native/godot/ui/preferences_dialog.gd#L10) | `open` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/preparation_briefing.gd:63](../../native/godot/ui/preparation_briefing.gd#L63) | `open_all` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/profile_safety_view.gd:163](../../native/godot/ui/profile_safety_view.gd#L163) | `_confirm` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/squad_views.gd:820](../../native/godot/ui/squad_views.gd#L820) | `comparison` | Ouvert dans les reçus (états précisés dans la recette) |
| [native/godot/ui/support_view.gd:181](../../native/godot/ui/support_view.gd#L181) | `_confirm` | Non couvert : état conditionnel / périmètre réservé |

## Sous-classes instanciées par ressource

| Source | Statut |
| --- | --- |
| [native/godot/match_action_review.gd:1](../../native/godot/match_action_review.gd#L1) | Non couvert (match en cours réservé) |
| [native/godot/ui/coach_notes_view.gd:1](../../native/godot/ui/coach_notes_view.gd#L1) | Ouvert dans le complément graphique |
| [native/godot/ui/competition_editor_view.gd:1](../../native/godot/ui/competition_editor_view.gd#L1) | Ouvert dans le complément graphique |
| [native/godot/ui/epcr_preparation_dialog.gd:1](../../native/godot/ui/epcr_preparation_dialog.gd#L1) | Non disponible dans la fixture commune |
| [native/godot/ui/interclub_market_view.gd:1](../../native/godot/ui/interclub_market_view.gd#L1) | Ouvert dans le complément graphique |
| [native/godot/ui/profile_safety_view.gd:1](../../native/godot/ui/profile_safety_view.gd#L1) | Ouvert dans le complément graphique |
| [native/godot/ui/regen_scouting_view.gd:1](../../native/godot/ui/regen_scouting_view.gd#L1) | Ouvert dans le complément graphique |
| [native/godot/ui/youth_development_view.gd:1](../../native/godot/ui/youth_development_view.gd#L1) | Ouvert dans le complément graphique |
