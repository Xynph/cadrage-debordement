extends SceneTree
## Comparateur de joueurs : logique pure de sélection et d’écarts (aucun moteur, aucun écran).
## Captures (rendu graphique, carrière Monde importée) : CD_COMPARATEUR_CAPTURE=<dossier> et CD_COMPARATEUR_SAUVEGARDE=<export>.
## Sans ces variables, rien ne change : suite logique seule, exécutable en headless.
const Comparison = preload("res://ui/immersive08/recruitment_comparison.gd")
var checks := 0
var failures := 0
var app: Control
var capture_dir := OS.get_environment("CD_COMPARATEUR_CAPTURE")
const LONG_NAME := "Jean-Baptiste Montmorency-Delacroix de Villeneuve-Saint-Étienne"
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;printerr("FAIL: ",message)
func person(id: String,pos: String,rating: float,extra: Dictionary={}) -> Dictionary:
	var result:={"id":id,"name":"Joueur "+id,"pos":pos,"rating":rating,"condition":80,"age":25,"salary":1000}
	result.merge(extra,true)
	return result
func _initialize() -> void:
	var squad:=[person("s1","Talonneur",70),person("s2","Talonneur",78),person("s3","Pilier",74)]
	var market:=[person("m1","Talonneur",90),person("s2","Talonneur",78)]
	var pool:=Comparison.pool({"squad":squad,"market":market})
	check(pool.size()==4,"Réserve : effectif puis marché, sans doublon")
	check(str(pool[0].id)=="s1" and str(pool[3].id)=="m1","Réserve : mon effectif passe d’abord")
	var own:=["s1","s2","s3"]
	var ids:=Comparison.initial_ids(pool,"m1",[],own)
	check(ids[0]=="m1" and ids[1]=="s2","Second choix par défaut : le meilleur de mon effectif au même poste")
	ids=Comparison.initial_ids(pool,"s3",[],own)
	check(ids[0]=="s3" and ids[1]!="s3" and ids[1]!="","Second choix : jamais le même joueur")
	ids=Comparison.initial_ids(pool,"",["s1","s3"],own)
	check(ids[0]=="s1" and ids[1]=="s3","Mémoire A/B respectée quand elle est complète")
	ids=Comparison.initial_ids(pool,"m1",["s1","s3"],own)
	check(ids[0]=="m1" and ids[1]=="s2","Mémoire d’un autre premier joueur ignorée")
	var a:=person("a","Talonneur",70,{"__own":true,"condition":90,"age":30,"salary":500})
	var b:=person("b","Talonneur",70,{"__own":true,"condition":70,"age":22,"salary":2000})
	check(Comparison.leader("condition",[a,b])==0,"Meilleure condition : A en tête")
	check(Comparison.leader("condition",[b,a])==1,"Meilleure condition : B en tête")
	check(Comparison.leader("age",[a,b])==-1 and Comparison.leader("salary",[a,b])==-1,"Âge et salaire ne sont jamais un avantage à eux seuls")
	b.condition=90
	check(Comparison.leader("condition",[a,b])==-1,"Égalité : aucun écart mis en évidence")
	b.erase("condition")
	check(Comparison.leader("condition",[a,b])==-1,"Valeur inconnue : aucun écart mis en évidence")
	var x:=person("x","Talonneur",99,{"ratingRange":{"min":70,"max":78},"knowledge":{"owned":false,"stage":"observed"}})
	var y:=person("y","Talonneur",99,{"ratingRange":{"min":74,"max":82},"knowledge":{"owned":false,"stage":"observed"}})
	check(Comparison.leader("rating",[x,y])==-1,"Fourchettes qui se chevauchent : pas de vainqueur")
	y.ratingRange={"min":80,"max":86}
	check(Comparison.leader("rating",[x,y])==1,"Fourchettes disjointes : le mieux classé est désigné")
	print("COMPARATEUR JOUEURS : %d contrôles ; %d échecs" % [checks,failures])
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless":
		quit(0 if failures==0 else 1)
		return
	run_captures.call_deferred()

# ---- Captures : vrai jeu, carrière Monde importée ------------------------------------------------------------------

func settle(frames: int = 12) -> void:
	await create_timer(.4).timeout
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw

func wait_engine() -> void:
	var deadline := Time.get_ticks_msec() + 180000
	while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	check(not app.waiting and app.bridge.last_response_ok,"Vraie réponse du moteur : "+str(app.last_error))
	await settle()

func capture(name: String) -> void:
	await settle(16)
	check(root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))==OK,"Capture "+name)

func close_dialogs() -> void:
	app._clear_dialogs()
	await settle(6)

## Nombre de valeurs mises en vert (« meilleur des deux ») dans le comparateur ouvert.
func green_count() -> int:
	var dialog := app.find_child("MarketComparison",true,false)
	var total := 0
	if dialog==null: return 0
	for node: Node in dialog.find_children("*","Label",true,false):
		if node.is_visible_in_tree() and node.has_theme_color_override("font_color") and node.get_theme_color("font_color")==preload("res://ui/immersive08/components.gd").MINT: total+=1
	return total

func long_name_fits(label: String) -> void:
	var dialog := app.find_child("MarketComparison",true,false)
	check(dialog!=null,label+" : comparateur ouvert")
	if dialog==null: return
	for slot in 2:
		var card := dialog.find_child("MarketComparisonCard"+str(slot),true,false) as Control
		check(card!=null and card.is_visible_in_tree(),label+" : fiche "+["A","B"][slot]+" visible")
	print("DIAG ",label," : fenêtre=",root.size," vert=",green_count())

func open_squad_comparison(own_ids: Array) -> void:
	app.management_ui.compare=own_ids.duplicate()
	app._navigate("Effectif")
	await settle(24)
	var button := app.find_child("OpenComparison",true,false) as Button
	check(button!=null and not button.disabled,"Bouton COMPARER de l’Effectif")
	if button!=null: button.pressed.emit()
	await settle(24)

func run_captures() -> void:
	create_timer(900.0).timeout.connect(func():
		printerr("FAIL: délai dépassé (900 s)")
		quit(1))
	DirAccess.make_dir_recursive_absolute(capture_dir)
	root.size=Vector2i(1920,1080)
	DisplayServer.window_set_size(root.size)
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	await wait_engine()
	app.timer.stop()
	app._command("import",{"text":FileAccess.get_file_as_string(OS.get_environment("CD_COMPARATEUR_SAUVEGARDE"))})
	await wait_engine()
	app.timer.stop()
	check(app.model.get("club") is Dictionary and str(app.model.get("meta",{}).get("mode"))=="world","Carrière Monde importée")
	var squad: Array = app.model.get("squad",[])
	var market: Array = app.model.get("market",[])
	check(squad.size()>=2 and market.size()>=1,"Effectif (%d) et marché (%d) présents" % [squad.size(),market.size()])
	if squad.size()<2 or market.is_empty():
		finish()
		return
	# Mon joueur : le mieux classé de l’effectif ; joueur du marché : un poste que mon effectif occupe, noms longs des deux.
	var mine: Dictionary = squad[0]
	for player: Dictionary in squad:
		if float(player.get("rating",0))>float(mine.get("rating",0)): mine=player
	var other: Dictionary = squad[1] if str(squad[1].id)!=str(mine.id) else squad[0]
	var target: Dictionary = market[0]
	for player: Dictionary in market:
		if str(player.get("pos",""))==str(mine.get("pos","")) and float(player.get("rating",0))>=float(target.get("rating",0)): target=player
	mine["name"]=LONG_NAME
	target["name"]=LONG_NAME+" II"
	for size: Vector2i in [Vector2i(2560,1440),Vector2i(1280,720)]:
		root.size=size
		DisplayServer.window_set_size(size)
		await settle(24)
		var tag := "%dp" % size.y
		# 1. Depuis l’Effectif : deux joueurs de mon effectif, bouton COMPARER.
		await open_squad_comparison([str(mine.id),str(other.id)])
		long_name_fits("Effectif "+tag)
		await capture("comparateur-effectif-"+tag)
		await close_dialogs()
		# 2. Depuis la fiche joueur : bouton « Comparer » de la fiche complète (le premier joueur est mémorisé).
		app.management_ui.compare=[]
		app._navigate("Effectif")
		await settle(24)
		app.selected_player=str(mine.id)
		app.management_ui.immersive_player_tab=0
		app.set_meta("immersive08_full_player",true)
		app._render()
		await settle(30)
		var compare := app.find_child("FullPlayerCompare",true,false) as Button
		check(compare!=null,"Bouton Comparer de la fiche joueur "+tag)
		if compare!=null: compare.pressed.emit()
		await settle(24)
		long_name_fits("Fiche joueur "+tag)
		await capture("comparateur-fiche-"+tag)
		await close_dialogs()
		app.set_meta("immersive08_full_player",false)
		# 3. Joueur du marché contre mon joueur (entrée du Recrutement : premier choix = le joueur du marché).
		app.management_ui.compare=[]
		app._navigate("Recrutement")
		await settle(24)
		preload("res://ui/immersive08/recruitment_comparison.gd").open(app,str(target.id),{})
		await settle(24)
		long_name_fits("Marché contre effectif "+tag)
		await capture("comparateur-marche-"+tag)
		await close_dialogs()
	finish()

func finish() -> void:
	print("COMPARATEUR CAPTURES : %d contrôles ; %d échecs" % [checks,failures])
	app.closing=true
	app.bridge.stop()
	quit(0 if failures==0 else 1)
