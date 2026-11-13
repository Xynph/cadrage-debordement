'use strict';
process.env.CD_MODES_HERITES='1'; // Anciens modes de carrière (non-Monde) : test à migrer vers le mode Monde.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process'),{createBridge}=require('../native/engine/worker.cjs');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;if(!godot){console.log('SKIP native-press-personalities-ui.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE) ; réception native non exécutée.');process.exit(0);}
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-press-personalities-ui-')),b=createBridge({dataDir:root,seed:13,now:1700000000000});let i=0;
function good(command,payload={}){const r=b.handle({id:++i,command,payload});assert.equal(r.ok,true,r.error);return r.model;}
try{let m=good('new_career',{mode:'common',club:0}),p=m.clubLife.press;m=good('press_conference',{context:p.context,answers:p.conference.questions.map(q=>({questionId:q.id,answerId:'r1'}))});fs.writeFileSync(path.join(root,'model.json'),JSON.stringify(m));}finally{b.close();}
const script=path.join(root,'people.gd');fs.writeFileSync(script,`extends SceneTree
var checks := 0
var failures: Array[String] = []
class App extends Control:
 var model: Dictionary
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures.append(message); printerr(message)
func settle() -> void:
 for i in 10: await process_frame
func run() -> void:
 var app := App.new()
 app.model = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_PRESS_UI_ROOT").path_join("model.json")))
 root.add_child(app); app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var surface := PanelContainer.new(); app.add_child(surface); surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 surface.theme = load("res://theme.gd").paper()
 var background := StyleBoxFlat.new(); background.bg_color = Color("f3eddf"); surface.add_theme_stylebox_override("panel",background)
 var margin := MarginContainer.new(); surface.add_child(margin)
 for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_" + edge, 20)
 var page: Control = load("res://ui/press_people_view.gd").build(app)
 margin.add_child(page)
 for dimensions in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
  root.size = dimensions; root.content_scale_size = dimensions; await settle()
  var chooser: OptionButton = page.find_child("PressPersonPicker",true,false)
  check(chooser != null and chooser.item_count == 30,"30 identités visibles au carnet")
  check(chooser.size.y >= 44 and chooser.size.x <= dimensions.x - 35,"Sélection lisible et contenue")
  var detail: Control = page.find_child("PressPeopleMemory",true,false)
  check(detail.get_parent().size.y >= 250,"Mémoire accessible sur la hauteur disponible")
  for index in [0,7,10,29]:
   chooser.select(index); chooser.item_selected.emit(index); await settle()
   check(detail.get_child_count() > 5,"Fiche référencée ou fictive accessible")
  for index in app.model.clubLife.press.people.size():
   if app.model.clubLife.press.people[index].encounters > 0: chooser.select(index); chooser.item_selected.emit(index); break
  chooser.grab_focus(); await settle()
  check(chooser.has_focus(),"Catalogue accessible au clavier")
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OS.get_environment("CD_PRESS_UI_ROOT").path_join("relations-" + str(dimensions.x) + ".png"))
 print("Personnalités UI : ",checks," contrôles ; ",failures.size()," échec(s)")
 quit(0 if failures.is_empty() else 1)
`);
const r=spawnSync(godot,[...(process.env.CD_PRESS_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',script],{encoding:'utf8',windowsHide:true,timeout:60000,env:{...process.env,CD_PRESS_UI_ROOT:root}});const log=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),log);console.log(log);console.log('Preuves : '+root);if(r.error)throw r.error;assert.equal(r.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
