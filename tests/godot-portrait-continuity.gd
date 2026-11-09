extends SceneTree
const Portrait = preload("res://ui/regen_portrait.gd")
const Training = preload("res://ui/immersive08/training_canvas.gd")
const Recruitment = preload("res://ui/immersive08/recruitment_canvas.gd")
var app: Control
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL: "+message)
func settle() -> void:
	for i in 10:await process_frame
func response(id: String) -> void:
	var deadline:=Time.get_ticks_msec()+30000
	while (app.model.is_empty() or app.waiting) and Time.get_ticks_msec()<deadline:await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Vrai worker : "+id);await settle()
func command(id: String,payload: Dictionary={}) -> void:
	app._command(id,payload);await response(id)
func run() -> void:
	root.size=Vector2i(1920,1080);app=load("res://main.tscn").instantiate();root.add_child(app)
	await response("snapshot initial");await command("new_career",{"mode":"common","club":0})
	var source: Dictionary={}
	for person: Dictionary in app.model.decisions.development.academy:
		var profile:=Portrait.describe(person)
		if person.get("appearanceBankVersion")==2 and ResourceLoader.exists(str(profile.get("assetPath",""))):
			if source.is_empty() or profile.cell>=32:source=person
			if profile.cell>=32:break
	check(not source.is_empty(),"Vrai académicien banque2 disponible")
	if source.is_empty():await finish();return
	var original:=Portrait.describe(source)
	await command("promote_academy",{"playerId":source.id,"confirmed":true})
	var promoted: Dictionary=app.model.squad.filter(func(p):return p.id==source.id)[0]
	check(Portrait.describe(promoted)==original,"Promotion réelle conserve banque/base/variantes")
	var slots: Array=app.model.selection.slots.filter(func(s):return int(s.slot)<15 and source.id in s.eligibleIds)
	check(not slots.is_empty(),"Poste réellement éligible pour le joueur promu")
	if not slots.is_empty():await command("set_lineup",{"slot":int(slots[0].slot),"playerId":source.id})
	await command("export");var before: String=app.model.meta.exportText
	var save: String=str(app.model.meta.dataDir).path_join("donnees.json");var bytes:=FileAccess.get_file_as_bytes(save)
	app.selected_player=str(promoted.id);app.management_ui.roster.search=str(promoted.name);app._navigate("Effectif");await settle()
	var row: Node=app.body.find_child("SquadPlayer"+str(promoted.id).replace(":","_"),true,false)
	check(row!=null,"Vraie ligne du joueur promu présente")
	if row!=null:
		var images: Array=row.find_children("*","TextureRect",true,false)
		check(images.size()>0 and images[0].texture==Portrait.texture(promoted) and images[0].material==Portrait.material(promoted),"Petite vignette utilise même banque/base/variantes")
	var large:=false
	for image: TextureRect in app.body.find_children("*","TextureRect",true,false):
		if image.size.x>100 and image.texture==Portrait.texture(promoted) and image.material==Portrait.material(promoted):large=true
	check(large,"Grand dossier utilise le même portrait")
	app.set_meta("immersive08_full_player",true);app._render();await settle()
	var full: Node=app.body.find_child("FullPlayerHero",true,false)
	check(full!=null,"Fiche pleine page réelle ouverte")
	if full!=null:
		var images: Array=full.find_children("*","TextureRect",true,false)
		check(images.size()>0 and images[0].texture==Portrait.texture(promoted) and images[0].material==Portrait.material(promoted),"Fiche pleine page conserve banque/base/variantes")
	app.set_meta("immersive08_full_player",false);app._render();await settle()
	if not slots.is_empty():
		app.selected_slot=int(slots[0].slot);app._navigate("Composition");await settle()
		check(has_portrait(app.body,promoted),"Composition utilise le même portrait du vrai joueur")
	var market: Array=app.model.market.duplicate();market.sort_custom(func(a: Dictionary,b: Dictionary):return float(a.rating)>float(b.rating))
	check(not market.is_empty(),"Vrai marché disponible")
	if not market.is_empty():
		app._navigate("Bureau");await settle()
		check(has_portrait(app.body,market[0]),"Piste réelle du bureau conserve sa banque")
		for full_size in [false,true]:
			var parent:=Control.new();root.add_child(parent)
			Recruitment._portrait(parent,Rect2(0,0,80,80),market[0],str(market[0].id),full_size)
			check(has_portrait(parent,market[0]),"Recrutement petite/grande image conserve sa banque")
			parent.queue_free();await settle()
	var helper:=Training.new();helper.app=app
	for packed in [false,true]:
		var parent:=Control.new();root.add_child(parent);var p:=promoted.duplicate(true)
		if packed:p.identity={"portraitPath":ProjectSettings.globalize_path("res://art/regen-staff-atlas.png"),"portraitStatus":"official"}
		helper._portrait(parent,p,Rect2(0,0,80,80))
		var images:=parent.find_children("*","TextureRect",true,false)
		check(images.size()>0 and (images[0].material==null if packed else images[0].texture==Portrait.texture(promoted) and images[0].material==Portrait.material(promoted)),"Entraînement : priorité pack ou même composition locale")
		parent.queue_free();await settle()
	helper.free()
	app._navigate("Effectif");await settle()
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw;check(root.get_texture().get_image().save_png(OS.get_environment("CD_REGEN_UI_OUTPUT").path_join("squad-bank2.png"))==OK,"Capture petite/grande vignette")
	await command("export");check(app.model.meta.exportText==before and FileAccess.get_file_as_bytes(save)==bytes,"Consultation sans mutation/RNG/disque")
	app.bridge.stop()
	var until:=Time.get_ticks_msec()+5000
	while app.bridge.child_pid>0 and Time.get_ticks_msec()<until:await process_frame
	check(app.bridge.child_pid==-1,"Ancien worker fermé avant reprise")
	app.queue_free();await process_frame
	app=load("res://main.tscn").instantiate();root.add_child(app);await response("réouverture profil")
	var reopened: Dictionary=app.model.squad.filter(func(p):return p.id==source.id)[0]
	check(Portrait.describe(reopened)==original,"Reprise réelle conserve exactement l’apparence")
	print("Banque/base réellement reçue : ",original.baseId)
	await command("new_career",{"mode":"fiction","club":0})
	app._navigate("Préparation");await settle()
	var threats: Array=app.model.decisions.preparation.threats
	check(not threats.is_empty(),"Vrais joueurs adverses projetés")
	var threat_panel: Node=app.body.find_child("PreparationThreats",true,false)
	check(threat_panel!=null,"Panneau adverse réellement visible")
	if threat_panel!=null:
		for threat: Dictionary in threats:
			check(threat.get("appearanceBankVersion")==2,"Version du vrai nouveau joueur adverse transmise")
			check(has_portrait(threat_panel,threat),"Adversaire identifié garde banque/base/variantes")
	await finish()
func has_portrait(parent: Node,person: Dictionary) -> bool:
	var texture:=Portrait.texture(person);var material:=Portrait.material(person)
	if texture==null:return false
	for image: TextureRect in parent.find_children("*","TextureRect",true,false):
		if image.texture==texture and image.material==material:return true
	return false
func finish() -> void:
	print(JSON.stringify({"checks":checks,"failures":failures}))
	app.queue_free();await process_frame
	# AudioStreamPlayback is released by the mix thread after the scene exits.
	# Give the real guide player teardown one audio buffer before ending Godot.
	await create_timer(0.15).timeout
	quit(0 if failures.is_empty() else 1)
