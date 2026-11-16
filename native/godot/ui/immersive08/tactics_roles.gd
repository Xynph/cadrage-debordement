extends RefCounted
## Tireurs et lanceur : consignes individuelles du XV (buteur, buteur de secours, lanceur en touche,
## jeu au pied d'occupation), ouvertes depuis l'écran Composition. Le moteur projette `tactics.roles`
## (native/engine/model.cjs, playerRolesView) et reçoit les choix par `set_tactics` avec `roles`.
## Premier choix de chaque liste : « Choix du staff » (le meilleur à ce rôle).
const C = preload("res://ui/immersive08/components.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const PersonName = preload("res://ui/person_name.gd")

## Projection des rôles (vide si le moteur ne la donne pas).
static func view(model: Dictionary) -> Dictionary:
	var tactics: Variant = model.get("tactics", {})
	if not tactics is Dictionary: return {}
	var roles: Variant = tactics.get("roles", {})
	return roles if roles is Dictionary else {}

static func _name(person: Variant) -> String:
	if not person is Dictionary or person.is_empty(): return "—"
	return PersonName.initial_and_surname(str(person.get("name", "")))

static func _value(person: Variant) -> String:
	if not person is Dictionary or person.get("value") == null: return "—"
	return str(int(person.get("value")))

## Lignes de l'écran : pour chaque rôle, libellés de la liste (staff d'abord), identifiants
## (chaîne vide = choix du staff) et index retenu.
static func rows(model: Dictionary) -> Array:
	var result: Array = []
	for role: Variant in view(model).get("roles", []):
		if not role is Dictionary: continue
		var attribute := str(role.get("attributeLabel", ""))
		var staff: Variant = role.get("staff")
		var labels: Array = ["Choix du staff · %s (%s %s)" % [_name(staff), attribute, _value(staff)]]
		var ids: Array = [""]
		var chosen: Variant = role.get("chosen")
		var chosen_id := str(chosen.get("id", "")) if chosen is Dictionary else ""
		var selected := 0
		for person: Variant in role.get("candidates", []):
			if not person is Dictionary: continue
			labels.append("%s · %s · %s %s" % [_name(person), str(person.get("pos", "")), attribute, _value(person)])
			ids.append(str(person.get("id", "")))
			if str(person.get("id", "")) == chosen_id: selected = ids.size() - 1
		# Joueur désigné hors du XV (blessé, remplaçant) : gardé dans la liste, signalé.
		if not chosen_id.is_empty() and selected == 0:
			labels.append("%s · hors du XV · %s %s" % [_name(chosen), attribute, _value(chosen)])
			ids.append(chosen_id)
			selected = ids.size() - 1
		result.append({"id": str(role.get("id", "")), "label": str(role.get("label", "")), "labels": labels, "ids": ids, "selected": selected, "outside": not chosen_id.is_empty() and not bool(role.get("inLineup", true))})
	return result

## Charge utile de `set_tactics` pour un choix (consignes d'équipe inchangées).
static func payload(model: Dictionary, role_id: String, player_id: String) -> Dictionary:
	var tactics: Dictionary = model.get("tactics", {}) if model.get("tactics") is Dictionary else {}
	return {"attack": tactics.get("attack", "equilibre"), "defense": tactics.get("defense", "equilibre"), "roles": {role_id: null if player_id.is_empty() else player_id}}

## Mise en garde du staff sur le buteur désigné (texte vide sans alerte).
static func warning(model: Dictionary) -> String:
	var alerte: Variant = view(model).get("alerte")
	if not alerte is Dictionary: return ""
	return "Le staff te met en garde : %s tire à %s au but, %s à %s. Sur une saison, l’écart se paie en points." % [str(alerte.get("name", "")), _value(alerte), str(alerte.get("staffName", "")), str(int(alerte.get("staffValue", 0)))]

## Corps de la fenêtre : une liste par rôle. `on_choice` reçoit la charge utile de `set_tactics`.
static func body(model: Dictionary, on_choice: Callable) -> VBoxContainer:
	var box := C.v(10)
	box.name = "TacticsRolesBody"
	var editable := bool(view(model).get("editable", false))
	box.add_child(C.wrap("Le staff désigne par défaut le meilleur à chaque rôle. Tes choix valent pour les prochains matchs, dès le coup d’envoi.", 18))
	for row: Dictionary in rows(model):
		var line := C.h(12)
		line.name = "TacticsRoleRow_" + row.id
		box.add_child(line)
		var caption := C.wrap(row.label, 20, C.IVORY, false, 700)
		caption.custom_minimum_size.x = 250
		line.add_child(caption)
		var choice := OptionButton.new()
		choice.name = "TacticsRole_" + row.id
		choice.accessibility_name = row.label
		for label: String in row.labels: choice.add_item(label)
		choice.select(int(row.selected))
		choice.disabled = not editable
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ids: Array = row.ids
		var role_id: String = row.id
		choice.item_selected.connect(func(index: int): on_choice.call(payload(model, role_id, str(ids[index]))))
		line.add_child(choice)
		if row.outside:
			box.add_child(C.wrap("Ce joueur n’est pas dans le XV de départ : le suivant prend le relais.", 16, C.AMBER))
	var text := warning(model)
	if not text.is_empty():
		var alert := C.wrap(text, 18, C.ALERT, false, 700)
		alert.name = "TacticsRolesWarning"
		box.add_child(alert)
	if not editable:
		box.add_child(C.wrap("Les tireurs et le lanceur se désignent avant le coup d’envoi.", 16, C.MUTED))
	return box

## Fenêtre « Tireurs et lanceur » de l'écran Composition.
static func open(app: Control) -> void:
	app._clear_dialogs()
	var dialog := AcceptDialog.new()
	dialog.name = "TacticsRoles"
	app._prepare_dialog(dialog, 860)
	dialog.title = "Tireurs et lanceur"
	dialog.add_child(body(app.model, func(data: Dictionary):
		dialog.queue_free()
		app._command("set_tactics", data)))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	app.add_child(dialog)
	Dialogs.show_centered(dialog, Vector2i(860, 560))
