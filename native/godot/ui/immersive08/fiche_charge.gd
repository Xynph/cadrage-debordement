extends RefCounted
## Sous-page « Charge individuelle » de la fiche joueur (décision de Léo du 19/11/2026 : jamais de petite fenêtre) :
## remplace l'ancienne fenêtre « Consignes · nom ». Ouverte par « Régler la charge individuelle → » de la fiche, elle
## garde la coque, un retour « ← Retour à la fiche » (Échap) et une étape d'historique (`management_ui.charge_joueur`,
## voir navigation_controller.gd). Le choix part au moteur par la commande `set_player_load`.
## Exemple : `FicheCharge.ouvrir(app, player)` ; la fiche appelle `FicheCharge.build(app, page, player)`.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const IntensiteAuto = preload("res://ui/immersive08/intensite_auto.gd")
## [mode du moteur, libellé, effet].
const MODES := [["collective", "Auto", "L’intensité de la règle de sa forme (onglet Individuel de l’Entraînement)."],
	["repos", "Récupération", "Charge allégée pour retrouver de la fraîcheur."],
	["normal", "Charge normale", "La séance complète, sans travail supplémentaire."],
	["intense", "Travail intense", "Plus de progression, plus de fatigue."]]

## La sous-page est demandée pour ce joueur ?
static func active(app: Control, player: Dictionary) -> bool:
	return not str(player.get("id", "")).is_empty() and str(app.management_ui.get("charge_joueur", "")) == str(player.get("id", ""))

static func ouvrir(app: Control, player: Dictionary) -> void:
	app.management_ui.charge_joueur = str(player.get("id", ""))
	app.selected_player = str(player.get("id", ""))
	app.set_meta("immersive08_full_player", true)
	app._navigate("Effectif", true, true)
	var cible := app.root_content.find_child("FicheChargeRetour", true, false) as Control
	if cible != null: cible.grab_focus.call_deferred()

static func fermer(app: Control) -> void:
	app.management_ui.erase("charge_joueur")
	app._navigate("Effectif", true, true)

static func build(app: Control, page: Control, player: Dictionary) -> void:
	var retour := Kit.lien(page, Rect2(0, 4, 0, 38), "← Retour à la fiche", func(): fermer(app), "FicheChargeRetour", 20)
	retour.accessibility_name = "Retour à la fiche · Échap"
	Kit.touche(page, retour.size.x / C.density + 10, 32, "Échap")
	Kit.titre_page(page, 0, 98, "Charge individuelle · " + Kit.casse(str(player.get("name", ""))), 38, 1600).name = "IndividualInstructions"
	D.line(page, Vector2(0, 122), Vector2(2248, 122), Charte.FILET)
	var bloc := D.rect(page, Rect2(0, 146, 1300, 520), Charte.PANNEAU, 24)
	bloc.name = "FicheChargePage"
	bloc.mouse_filter = Control.MOUSE_FILTER_PASS
	var resume := "%s · condition %s %% · charge %s / 100" % [str(player.get("pos", "")), G.n(player.get("condition", 0)), G.n(player.get("physicalLoad", 0))]
	Kit.texte(bloc, 28, 46, resume, Charte.IVOIRE, 1240, 20)
	var raison: String = app.SquadViews.player_load_unavailable_reason(app)
	if not raison.is_empty(): Kit.texte(bloc, 28, 84, raison, Charte.D, 1240, 18).name = "PlayerLoadUnavailableReason"
	D.line(bloc, Vector2(28, 104), Vector2(1272, 104), Charte.FILET)
	var actuel := str(player.get("loadPlan", "collective"))
	for i in MODES.size():
		var mode: Array = MODES[i]
		var choisi := actuel == str(mode[0])
		var ligne := Button.new()
		ligne.name = "IndividualLoad_" + str(mode[0])
		Kit.styler_ligne(ligne, Color.TRANSPARENT, choisi, Charte.SELECTION)
		bloc.add_child(ligne)
		D.place(ligne, Rect2(20, 116 + i * 56, 1260, 52))
		D.line(ligne, Vector2(0, 51), Vector2(1260, 51), Charte.FILET)
		if choisi: Kit.marqueur(ligne, Rect2(6, 8, 4, 36))
		var libelle := str(mode[1])
		# Auto : l’intensité que donne la règle de sa forme (blessé : repos).
		if mode[0] == "collective": libelle += "  →  " + str(IntensiteAuto.NOMS_MODE.get(IntensiteAuto.intensite(app, player.merged({"loadPlan":"collective", "loadMode":""}, true)), ""))
		D.text(ligne, 22, 33, libelle, 20, Charte.IVOIRE, 700, 340, HORIZONTAL_ALIGNMENT_LEFT, true).add_theme_font_override("font", Kit.texte_gras())
		ligne.tooltip_text = str(mode[2])
		Kit.texte(ligne, 1240, 33, "actuel" if choisi else "Choisir →", Charte.IVOIRE if choisi else Charte.IVOIRE, 160, 18, HORIZONTAL_ALIGNMENT_RIGHT)
		ligne.disabled = not raison.is_empty()
		if ligne.disabled: ligne.focus_mode = Control.FOCUS_NONE
		ligne.accessibility_name = "%s · %s%s" % [mode[1], mode[2], " · actuel" if choisi else ""]
		var cle := str(mode[0])
		ligne.pressed.connect(func(): app._command("set_player_load", {"playerId":player.id, "mode":cle}))
