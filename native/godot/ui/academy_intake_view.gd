extends RefCounted
# Nouvelle génération du 1er juillet : choisir les jeunes gardés en Crabos et, si besoin,
# libérer d'abord des jeunes du centre (Crabos 16-17 ans, plafond de 35 places).
const G = preload("res://ui/carnet_skin.gd")

static func entry(app: Control, parent: Node) -> void:
	var data: Dictionary = app.model.get("clubLife", {}).get("academyIntake", {})
	if not data.get("available", false): return
	var b := G.button("NOUVELLE GÉNÉRATION · %d JEUNES À EXAMINER →" % data.players.size(), func(): open(app), true)
	b.name = "AcademyIntakeOpen"
	parent.add_child(b)
	parent.add_child(G.wrap("Sans décision avant la première journée, le responsable de la formation choisira pour vous.", 13))

static func _line(p: Dictionary) -> String:
	var level := "niveau %s" % str(p.rating) if p.get("rating") != null else "niveau inconnu"
	var span: Variant = p.get("potentialRange")
	var ceiling := " · potentiel %d–%d" % [int(span.min), int(span.max)] if span is Dictionary else ""
	var prodigy := " · PRODIGE" if p.get("prodigy", false) else ""
	return "%s · %s · %d ans · %s%s%s" % [p.name, p.pos, int(p.age), level, ceiling, prodigy]

static func open(app: Control) -> AcceptDialog:
	app._clear_dialogs()
	var data: Dictionary = app.model.get("clubLife", {}).get("academyIntake", {})
	var academy: Array = app.model.get("decisions", {}).get("development", {}).get("academy", [])
	var dialog := AcceptDialog.new()
	dialog.name = "AcademyIntake"
	dialog.title = "Nouvelle génération du centre"
	dialog.get_ok_button().text = "VALIDER LE CHOIX"
	dialog.add_cancel_button("PLUS TARD")
	app._prepare_dialog(dialog, 820)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var list := G.v(10)
	G.fill(list, true)
	scroll.add_child(list)
	var keep := {}
	var release := {}
	var counter := G.wrap("", 16, G.INK)
	counter.name = "AcademyIntakeCounter"
	var crabos_now := int(data.get("crabos", 0))
	var cap := int(data.get("crabosCap", 35))
	var refresh := func():
		var released_crabos := 0
		for p: Dictionary in academy:
			if release.has(str(p.id)) and int(p.age) <= 17: released_crabos += 1
		var total := crabos_now - released_crabos + keep.size()
		var everyone := int(data.get("academy", 0)) - release.size() + keep.size()
		var limit := int(data.get("capacity", 75))
		var full := total > cap or everyone > limit
		counter.text = "Crabos après votre choix : %d / %d · centre : %d / %d%s" % [total, cap, everyone, limit, "  — faites de la place avant de valider" if full else ""]
		dialog.get_ok_button().disabled = full
	list.add_child(counter)
	list.add_child(G.section("Les candidats", "Gardez ceux que vous voulez former. Les autres quittent le centre."))
	for p: Dictionary in data.players:
		var box := CheckBox.new()
		box.name = "Keep_" + str(p.id).replace("-", "_")
		box.text = _line(p)
		box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.toggled.connect(func(on: bool):
			if on: keep[str(p.id)] = true
			else: keep.erase(str(p.id))
			refresh.call())
		list.add_child(box)
	list.add_child(G.separator())
	list.add_child(G.section("Faire de la place", "Les jeunes libérés quittent définitivement le centre."))
	for p: Dictionary in academy:
		var box := CheckBox.new()
		box.name = "Release_" + str(p.id).replace("-", "_")
		box.text = ("Crabos · " if int(p.age) <= 17 else "Espoirs · ") + _line(p)
		box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.toggled.connect(func(on: bool):
			if on: release[str(p.id)] = true
			else: release.erase(str(p.id))
			refresh.call())
		list.add_child(box)
	refresh.call()
	dialog.confirmed.connect(func():
		app._command("academy_intake_confirm", {"context": data.context, "confirmed": true, "keep": keep.keys(), "release": release.keys()})
		dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	preload("res://ui/immersive08/dialogs.gd").show_centered(dialog, Vector2i(820, 560))
	return dialog
