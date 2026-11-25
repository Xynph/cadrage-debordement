extends RefCounted
## Coque du jeu (main.gd) : confirmations (fenêtre ou bloc en place dans la page), avis, menu de la carrière (Échap,
## logo du rail) et fichiers de carrière (import, export).
## Fonctions statiques ; `m` est la coque (main.gd), qui garde l’état et les noms appelés de l’extérieur.
const G = preload("res://ui/game_skin.gd")
const ImmersiveDialogs = preload("res://ui/immersive08/dialogs.gd")

# Recettes Godot seulement (ancien mode France 30, moteur lancé avec CD_MODES_HERITES=1).
static func create_career(m: Control, id: int) -> void:
	var action := func(): m._command("new_career",{"club":id,"mode":"common"})
	if m._has_career(): m.confirm("Une nouvelle histoire", "La carrière actuelle sera conservée dans Copies de sécurité avant son remplacement. Si cette copie ne peut pas être écrite, le remplacement sera refusé. Prendre les rênes de %s ?" % m.catalogue[id].name, action)
	else: action.call()

static func confirm_decision(m: Control, command: String, payload: Dictionary, title: String, text: String, callback: Callable) -> void:
	var preview := preload("res://ui/decision_preview.gd")
	var detail: Dictionary = preview.describe(command,payload,m.model)
	if detail.is_empty(): m.confirm(title,text,callback)
	elif m._confirmation_club(title, [text, m._lignes_decision(detail)], "Confirmer", callback): return
	else: preview.open(m,title,text,detail,callback)

## Écrans Club, Staff, Travail du club et Stratégie : la confirmation s'ouvre EN PLACE dans la page (bloc de
## confirmation_en_place.gd), jamais dans une fenêtre (décision de Léo, 19/11/2026). Faux si la page n'a pas son hôte.
static func confirmation_club(m: Control, title: String, lignes: Array, libelle_ok: String, callback: Callable) -> bool:
	if m.route not in ["Club", "Staff", "Travail du club", "Stratégie"] or not is_instance_valid(m.root_content): return false
	var hote := m.root_content.find_child("ClubConfirmHote", true, false) as Container
	if hote == null or not hote.is_visible_in_tree(): return false
	m._clear_dialogs()
	preload("res://ui/confirmation_en_place.gd").ouvrir(m, hote, "ClubConfirmation", title, lignes, libelle_ok, callback)
	return true

static func lignes_decision(detail: Dictionary) -> String:
	var parts: Array[String] = []
	if int(detail.get("amount", 0)) != 0: parts.append(("Débit immédiat : " if str(detail.get("direction", "debit")) == "debit" else "Versement : ") + str(G.euros(detail.amount)))
	if int(detail.get("recurring_amount", 0)) != 0: parts.append("%s : %s" % [str(detail.get("recurring_label", "Ensuite")).capitalize(), str(G.euros(detail.recurring_amount))])
	if not str(detail.get("later", "")).is_empty(): parts.append(str(detail.later))
	if not str(detail.get("caution", "")).is_empty(): parts.append(str(detail.caution))
	return "\n".join(parts)

static func confirm(m: Control, title: String, text: String, callback: Callable, focus_cancel: bool) -> void:
	if m._confirmation_club(title, [text], "Confirmer", callback): return
	m._clear_dialogs()
	var d := ConfirmationDialog.new()
	m._prepare_dialog(d, 650)
	d.title = title
	d.dialog_text = text
	d.get_ok_button().text = "CONFIRMER"
	d.get_cancel_button().text = "ANNULER"
	m.add_child(d)
	d.confirmed.connect(func(): callback.call(); d.queue_free())
	d.canceled.connect(d.queue_free)
	d.popup_centered(Vector2i(650,180))
	if focus_cancel: d.get_cancel_button().grab_focus()

static func prepare_dialog(m: Control, dialog: AcceptDialog, width: int) -> void:
	# Configure wrapping before text/insertion can queue an oversized minimum.
	ImmersiveDialogs.prepare(dialog,width,m.accent)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: m.call_deferred("_refresh_coach"))

static func pause_menu(m: Control) -> void:
	m._clear_dialogs()
	if not m._live().is_empty() and not m._live().get("paused",false) and not m._live().get("finished",false):
		if not m._command("pause",{"paused":true}): return
	var d := AcceptDialog.new()
	d.name = "ImmersivePauseMenu"
	m._prepare_dialog(d, 820)
	d.title = "Ta carrière"
	ImmersiveDialogs.pause_content(d,m)
	for pair in [["Accueil","home"],["Mes carrières","career_slots"],["Exporter","export"],["Importer","import"],["Copies de sécurité","profile_safety"],["Paramètres","settings"],["Quitter","quit"]]:
		var button := d.add_button(pair[0],false,pair[1])
		if pair[1] == "profile_safety": button.name = "ProfileSafetyOpen"
	d.custom_action.connect(func(action: String):
		d.hide(); d.queue_free()
		match action:
			"home": m._navigate("Accueil")
			"export": m.open_file(false)
			"import": m.open_file(true)
			"career_slots": m.open_career_slots()
			"profile_safety": m.open_profile_safety()
			"settings": m.settings()
			"quit": m.request_quit()
	)
	m.add_child(d)
	d.confirmed.connect(d.queue_free)
	d.canceled.connect(d.queue_free)
	ImmersiveDialogs.show_centered(d,Vector2i(820,370))

static func open_file(m: Control, importing: bool) -> void:
	m.import_mode = importing
	var file_dialog: FileDialog = m.file_dialog
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Importer une carrière · 8 à 24 Mio selon l’édition" if importing else "Exporter une carrière"
	file_dialog.current_file = "" if importing else "Rugby-Legacy-27.json"
	file_dialog.popup_centered_ratio(0.7)

static func file_selected(m: Control, path: String) -> void:
	m.file_dialog.hide()
	if m.import_mode:
		var f := FileAccess.open(path,FileAccess.READ)
		if f == null: m._refuse_action("Le fichier ne peut pas être lu : " + error_string(FileAccess.get_open_error())); return
		var byte_count := f.get_length()
		if byte_count > NativeEngineBridge.EXTENDED_IMPORT_LIMIT_BYTES:
			f.close()
			m._refuse_action("Fichier trop volumineux (24 Mio UTF-8 maximum).")
			return
		var buffer := f.get_buffer(byte_count)
		f.close()
		# Le décodeur UTF-8 s'arrête au premier octet NUL.
		var has_nul := buffer.has(0)
		var text := "" if has_nul else buffer.get_string_from_utf8()
		var control_characters := RegEx.create_from_string("[\\x01-\\x08\\x0b\\x0c\\x0e-\\x1f]")
		if has_nul or control_characters.search(text) != null:
			m._refuse_action("Le fichier JSON contient un caractère de contrôle non échappé.")
			return
		var refusal := NativeEngineBridge.import_preflight(text, byte_count)
		if not refusal.is_empty():
			m._refuse_action(refusal)
			return
		m.confirm("Reprendre cette carrière", "Cette carrière sera vérifiée avant sa reprise. La carrière actuelle sera conservée dans Copies de sécurité avant son remplacement ; si cette copie ne peut pas être écrite, l'importation sera refusée.", func(): m._command("import", {"text":text}, "Réception"), m._has_career())
	else:
		if m.waiting: m._refuse_action("Une décision est en cours. Réessaie après sa réponse."); return
		m.export_path = path
		m._command("export")

static func write_export(m: Control) -> bool:
	var destination: String = m.export_path
	m.export_path = ""
	var text := str(m.model.get("meta",{}).get("exportText",""))
	if text.is_empty(): m._failed("Aucun export de carrière n’a été reçu."); return false
	var temporary := destination + ".tmp-" + str(OS.get_process_id()) + "-" + str(Time.get_ticks_usec())
	var f := FileAccess.open(temporary,FileAccess.WRITE)
	if f == null: m._failed("L'export ne peut pas être écrit."); return false
	f.store_string(text)
	f.flush()
	var error := f.get_error()
	f.close()
	var replacement_error := error_string(error) if error != OK else preload("res://atomic_file.gd").replace_staged(temporary, destination)
	if not replacement_error.is_empty():
		DirAccess.remove_absolute(temporary)
		m._failed("Écriture de l'export refusée : " + replacement_error)
		return false
	return true

static func notice(m: Control, title: String, text: String) -> void:
	m._clear_dialogs()
	var d:=AcceptDialog.new()
	m._prepare_dialog(d, 620)
	d.title=title
	d.dialog_text=text
	m.add_child(d)
	d.confirmed.connect(d.queue_free)
	d.popup_centered(Vector2i(620,190))

static func clear_dialogs(m: Control) -> void:
	for child in m.get_children():
		if child is AcceptDialog and child!=m.file_dialog:
			if is_instance_valid(m.navigation_controller) and m.navigation_controller.is_suspended_reader(child): continue
			child.hide()
			child.queue_free()
