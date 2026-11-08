'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;if(!godot){console.log('SKIP native-press-ui.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE) ; réception native non exécutée.');process.exit(0);}
const root=fs.mkdtempSync(path.join(process.env.CD_PRESS_TEST_ROOT||require('node:os').tmpdir(),'cd-native-press-ui-')),script=path.join(root,'press-reception.gd');
fs.writeFileSync(script,`extends SceneTree
var app: Control
var failures: Array[String] = []
var checks := 0
func _initialize() -> void:
 call_deferred("run")
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures.append(message); printerr(message)
func settle() -> void:
 for i in 10: await process_frame
func command(id: String, payload: Dictionary = {}) -> void:
 app._command(id, payload)
 var deadline := Time.get_ticks_msec() + 45000
 while (app.waiting or app.model.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
 check(not app.waiting and app.bridge.last_response_ok, "Commande " + id)
 await settle()
func press_space(button: Button) -> void:
 button.grab_focus(); await settle()
 var event := InputEventKey.new(); event.keycode = KEY_SPACE; event.pressed = true; Input.parse_input_event(event); await process_frame
 event = InputEventKey.new(); event.keycode = KEY_SPACE; event.pressed = false; Input.parse_input_event(event); await settle()
func capture(name: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OS.get_environment("CD_PRESS_CAPTURES").path_join(name + ".png")) == OK, "Capture " + name)
func run() -> void:
 root.size = Vector2i(1280, 720)
 app = load("res://main.tscn").instantiate(); root.add_child(app)
 await command("snapshot")
 await command("new_career", {"mode":"common", "club":29})
 await command("export")
 var before: String = app.model.meta.exportText
 var disk: String = str(app.model.meta.dataDir).path_join("donnees.json")
 var bytes := FileAccess.get_file_as_bytes(disk)
 for dimensions in [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080)]:
  root.size = dimensions; root.content_scale_size = dimensions; await settle()
  app._navigate("Presse"); await settle()
  var page: Node = app.body.find_child("CarnetPresse", true, false)
  check(page != null, "Écran Presse natif")
  if page == null: break
  var tabs: TabContainer = page.find_child("PressTabs", true, false)
  check(tabs.size.y >= 250, "Contenu presse réellement visible en hauteur")
  check(tabs.get_tab_count() == 4, "Journal, conférence, historique, relations")
  var division: OptionButton = page.find_child("PressDivision", true, false)
  check(division.item_count == 2 and division.selected == 1, "Deux divisions, Accession sélectionnée")
  division.select(0); division.item_selected.emit(0); await settle()
  await capture("journal-" + str(dimensions.x))
  tabs.current_tab = 1; await settle()
  var submit: Button = page.find_child("PressSubmit", true, false)
  check(submit != null, "Publication présente")
  var questions: Array = app.model.clubLife.press.conference.questions
  check(tabs.get_tab_title(0) == "Journal" and tabs.get_tab_title(1) == "Conférence" and tabs.get_tab_title(2) == "Historique", "Indices historiques conservés")
  for question: Dictionary in questions:
   check(question.answers.size() == 5, "Cinq options réelles")
   var identity: Label = page.find_child("PressIdentity_" + str(question.id),true,false)
   check(identity != null and identity.text.contains(question.journalist.identityLabel), "Identité référencée ou fictive exacte")
   var relation: Label = page.find_child("PressRelation_" + str(question.id),true,false)
   check(relation != null and relation.text.contains(question.relation.label), "Relation personnelle visible")
   for answer: Dictionary in question.answers:
    var control: Button = page.find_child("PressAnswer_" + str(question.id) + "_" + str(answer.id),true,false)
    check(control != null and control.text.contains(answer.toneLabel.to_upper()) and control.text.contains(answer.consequence), "Ton et conséquences lisibles sur chaque option")
   var option: Button = page.find_child("PressAnswer_" + str(question.id) + "_r4", true, false)
   check(option != null and option.custom_minimum_size.y >= 60, "Humour réel espacé")
   if option != null:
    if option.button_pressed: option.button_pressed = false
    await press_space(option)
    check(option.button_pressed and option.has_focus(), "Cinquième réponse sélectionnée au clavier")
    var visible_area: Rect2 = option.get_parent().get_parent().get_parent().get_parent().get_global_rect()
    check(option.get_global_rect().intersection(visible_area).size.y >= option.size.y - 1, "Focus clavier défile vers la cinquième réponse entière")
    check(option.size.x <= tabs.size.x + 2, "Réponse contenue dans la largeur")
  check(not submit.disabled, "Publication active après toutes les réponses")
  await capture("conference-" + str(dimensions.x))
  submit.get_parent().get_parent().scroll_vertical = 0; await settle()
  await capture("conference-start-" + str(dimensions.x))
  tabs.current_tab = 3; await settle()
  var people: OptionButton = page.find_child("PressPersonPicker",true,false)
  check(people != null and people.item_count == 30,"Catalogue30 présent dans le quatrième onglet")
  await capture("relations-" + str(dimensions.x))
  tabs.current_tab = 1; await settle()
  for question: Dictionary in questions: check(page.find_child("PressAnswer_" + str(question.id) + "_r4",true,false).button_pressed,"Choix conservé après visite du carnet")
 await command("export")
 check(app.model.meta.exportText == before and FileAccess.get_file_as_bytes(disk) == bytes, "Navigation presse pure")
 app._navigate("Presse"); await settle()
 var page: Node = app.body.find_child("CarnetPresse", true, false)
 if page != null:
  var tabs: TabContainer = page.find_child("PressTabs", true, false)
  tabs.current_tab = 1
  for question: Dictionary in app.model.clubLife.press.conference.questions:
   var option: Button = page.find_child("PressAnswer_" + str(question.id) + "_r4", true, false)
   check(option.button_pressed,"Brouillon conservé après reconstruction de la page")
  var submit: Button = page.find_child("PressSubmit", true, false)
  submit.pressed.emit()
  var deadline := Time.get_ticks_msec() + 45000
  while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
  await settle()
  check(app.bridge.last_response_ok and not app.model.clubLife.press.conference.available, "Conférence publiée par le vrai contrôle")
  check(app.model.clubLife.press.lastOutcome.delta.morale > 0, "Effet moral réel")
  check(app.model.clubLife.press.history.all(func(row: Dictionary): return row.answerId == "r4"),"Choix clavier Humour réellement enregistré")
  app._navigate("Presse"); await settle()
  tabs = app.body.find_child("PressTabs", true, false)
  tabs.current_tab = 1; await settle(); await capture("resultat")
  check(app.body.find_child("PressRelationshipOutcome",true,false) != null,"Retours individuels visibles après publication")
  tabs.current_tab = 2; await settle(); await capture("historique")
  tabs.current_tab = 3; await settle(); await capture("relations-apres")
 var report := FileAccess.open(OS.get_environment("CD_PRESS_CAPTURES").path_join("report.json"), FileAccess.WRITE)
 report.store_string(JSON.stringify({"checks":checks,"failures":failures},"  ")); report.close()
 app.closing = true; app.timer.stop(); app.bridge.stop()
 var deadline := Time.get_ticks_msec() + 5000
 while app.bridge.child_pid > 0 and Time.get_ticks_msec() < deadline: await process_frame
 app.queue_free(); await settle()
 print("PRESSE UI : ", checks, " contrôles ; ", failures.size(), " échec(s)")
 quit(0 if failures.is_empty() else 1)
`);
const r=spawnSync(godot,[...(process.env.CD_PRESS_GRAPHICS==='1'?[]:['--headless']),'--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',script],{windowsHide:true,encoding:'utf8',timeout:120000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(root,'PrototypeGodot'),CD_PRESS_CAPTURES:root}});
const log=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),log);console.log(log);console.log('Preuves presse : '+root);if(r.error)throw r.error;assert.equal(r.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);

