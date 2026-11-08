extends SceneTree
const Content = preload("res://guide/guide_content.gd")
const Store = preload("res://guide/guide_profile.gd")
const ROUTES := {"Accueil":"bienvenue", "Création":"club", "Bureau":"bureau", "Effectif":"effectif", "Composition":"composition", "Préparation":"entrainement", "Plan de jeu":"plan-jeu", "Vestiaire":"vestiaire", "Match":"premier-match", "Calendrier":"calendrier", "Classements":"classements", "Finances":"finances", "Recrutement":"recrutement", "Club":"territoire", "Packs":"packs", "Staff":"staff", "Formation":"formation", "Centre":"centre", "Presse":"presse", "Rivalités":"rivalites", "Travail du club":"travail-club", "Stratégie":"strategie", "Carrière":"carriere"}
var app: Control
var guide: Control
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures.append(message); printerr("FAIL: ", message)
func wait_model() -> void:
	var until := Time.get_ticks_msec() + 30000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
	check(not app.waiting and not app.model.is_empty(), "Réponse du moteur réel")
func command(id: String, payload: Dictionary = {}) -> void:
	app._command(id, payload); await wait_model()
	check(app.bridge.last_response_ok, "Commande réelle : " + id)
func attach() -> void:
	guide = load("res://guide/coach_guide.gd").new(); app.add_child(guide); guide.setup(app)
	# No speech is requested in this test; silent mode still displays useful text.
	guide.speech.set_muted(true); guide.profile.data.muted = true
func consider(route: String, model: Dictionary = {}, cmd: String = "snapshot", ok: bool = true) -> void:
	if app.route != route: app._navigate(route)
	guide.consider_context(route, app.model if model.is_empty() else model, cmd, ok)
func profiles() -> void:
	var directory: String = app._profile_path().path_join("legacy")
	DirAccess.make_dir_recursive_absolute(directory)
	var old := {"version":1,"enabled":false,"muted":true,"voice":"ancienne-voix","rate":1.25,"step":"composition","completed":["bienvenue"]}
	var file := FileAccess.open(directory.path_join("guide.json"), FileAccess.WRITE); file.store_string(JSON.stringify(old)); file.close()
	var store = Store.new(); store.load_profile(directory)
	check(store.last_error.is_empty() and not store.data.enabled and store.data.muted and store.data.step == "composition" and store.data.voice == "ancienne-voix", "Ancien v1 conservé sans réinitialiser les préférences")
	check(store.data.get("seen", null) is Array and store.data.get("events", null) is Array, "Champs contextuels optionnels complétés")
	for patch in [{"seen":["inconnu"]},{"seen":["bureau","bureau"]},{"events":["signed:../../secret"]},{"events":["cash:0:2026:1:".repeat(500)]}]:
		var invalid: Dictionary = store.data.duplicate(true); invalid.merge(patch,true)
		check(not store.save_profile(invalid), "Whitelist et bornes refusent " + str(patch.keys()))
	file = FileAccess.open(directory.path_join("guide.json"), FileAccess.WRITE); file.store_string("{interrompu"); file.close()
	var bytes := FileAccess.get_file_as_bytes(directory.path_join("guide.json"))
	var broken = Store.new(); broken.load_profile(directory)
	check(not broken.last_error.is_empty() and not broken.save_profile(old) and bytes == FileAccess.get_file_as_bytes(directory.path_join("guide.json")), "Profil malformé conservé, erreur visible sans écrasement")
func navigation_cases() -> void:
	# A tiny silent WAV supplies a real local audio backend in headless mode.
	# This observes Speech.requested, rather than mocking speak() or TTS.
	var directory: String = app._profile_path().path_join("navigation-audio-fixture")
	DirAccess.make_dir_recursive_absolute(directory)
	var wav := AudioStreamWAV.new(); wav.format = AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate = 24000
	var pcm := PackedByteArray(); pcm.resize(4800); wav.data = pcm
	check(wav.save_to_wav(directory.path_join("silence.wav")) == OK, "WAV de réception navigation créé")
	var bureau: String = Content.fragments("bureau")[0].text
	var centre: String = Content.fragments("centre")[0].text
	var file := FileAccess.open(directory.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"clips":[{"id":"test-bureau","text":bureau,"text_sha256":bureau.sha256_text(),"file":"silence.wav"},{"id":"test-centre","text":centre,"text_sha256":centre.sha256_text(),"file":"silence.wav"}]})); file.close()
	guide.speech.load_manifest(directory.path_join("manifest.json")); guide.speech.volume = 0; guide.speech.set_muted(false)
	var requested: Array[String] = []
	var on_requested := func(text: String): requested.append(text)
	guide.speech.requested.connect(on_requested)
	app._navigate("Bureau"); guide.refresh(); guide.consider_context(app.route,app.model,"snapshot",true)
	check(guide.expanded and guide.current_id == "bureau" and requested == [bureau], "Bureau automatique ouvert et première parole demandée")
	# Deliberately do not close the old automatic bubble before navigating.
	app._navigate("Centre"); guide.refresh(); guide.consider_context(app.route,app.model,"snapshot",true)
	check(guide.expanded and guide.current_id == "centre" and guide.bubble.text == centre and "centre" in guide.profile.data.seen, "Navigation réelle bulle ouverte : première visite Centre remplace Bureau")
	check(requested == [bureau,centre], "Navigation ne redemande jamais l'ancienne phrase Bureau")
	for i in 5: guide.refresh(); guide.consider_context(app.route,app.model,"snapshot",true)
	guide._layout(); guide.refresh(); guide.consider_context(app.route,app.model,"snapshot",true)
	check(requested == [bureau,centre], "Snapshots et layout du même écran sans relecture")
	app._navigate("Bureau"); guide.refresh(); guide.consider_context(app.route,app.model,"snapshot",true)
	check(not guide.expanded and requested == [bureau,centre], "Retour à un écran déjà vu ferme l'ancien contexte sans nouvelle parole")
	var reloaded = Store.new(); reloaded.load_profile(guide.profile.directory)
	check("bureau" in reloaded.data.seen and "centre" in reloaded.data.seen, "Deux premières visites persistées malgré navigation avec bulle ouverte")
	guide.open_tour(); var tour_id: String = guide.current_id
	app._navigate("Centre"); guide.refresh(); guide.consider_context(app.route,app.model,"snapshot",true)
	check(guide.expanded and guide.mode == "tour" and guide.current_id == tour_id, "Navigation conserve une visite guidée ouverte manuellement")
	guide.close(); guide.open_help()
	app._navigate("Bureau"); guide.refresh(); guide.consider_context(app.route,app.model,"snapshot",true)
	check(guide.expanded and guide.mode == "screen" and guide.current_id == "bureau", "Navigation conserve et actualise une aide ouverte manuellement")
	guide.close(); guide.profile.data.seen.erase("centre")
	var dialog := ConfirmationDialog.new(); app.add_child(dialog); dialog.popup_centered()
	app._navigate("Centre"); guide.refresh(); guide.consider_context(app.route,app.model,"snapshot",true)
	check(not guide.expanded and "centre" not in guide.profile.data.seen, "Navigation sous confirmation ne consomme pas la première visite")
	dialog.hide(); dialog.queue_free(); await process_frame
	guide.refresh(); guide.consider_context(app.route,app.model,"snapshot",true)
	check(guide.expanded and guide.current_id == "centre", "Conseil du nouvel écran disponible après confirmation")
	guide.close(); guide.speech.requested.disconnect(on_requested); guide.speech.set_muted(true); guide.speech.load_manifest()
	guide.profile.data.seen.erase("bureau"); guide.profile.data.seen.erase("centre")
func run() -> void:
	app = load("res://main.tscn").instantiate(); root.add_child(app); await wait_model(); app.timer.stop(); attach()
	check(guide.has_method("consider_context"), "API contextuelle disponible")
	if not guide.has_method("consider_context"): await finish(); return
	await command("new_career", {"club":0,"mode":"common"})
	await command("export")
	var export_before: Dictionary = JSON.parse_string(app.model.meta.exportText).state
	var disk_path: String = str(app.model.meta.dataDir).path_join("donnees.json")
	var disk_before := FileAccess.get_file_as_bytes(disk_path)
	await navigation_cases()
	check(Content.TOUR.size() == 15, "Quinze étapes de visite guidée conservées")
	for route in ROUTES:
		check(Content.for_route(route, app.model) == ROUTES[route], "Aide propre à " + route)
		var fragments: Array = Content.fragments(ROUTES[route])
		check(str(fragments[0].text).length() <= 181 and str(fragments[0].id).ends_with("-caractere"), "Conseil court de caractère : " + route)
		consider(route)
		check(guide.expanded and guide.current_id == ROUTES[route] and guide.bubble.text == fragments[0].text, "Première visite automatique en mode muet : " + route)
		check(not guide.speech.speaking and not guide.speech.player.playing, "Muet conserve la bulle sans son : " + route)
		guide.close()
		for i in 5: guide.refresh(); consider(route)
		guide._layout(); consider(route)
		check(not guide.expanded, "Snapshots, retour et layout discrets : " + route)
	# Restart reads persisted visits, without any career writes.
	guide.destroy(); await process_frame; attach(); consider("Bureau")
	check(not guide.expanded, "Pas de réapparition après rechargement du profil")
	guide.profile.data.seen.erase("centre")
	consider("Centre", {"meta":{"hasCareer":false},"club":null})
	check(not guide.expanded and "centre" not in guide.profile.data.seen, "Contexte carrière absent : visite non consommée")
	consider("Inconnu"); check(not guide.expanded, "Route inconnue sans aide automatique inventée")
	guide.profile.data.seen.append("centre")
	guide.profile.data.enabled = false; consider("Bureau"); check(not guide.expanded, "Désactivation respectée"); guide.profile.data.enabled = true
	guide.open_tour(); var tour_text: String = guide.bubble.text; consider("Finances")
	check(guide.mode == "tour" and guide.bubble.text == tour_text, "Visite manuelle non interrompue"); guide.close()
	# Facts are isolated read-only model projections, never written to the engine.
	var facts: Dictionary = app.model.duplicate(true)
	facts.finance.cash = 100; facts.finance.forecast = -1000000; consider("Finances", facts)
	check(not guide.expanded, "Prévision négative sans solde négatif : pas de fausse alerte")
	facts.meta.negotiation = {"status":"counter","playerId":"p0-1-1"}; consider("Recrutement",facts,"recruit")
	check(not guide.expanded, "Contre-offre non présentée comme une signature")
	facts.meta.negotiation.status = "signed"; consider("Recrutement",facts,"recruit",false)
	check(not guide.expanded, "Réponse échouée non présentée comme une signature")
	var dialog := ConfirmationDialog.new(); app.add_child(dialog); dialog.popup_centered()
	consider("Recrutement",facts,"recruit")
	check(not guide.expanded, "Confirmation jamais masquée")
	dialog.hide(); dialog.queue_free(); await process_frame
	consider("Recrutement",facts)
	check(guide.expanded and guide.fragment_id == "decision-contrat", "Signature vraie délivrée après fermeture de la notice"); guide.close(); consider("Recrutement",facts,"recruit")
	check(not guide.expanded, "Signature unique sur le même contexte")
	check(Content.fragments("recrutement").all(func(part): return part.id != "decision-contrat"), "Aide manuelle sans annonce de signature hors contexte")
	facts.finance.cash = -1; consider("Finances",facts)
	check(guide.expanded and guide.fragment_id == "decision-tresorerie", "Solde réellement négatif détecté"); guide.close(); consider("Finances",facts)
	check(not guide.expanded, "Alerte solde unique sur le contexte borné")
	facts.finance.cash = 1
	consider("Bureau",facts,"next_season",false); check(not guide.expanded, "Passage de saison refusé silencieux")
	facts.meta.season += 1; facts.meta.week = 0; consider("Bureau",facts,"next_season")
	check(guide.expanded and guide.fragment_id == "decision-saison", "Réponse réussie au passage de saison")
	guide.close(); consider("Bureau",facts,"next_season"); check(not guide.expanded, "Passage de saison unique")
	guide.destroy(); await process_frame; attach()
	# A new season creates a different event context; reloading the original
	# same context must not repeat its contract or cash warning.
	facts.meta.season -= 1; consider("Recrutement",facts,"recruit")
	check(not guide.expanded, "Signature déjà vue persistée après redémarrage")
	# Fresh screen guard checks must leave its visit available until safe.
	guide.profile.data.seen.erase("centre")
	app.waiting = true; consider("Centre"); check(not guide.expanded and "centre" not in guide.profile.data.seen, "Attente ne consomme pas une visite"); app.waiting = false
	app.last_error = "Erreur UI"; consider("Centre"); check(not guide.expanded and "centre" not in guide.profile.data.seen, "Erreur ne consomme pas une visite"); app.last_error = ""
	var confirm_dialog := ConfirmationDialog.new(); app.add_child(confirm_dialog); confirm_dialog.popup_centered(); consider("Centre")
	check(not guide.expanded and "centre" not in guide.profile.data.seen, "Confirmation conserve une première visite en attente")
	confirm_dialog.hide(); confirm_dialog.queue_free(); await process_frame
	consider("Centre"); check(guide.expanded and guide.current_id == "centre", "Première visite disponible après confirmation"); guide.close()
	app.waiting = true; facts.meta.week += 1; consider("Finances",facts); check(not guide.expanded, "Attente moteur respectée"); app.waiting = false
	app.last_error = "Erreur UI"; consider("Finances",facts); check(not guide.expanded, "Erreur UI respectée"); app.last_error = ""
	var original_live: Variant = app.model.live; app.model.live = {"paused":false,"finished":false}; consider("Finances",facts)
	check(not guide.expanded, "Direct non pausé silencieux"); app.model.live = original_live
	# Write failure remains visible and consumes a visit for this session only.
	var blocker: String = app._profile_path().path_join("guide-blocker")
	var file := FileAccess.open(blocker,FileAccess.WRITE); file.store_string("obstacle"); file.close()
	guide.profile.directory = blocker; guide.profile.data.seen.erase("bureau"); consider("Bureau")
	check(guide.expanded and not guide.profile.last_error.is_empty() and guide._error.visible, "Échec d'écriture visible et conseil disponible")
	guide.close(); for i in 5: consider("Bureau")
	check(not guide.expanded and FileAccess.get_file_as_string(blocker) == "obstacle", "Échec d'écriture : aucun spam ni repli silencieux")
	profiles()
	await command("export")
	check(export_before == JSON.parse_string(app.model.meta.exportText).state, "Export carrière et RNG inchangés")
	check(disk_before == FileAccess.get_file_as_bytes(disk_path), "Sauvegarde S inchangée octet pour octet")
	# A real worker response proves that a successful command is insufficient:
	# only the returned signed status is eligible, after the real notice closes.
	guide.profile.directory = app._profile_path().path_join("real-signature")
	var candidate: Dictionary = app.model.market.filter(func(p): return p.available)[0]
	await command("recruit",{"playerId":candidate.id,"salary":100000,"years":1,"confirmed":true})
	check(app.model.meta.negotiation.status == "signed", "Signature confirmée par le moteur réel")
	consider("Recrutement",app.model,"recruit")
	check(not guide.expanded, "Réponse joueur réelle prioritaire sur le coach")
	for child in app.get_children():
		if child is AcceptDialog: child.hide(); child.queue_free()
	await process_frame
	consider("Recrutement")
	check(guide.expanded and guide.fragment_id == "decision-contrat", "Vraie signature annoncée après notice")
	await finish()
func finish() -> void:
	if is_instance_valid(guide): guide.destroy(); await process_frame
	app.bridge.stop()
	var until := Time.get_ticks_msec() + 4000
	while app.bridge.child_pid > 0 and Time.get_ticks_msec() < until: await process_frame
	app.queue_free(); for i in 5: await process_frame
	print("GABI CONTEXTE : ", checks, " contrôles ; ", failures.size(), " échec(s)")
	quit(0 if failures.is_empty() else 1)
