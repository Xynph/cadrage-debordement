extends Control
## Page « Préparer l’Europe » (décision de Léo du 19/11/2026 : jamais de petite fenêtre) : remplace l'ancienne fenêtre
## du brouillon européen. Brouillon consultatif : aucune inscription ni modification de carrière. Ouverte depuis
## l'Effectif (« Préparer l’Europe → ») ; « ← Retour » et Échap ramènent à l'écran d'origine, Précédent aussi.
## Le brouillon (joueurs cochés, dernier rapport) vit dans `management_ui.europe` : il survit à un nouveau rendu.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Kit = preload("res://ui/immersive08/tactics_kit.gd")
const FocusLater = preload("res://ui/focus_later.gd")
const ROUTE := "Préparation Europe"
var app: Control
var preview: Dictionary
var selected: Dictionary = {}
var choices: Array[CheckButton] = []
var count: Label
var result: Label
var verify: Button
var pending := false
var requested_ids: Array = []
var etat: Dictionary

## Ouvre la page si le moteur projette une préparation européenne.
static func open(owner_app: Control) -> void:
	if not owner_app.model.get("epcrPreparation") is Dictionary: return
	if owner_app.route != ROUTE:
		owner_app.management_ui.europe_origine = owner_app.route
		owner_app.management_ui.erase("europe")
	owner_app._navigate(ROUTE)
	var cible := owner_app.root_content.find_child("EpcrVerify", true, false) as Control
	if cible != null: cible.grab_focus.call_deferred()

static func retour(owner_app: Control) -> void:
	var navigation: Node = owner_app.get("navigation_controller")
	if is_instance_valid(navigation) and navigation._destination(-1) >= 0:
		navigation._travel(-1)
		return
	owner_app._navigate(str(owner_app.management_ui.get("europe_origine", "Effectif")))

static func build(owner_app: Control, canvas: Control) -> void:
	var page: Control = load("res://ui/immersive08/europe_canvas.gd").new()
	page.app = owner_app
	canvas.add_child(page)
	D.place(page, Rect2(0, 0, 2248, 1244))
	page._construire()

func _construire() -> void:
	name = "EpcrPreparationDialog"
	var data: Variant = app.model.get("epcrPreparation")
	if not app.management_ui.has("europe") or str(app.management_ui.europe.get("competition", "")) != str(data.get("competitionId", "") if data is Dictionary else ""):
		app.management_ui.europe = {"competition": str(data.get("competitionId", "") if data is Dictionary else ""), "selected": {}, "result": "", "preview": {}, "pret": false, "pending": false, "requested": []}
	etat = app.management_ui.europe
	preview = (etat.preview if not etat.preview.is_empty() else (data.duplicate(true) if data is Dictionary else {}))
	var retour_lien := Kit.lien(self, Rect2(0, 4, 0, 38), "← Retour", func(): retour(app), "EuropeRetour", 20)
	C.style_bouton_lien(retour_lien, 20)
	retour_lien.accessibility_name = "Retour à l’écran d’origine · Échap"
	Kit.touche(self, retour_lien.size.x / C.density + 10, 32, "Échap")
	Kit.titre_page(self, 0, 98, "Préparer l’Europe", 56, 1200).name = "EuropeTitre"
	var coupe: String = str(app.pack_manager.competition(str(preview.get("competitionId", "")), "career").get("name", "Coupe d’Europe"))
	Kit.texte(self, 0, 134, coupe + " · " + str(preview.get("season", "")), Charte.IVOIRE, 1400, 22)
	var notice := Kit.texte(self, 0, 170, "Prépare une liste pour vérifier ses limites et la présence de ta feuille actuelle. Ce brouillon ne vaut pas inscription officielle et reste local.", Charte.IVOIRE_2, 1700, 19)
	notice.name = "EpcrPreparationNotice"
	Kit.texte(self, 0, 198, str(preview.get("notice", "Les qualifications de première ligne, contrats et inscriptions restent à confirmer.")), Charte.IVOIRE_2, 1700, 18)
	count = Kit.texte(self, 0, 244, "", Charte.IVOIRE, 1200, 22)
	count.name = "EpcrPreparationCount"
	var tout := Kit.lien(self, Rect2(1500, 220, 0, 36), "Tout sélectionner", func(): _select_all(true), "EpcrSelectAll", 19)
	C.style_bouton_lien(tout, 19)
	var rien := Kit.lien(self, Rect2(1760, 220, 0, 36), "Vider la liste", func(): _select_all(false), "EpcrSelectNone", 19)
	C.style_bouton_lien(rien, 19)
	var defile := ScrollContainer.new()
	defile.name = "EpcrCandidateScroll"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.follow_focus = true
	add_child(defile)
	D.place(defile, Rect2(0, 270, 1500, 760))
	var lignes := C.v(4)
	C.fill(lignes)
	defile.add_child(lignes)
	for candidate: Dictionary in preview.get("candidates", []):
		var id := str(candidate.id)
		if not bool(etat.pret): selected[id] = true
		elif etat.selected.has(id): selected[id] = true
		var box := CheckButton.new()
		box.name = "EpcrCandidate" + str(choices.size())
		box.text = str(candidate.get("name", id)) + " · " + str(candidate.get("pos", "Poste à confirmer"))
		box.tooltip_text = "Qualification de première ligne à confirmer" if not candidate.get("qualificationKnown", false) else "Qualification de première ligne renseignée"
		box.set_meta("player_id", id)
		box.add_theme_font_override("font", C.BODY)
		box.add_theme_font_size_override("font_size", maxi(12, C.px(19)))
		box.custom_minimum_size.y = C.px(40)
		box.button_pressed = selected.has(id)
		box.toggled.connect(func(value: bool):
			if value: selected[id] = true
			else: selected.erase(id)
			_changed())
		lignes.add_child(box)
		choices.append(box)
	etat.pret = true
	verify = Button.new()
	verify.name = "EpcrVerify"
	verify.text = "Vérifier ce brouillon"
	verify.pressed.connect(_verify)
	add_child(verify)
	C.style_bouton_ivoire_plein(verify, 21)
	D.place(verify, C.reach_rect(Rect2(1560, 300, 440, 56)))
	result = Kit.texte(self, 1560, 400, "", Charte.IVOIRE, 640, 19)
	result.name = "EpcrPreparationResult"
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size.y = C.px(700)
	_brancher(app)
	pending = bool(etat.pending)
	requested_ids = etat.requested
	var texte_conserve := str(etat.result)
	_changed(false)
	verify.disabled = not preview.get("supported", false)
	if not texte_conserve.is_empty(): result.text = texte_conserve
	if pending:
		verify.disabled = true
		for box in choices: box.disabled = true
		result.text = "Vérification du brouillon…"
	if verify.disabled: result.text = "La référence 2026/27 ne permet pas de vérifier cette saison."

func _ids() -> Array:
	var ids: Array = []
	for box in choices:
		var id := str(box.get_meta("player_id"))
		if selected.has(id): ids.append(id)
	return ids

func _changed(effacer := true) -> void:
	etat.selected = selected.duplicate()
	count.text = "%d joueurs dans le brouillon · plafond initial : 42" % selected.size()
	if effacer:
		result.text = "Brouillon modifié : relance la vérification."
		etat.result = result.text
		etat.rapport = false

func _select_all(value: bool) -> void:
	if pending: return
	selected.clear()
	for box in choices:
		box.set_pressed_no_signal(value)
		if value: selected[str(box.get_meta("player_id"))] = true
	_changed()

func _verify() -> void:
	if pending: return
	if app.waiting:
		result.text = "Une action est en cours. Réessaie après sa réponse."
		return
	requested_ids = _ids()
	etat.requested = requested_ids
	etat.pending = true
	pending = true
	verify.disabled = true
	for box in choices: box.disabled = true
	result.text = "Vérification du brouillon…"
	if not app._command("epcr_preview", {"registeredIds": requested_ids, "competitionId": preview.get("competitionId", "")}):
		_recevoir_echec("La vérification n’a pas pu démarrer. Réessaie.", app)

## Les réponses du moteur s'appliquent à l'état gardé dans `management_ui.europe`, même si la page a été reconstruite
## entre-temps (un nouveau rendu pendant la vérification ne perd ni le brouillon ni le verdict).
static func _brancher(owner_app: Control) -> void:
	if owner_app.has_meta("europe_branche"): return
	owner_app.set_meta("europe_branche", true)
	var script: Script = load("res://ui/immersive08/europe_canvas.gd")
	owner_app.bridge.model_changed.connect(script._recevoir_modele.bind(owner_app))
	owner_app.bridge.command_failed.connect(script._recevoir_echec.bind(owner_app))

static func _recevoir_modele(value: Dictionary, owner_app: Control) -> void:
	var donnees: Variant = owner_app.management_ui.get("europe")
	if not donnees is Dictionary or not bool(donnees.get("pending", false)) or not owner_app.bridge.last_response_ok or owner_app.last_command != "epcr_preview": return
	var data: Variant = value.get("epcrPreparation")
	if not data is Dictionary: return
	# Une réponse d'une autre action ne doit jamais valider ce brouillon.
	if data.get("registeredIds", []) != donnees.get("requested", []): return
	donnees.preview = data.duplicate(true)
	donnees.pending = false
	donnees.rapport = true
	var page := owner_app.find_child("EpcrPreparationDialog", true, false)
	if page != null: page._relire()

static func _recevoir_echec(message: String, owner_app: Control) -> void:
	var donnees: Variant = owner_app.management_ui.get("europe")
	if not donnees is Dictionary or not bool(donnees.get("pending", false)): return
	donnees.pending = false
	donnees.rapport = false
	donnees.result = message
	var page := owner_app.find_child("EpcrPreparationDialog", true, false)
	if page != null: page._relire()

func _relire() -> void:
	pending = false
	preview = etat.preview if not etat.preview.is_empty() else preview
	_finish_request()
	if bool(etat.get("rapport", false)): _show_report()
	else: result.text = str(etat.result)
	FocusLater.grab(verify)

func _finish_request() -> void:
	pending = false
	verify.disabled = false
	for box in choices: box.disabled = false

func _show_report() -> void:
	count.text = "%d joueurs dans le brouillon · plafond initial : 42" % selected.size()
	verify.disabled = not preview.get("supported", false)
	var lines: Array[String] = []
	for key in ["registration", "teamSheet"]:
		var report: Dictionary = preview.get(key, {})
		var caption := "Liste" if key == "registration" else "Feuille actuelle"
		var state := str(report.get("status", "unknown"))
		lines.append(caption + " : " + {"valid": "critères contrôlés respectés", "invalid": "points à corriger", "unknown": "informations à confirmer"}.get(state, "non vérifiée"))
		for message in report.get("messages", []): lines.append("• " + str(message))
		for message in report.get("pendingMessages", []): lines.append("• À confirmer : " + str(message))
	if not preview.get("supported", false): lines.append("La référence 2026/27 ne permet pas de vérifier cette saison.")
	lines.append("Les qualifications et l’inscription officielle ne sont pas certifiées par ce contrôle.")
	result.text = "\n".join(lines)
	etat.result = result.text
