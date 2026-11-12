'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const exe=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;if(!exe){console.log('SKIP native-academy-ui.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE) ; réception native non exécutée.');process.exit(0);}const folder=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'native-academy-ui-')),script=path.join(folder,'academy-ui.gd');
fs.writeFileSync(script,`extends SceneTree
var app: Control
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
 call_deferred("run")
func check(value:bool,label:String) -> void:
 checks += 1
 if not value: failures.append(label); printerr("FAIL " + label)
func named(node:Node,id:String) -> Node:
 if str(node.name)==id: return node
 for child in node.get_children():
  var found:=named(child,id)
  if found!=null: return found
 return null
func settle() -> void:
 for frame in 5: await process_frame
func response() -> void:
 var until:=Time.get_ticks_msec()+30000
 while app.waiting and Time.get_ticks_msec()<until: await process_frame
 check(not app.waiting and app.bridge.last_response_ok,"Commande réelle terminée · "+str(app.last_error))
 await settle()
func command(id:String,payload:Dictionary={}) -> void:
 app._command(id,payload)
 await response()
func enter(control:Control) -> void:
 check(control!=null,"Contrôle présent")
 if control==null: return
 control.grab_focus()
 await settle()
 check(control.has_focus(),"Focus clavier")
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
 var image:=root.get_texture().get_image()
 check(image.save_png(OS.get_environment("CD_ACADEMY_CAPTURE").path_join(name+".png"))==OK,"Capture "+name)
func run() -> void:
 app=load("res://main.tscn").instantiate()
 root.add_child(app)
 while app.model.is_empty():await process_frame
 app.timer.stop()
 await command("new_career",{"mode":"common","club":29})
 # Une carrière neuve ouvre d'abord son rendez-vous de direction : le moteur refuse toute dépense tant qu'il n'est pas traité.
 await preload("res://qa_runner.gd").settle_club_meetings(app,self,check)
 app._navigate("Centre");await settle()
 await enter(named(app,"academy_activate_action"));await confirm()
 check(app.model.clubLife.academyPathways.active,"Activation depuis le vrai bouton")
 var cash:float=app.model.clubLife.academyPathways.cash
 await enter(named(app,"academy_scout_action"));await confirm()
 check(app.model.clubLife.academyPathways.cash==cash-35000,"Détection débitée de35000 après confirmation")
 check(named(app,"academy_scout_action").disabled,"Double détection désactivée")
 var tabs:TabContainer=named(app,"AcademyTabs")
 check(tabs.get_tab_count()==6,"Six onglets utilisables")
 tabs.current_tab=1;await settle()
 var filter:OptionButton=named(app,"AcademyFilter")
 filter.select(1);filter.item_selected.emit(1);await settle()
 check(named(app,"AcademyFilter")==filter,"Filtre local sans requête")
 for resolution in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
  root.size=resolution
  if DisplayServer.get_name()!="headless":DisplayServer.window_set_size(resolution)
  app._navigate("Centre");await settle()
  tabs=named(app,"AcademyTabs")
  for tab in 6:
   tabs.current_tab=tab;await settle()
   var page:Control=named(app,"CarnetAcademyPathways")
   check(page.get_global_rect().end.x<=app.size.x+1 and page.get_global_rect().end.y<=app.size.y+1,"Bornes "+str(resolution)+" onglet"+str(tab))
   await capture("centre-"+str(resolution.x)+"-"+str(tab))
 await command("export")
 var saved:String=app.model.meta.exportText
 app._navigate("Centre");await settle()
 await command("export")
 check(app.model.meta.exportText==saved,"Consultations sans mutation de carrière")
 print("ACADEMY UI: ",checks," checks, ",failures.size()," failures")
 app.bridge.stop()
 quit(0 if failures.is_empty() else 1)
`);
const result=spawnSync(exe,[...(process.env.CD_ACADEMY_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',script],{encoding:'utf8',windowsHide:true,timeout:180000,env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:path.join(folder,'profile'),CD_ACADEMY_CAPTURE:folder}});const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(folder,'godot.log'),output);console.log(output);console.log('Recette UI : '+folder);if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
