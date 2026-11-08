'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
if(!godot){console.log('SKIP native-relationships-ui.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE) ; réception native non exécutée.');process.exit(0);}
const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'native-relationships-ui-')),script=path.join(root,'relations.gd');
fs.writeFileSync(script,`extends SceneTree
var app: Control
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
 checks += 1
 if not value: failures.append(text); printerr("FAIL: ", text)
func named(node: Node, id: String) -> Node:
 if str(node.name) == id: return node
 for child in node.get_children():
  var result := named(child, id)
  if result != null: return result
 return null
func wait_model() -> void:
 var until := Time.get_ticks_msec() + 30000
 while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < until: await process_frame
 check(not app.waiting and not app.model.is_empty(), "Réponse du vrai worker")
 for i in 4: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
 app._command(id, payload)
 await wait_model()
 check(app.bridge.last_response_ok, id + " : " + app.last_error)
func press(id: String) -> void:
 var b: Button = named(app, id)
 check(b != null and not b.disabled, "Contrôle disponible " + id)
 if b == null or b.disabled: return
 b.grab_focus()
 await process_frame
 check(b.has_focus(), "Focus clavier " + id)
 b.pressed.emit()
 await wait_model()
 check(app.bridge.last_response_ok, "Décision réelle " + id + " : " + app.last_error)
func render(route: String) -> void:
 app._navigate(route)
 for i in 5: await process_frame
func capture(id: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OS.get_environment("CD_RELATIONS_CAPTURES").path_join(id + ".png")) == OK, "Capture " + id)
func run() -> void:
 app = load("res://main.tscn").instantiate()
 root.add_child(app)
 await wait_model()
 app.timer.stop()
 await command("new_career", {"mode":"common", "club":29})
 if not failures.is_empty():
  print("RELATIONS UI : démarrage refusé ; contrôles de vues non exécutés")
  app.bridge.stop()
  quit(1)
  return
 for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
  root.size = resolution
  if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
  for route in ["Vestiaire", "Rivalités"]:
   await render(route)
   var page: Control = named(app, "CarnetRelations" if route == "Vestiaire" else "CarnetMonde")
   check(page != null, "Vue composée " + route)
   if page != null:
    check(page.get_global_rect().end.x <= app.size.x + 1 and page.get_global_rect().end.y <= app.size.y + 1, "Bornes " + route + " " + str(resolution))
    for b in page.find_children("*", "Button", true, false):
     if not b.disabled: check(b.focus_mode == Control.FOCUS_ALL and b.size.y >= 40, "Action clavier et taille " + b.name)
   await capture(route + "-" + str(resolution.x))
 await render("Vestiaire")
 var id: String = str(app.model.clubLife.relationships.event.playerId)
 var before: int = int(app.model.clubLife.relationships.players.filter(func(p): return p.id == id)[0].score)
 await press("LockerDecision_ecouter")
 check(app.model.clubLife.relationships.event == null, "Événement soldé dans le vrai état")
 check(int(app.model.clubLife.relationships.players.filter(func(p): return p.id == id)[0].score) == mini(95, before + 4), "Satisfaction réellement modifiée")
 var chooser: OptionButton = named(app, "RelationshipPlayer")
 chooser.select(1)
 chooser.item_selected.emit(1)
 await press("Conversation_rassurer")
 check(named(app, "RelationshipPlayer").selected == 1, "Joueur sélectionné conservé après décision")
 check(named(app, "Conversation_rassurer").disabled, "Entretien bloqué après décision")
 await press("Promise_rotation")
 check(app.model.clubLife.relationships.players[1].promise.target == "rotation", "Promesse réelle du joueur sélectionné")
 await press("DuoAction_duo")
 check(app.model.clubLife.relationships.pairs.size() == 1, "Duo réel")
 await command("auto_lineup")
 await command("begin_match")
 await command("delegate")
 await command("finish_round")
 await render("Rivalités")
 check(app.model.clubLife.clubWorld.events.size() == 15, "Quinze résultats réellement observés")
 for resolution in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
  root.size = resolution
  if DisplayServer.get_name() != "headless": DisplayServer.window_set_size(resolution)
  await render("Rivalités")
  await capture("Rivalités-resultats-" + str(resolution.x))
 print("RELATIONS UI : ", checks, " contrôles ; ", failures.size(), " échec(s)")
 app.bridge.stop()
 quit(0 if failures.is_empty() else 1)
`);
const result=spawnSync(godot,[...(process.env.CD_RELATIONS_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path','native/godot','--script',script],{cwd:path.resolve(__dirname,'..'),env:{...process.env,CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_SELF_TEST:'0',CD_GODOT_DATA_DIR:path.join(root,'profile'),CD_RELATIONS_CAPTURES:root},encoding:'utf8',windowsHide:true,timeout:180000});
const output=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),output);console.log(output.trim());console.log('Preuves UI : '+root);
if(result.error)throw result.error;assert.equal(result.status,0,output);assert.doesNotMatch(output,/SCRIPT ERROR|Parse Error|ERROR:/);
