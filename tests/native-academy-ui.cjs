'use strict';
// Réception native du Centre de formation (carrière Monde, vrai Godot + vrai moteur) : activation des parcours par le
// vrai bouton, puis les pages façon Effectif (choix de Léo du 22/11/2026) au clavier et à la souris : détection payée
// après confirmation puis « Faite », six onglets, filtre de trajectoire local (aucune requête), tri par en-tête,
// parcours individuel en petite fenêtre (charge et réponse à l'ambition gardées en aplat) fermée par Échap, page entière en 1280 × 720, 1600 × 900 et 1920 × 1080,
// consultations sans mutation de carrière. Captures : CD_ACADEMY_GRAPHICS=1.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const M=require('./helpers/carriere-monde.cjs');
const exe=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;if(!exe){console.log('SKIP native-academy-ui.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE) ; réception native non exécutée.');process.exit(0);}
const folder=fs.mkdtempSync(path.join(os.tmpdir(),'native-academy-ui-')),script=path.join(folder,'academy-ui.gd'),profil=path.join(folder,'profile');
fs.mkdirSync(profil,{recursive:true});
{const jeu=M.ouvrir({dataDir:profil,mandatoryPress:false});try{M.creer(jeu,5);jeu.call('save');}finally{jeu.fermer();}}
fs.writeFileSync(script,`extends SceneTree
var app: Control
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
 call_deferred("run")
func check(value:bool,label:String) -> void:
 checks += 1
 if not value: failures.append(label); printerr("FAIL " + label)
func named(id:String) -> Node:
 return app.find_child(id,true,false)
func settle() -> void:
 for frame in 8: await process_frame
func response() -> void:
 var until:=Time.get_ticks_msec()+60000
 while app.waiting and Time.get_ticks_msec()<until: await process_frame
 check(not app.waiting and app.bridge.last_response_ok,"Commande réelle terminée · "+str(app.last_error))
 await settle()
func enter(control:Control) -> void:
 check(control!=null,"Contrôle présent")
 if control==null: return
 control.grab_focus()
 await settle()
 check(control.has_focus(),"Focus clavier · "+str(control.name))
 for down in [true,false]:
  var event:=InputEventKey.new()
  event.keycode=KEY_ENTER;event.pressed=down
  Input.parse_input_event(event)
  await process_frame
 await settle()
func confirm() -> void:
 var dialog:ConfirmationDialog=null
 for child in app.get_children():
  if child is ConfirmationDialog and child.visible: dialog=child
 check(dialog!=null,"Confirmation de dépense visible")
 if dialog!=null: await enter(dialog.get_ok_button());await response()
func capture(name:String) -> void:
 if DisplayServer.get_name()=="headless":return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OS.get_environment("CD_ACADEMY_CAPTURE").path_join(name+".png"))==OK,"Capture "+name)
func tab(nom:String) -> void:
 await enter(named("CentreOnglet_"+nom.validate_node_name()) as Control)
 var page:=named("CentreVisuel") as Control
 check(page!=null and str(page.get_meta("onglet",""))==nom,"Onglet "+nom+" ouvert au clavier")
func run() -> void:
 # Pages riches du Centre dès 1280 × 720 (sous ce seuil, la coque garde son repli compact commun).
 root.size=Vector2i(1280,720)
 if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(root.size)
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 var until:=Time.get_ticks_msec()+120000
 while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec()<until: await process_frame
 app.timer.stop()
 await preload("res://qa_runner.gd").settle_club_meetings(app,self,check)
 app._navigate("Centre");await settle()
 check(named("CentreVisuel")==null,"Parcours inactifs : pas encore les pages du Centre")
 await enter(named("academy_activate_action") as Control);await confirm()
 check(app.model.clubLife.academyPathways.active,"Activation depuis le vrai bouton")
 app._navigate("Centre");await settle()
 check(named("CentreVisuel")!=null and named("CentreHero")==null,"Pages du Centre en pleine largeur, sans héros")
 for t in ["Cohesion","Reputation","Enveloppe","Places"]: check(named("CentreTuile"+t)!=null,"Tuile chiffre "+t)
 var ap:Dictionary=app.model.clubLife.academyPathways
 var cash:float=ap.cash
 var scout:int=int(ap.costs.scout)
 await enter(named("CentreDetectionLancer") as Control);await confirm()
 check(app.model.clubLife.academyPathways.cash==cash-scout,"Détection débitée de son prix indexé après confirmation")
 check(named("CentreDetectionLancer")==null and named("CentreDetectionFaite")!=null,"Détection affichée « Faite », plus de bouton")
 await tab("Parcours")
 var joueurs:Array=app.model.clubLife.academyPathways.players
 await command_free(func(): await enter(named("CentreFiltreTrajectoire_minutes") as Control))
 var lignes:=(named("CentreParcoursListeLignes") as Node).get_children().filter(func(n:Node): return n is Button)
 check(lignes.size()==joueurs.filter(func(p:Dictionary): return str(p.path)=="minutes").size(),"Filtre de trajectoire local : %d lignes" % lignes.size())
 await command_free(func(): await enter(named("CentreFiltreTrajectoire_") as Control))
 await enter(named("CentreParcoursListeTri_age") as Control)
 var ages:Array=(named("CentreParcoursListeLignes") as Node).get_children().filter(func(n:Node): return n is Button).map(func(b:Button): return int(b.get_meta("element").age))
 check(ages.size()==joueurs.size(),"Toutes les lignes après retrait du filtre")
 # Lignes regroupées par étape d'âge (17 et moins, 18-19, 20 et plus) : âges décroissants dans chaque étape.
 var tries:=true
 for i in ages.size()-1:
  var meme:bool=(0 if ages[i]<=17 else (1 if ages[i]<=19 else 2))==(0 if ages[i+1]<=17 else (1 if ages[i+1]<=19 else 2))
  if meme and ages[i]<ages[i+1]: tries=false
 check(tries,"Tri par l'en-tête Âge, décroissant dans chaque étape")
 await enter(named("CentreVisuelJoueur0") as Control)
 check(named("CentreVisuelParcours")!=null and (named("CentreVisuelParcours") as Control).is_visible_in_tree(),"Parcours individuel en petite fenêtre")
 # Charge de travail et réponse à l'ambition : le choix gardé par le moteur reste en aplat quand la fenêtre se rouvre.
 check(choisi("CVCharge_equilibree"),"Charge par défaut en aplat : équilibrée")
 await enter(named("CVCharge_intensive") as Control);await response()
 check(choisi("CVCharge_intensive") and not choisi("CVCharge_equilibree"),"Charge intensive en aplat après le choix")
 check(not choisi("CVAmbition_patienter"),"Ambition sans réponse au départ")
 await enter(named("CVAmbition_patienter") as Control);await response()
 check(choisi("CVAmbition_patienter"),"Réponse à l'ambition en aplat")
 check(named("CVAmbition_accompagner") is Button and (named("CVAmbition_accompagner") as Button).disabled,"Une réponse par saison : les autres se figent")
 check(choisi("CVCharge_intensive"),"Charge toujours en aplat après la réponse à l'ambition")
 var esc:=InputEventKey.new();esc.keycode=KEY_ESCAPE;esc.pressed=true;Input.parse_input_event(esc);await settle()
 var esc2:=InputEventKey.new();esc2.keycode=KEY_ESCAPE;esc2.pressed=false;Input.parse_input_event(esc2);await settle()
 check(named("CentreVisuelParcours")==null or not (named("CentreVisuelParcours") as Control).is_visible_in_tree(),"Échap ferme la petite fenêtre")
 check(app.route=="Centre","Échap ne quitte pas le Centre")
 for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
  root.size=resolution
  if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(resolution)
  app._navigate("Centre");await settle()
  for nom in ["Centre","Parcours","Centres","Filières","Passerelle pro","Générations"]:
   await tab(nom)
   var page:=named("CentreVisuel") as Control
   if page!=null: check(Rect2(Vector2.ZERO,app.size).grow(1).encloses(page.get_global_rect()),"Bornes "+str(resolution)+" onglet "+nom)
   await capture("centre-"+str(resolution.x)+"-"+nom.validate_node_name())
 app._command("export",{});await response()
 var saved:String=app.model.meta.exportText
 app._navigate("Centre");await settle()
 await tab("Centres");await tab("Filières");await tab("Générations")
 app._command("export",{});await response()
 check(app.model.meta.exportText==saved,"Consultations sans mutation de carrière")
 print("ACADEMY UI: ",checks," checks, ",failures.size()," failures")
 app.bridge.stop()
 quit(0 if failures.is_empty() else 1)
## Pastille en aplat (choix actif) de la petite fenêtre du parcours.
func choisi(id:String) -> bool:
 var b:=named(id) as Button
 return b!=null and b.is_visible_in_tree() and str(b.accessibility_name).ends_with("· choisi")
## L'action ne doit envoyer aucune commande au moteur (filtre local).
func command_free(action:Callable) -> void:
 var attente_avant:bool=app.waiting
 await action.call()
 check(not app.waiting and not attente_avant,"Aucune requête envoyée par le filtre")
`);
const result=spawnSync(exe,[...(process.env.CD_ACADEMY_GRAPHICS==='1'?[]:['--headless']),'--audio-driver','Dummy','--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',script],{encoding:'utf8',windowsHide:true,timeout:300000,env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_GUIDE_MODULE_TEST:'1',CD_GODOT_DATA_DIR:profil,CD_ACADEMY_CAPTURE:folder}});const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(folder,'godot.log'),output);console.log(output.slice(-6000));console.log('Recette UI : '+folder);if(result.error)throw result.error;assert.equal(result.status,0,output.slice(-4000));assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error/);assert.match(output,/ACADEMY UI: \d+ checks, 0 failures/);
