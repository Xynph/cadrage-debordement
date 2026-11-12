'use strict';
const {settleClubMeetings}=require('./helpers/club-meetings.cjs');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process'),{createBridge}=require('../native/engine/worker.cjs');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;if(!godot){console.log('SKIP native-club-support-ui.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE) ; réception native non exécutée.');process.exit(0);}const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-support-ui-'));
const b=createBridge({dataDir:root,seed:410,now:1700000000000});let n=0;const req=(command,payload={})=>{const r=b.handle({id:++n,command,payload});assert.equal(r.ok,true,r.error);return r.model;};
try{settleClubMeetings(req('new_career',{mode:'common',club:29}),req);const doc=JSON.parse(req('export').meta.exportText),p=doc.state.clubs[29].players[25];p.injury=2;let h=2166136261;for(const c of JSON.stringify(doc.state))h=Math.imul(h^c.charCodeAt(0),16777619);doc.checksum=(h>>>0).toString(16).padStart(8,'0');req('import',{text:JSON.stringify(doc)});}finally{b.close();}
const script=path.join(root,'support-reception.gd');fs.writeFileSync(script,`extends SceneTree
var app: Control
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures.append(message); printerr(message)
func settle() -> void:
 for frame in 10: await process_frame
func wait_command() -> void:
 var deadline := Time.get_ticks_msec() + 45000
 while app.waiting and Time.get_ticks_msec() < deadline: await process_frame
 check(not app.waiting and app.bridge.last_response_ok, "Commande réelle acceptée · " + str(app.last_error))
 await settle()
func command(id: String, payload: Dictionary = {}) -> void:
 app._command(id, payload); await wait_command()
func capture(name: String) -> void:
 if DisplayServer.get_name() == "headless": return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OS.get_environment("CD_SUPPORT_CAPTURES").path_join(name+".png")) == OK, "Capture "+name)
func open_tab(index: int) -> Node:
 app._navigate("Travail du club"); await settle()
 var page: Node = app.body.find_child("CarnetSupport", true, false)
 check(page != null, "Écran Travail du club")
 if page != null:
  var tabs: TabContainer = page.find_child("SupportTabs", true, false)
  tabs.current_tab = index
 await settle()
 return page
func run() -> void:
 root.size = Vector2i(1280,720)
 app = load("res://main.tscn").instantiate(); root.add_child(app)
 var startup_deadline := Time.get_ticks_msec() + 45000
 while app.model.is_empty() and Time.get_ticks_msec() < startup_deadline: await process_frame
 await settle()
 await command("export")
 var before: String = app.model.meta.exportText
 var disk: String = str(app.model.meta.dataDir).path_join("donnees.json")
 var bytes := FileAccess.get_file_as_bytes(disk)
 for dimensions in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
  root.size = dimensions
  for index in 3:
   var page: Node = await open_tab(index)
   if page == null: continue
   var tabs: TabContainer = page.find_child("SupportTabs", true, false)
   check(tabs.get_tab_count() == 3 and tabs.size.y >= 250, "Trois onglets et contenu visible")
   check(page.size.x <= app.body.size.x + 2, "Carnet contenu en largeur")
   await capture("support-"+str(index)+"-"+str(dimensions.x))
 await command("export")
 check(app.model.meta.exportText == before and FileAccess.get_file_as_bytes(disk) == bytes, "Navigation et devis purs")
 var page: Node = await open_tab(0)
 var morale: int = app.model.clubLife.clubSupport.diagnostic.morale
 var meeting: Button = page.find_child("SupportMeeting_cohesion", true, false)
 check(meeting != null and not meeting.disabled and meeting.custom_minimum_size.y >= 44, "Réunion réelle disponible")
 meeting.pressed.emit(); await wait_command()
 check(app.model.clubLife.clubSupport.diagnostic.morale == mini(98,morale+3), "Effet moral du vrai contrôle")
 page = await open_tab(0)
 check(page.find_child("SupportMeeting_cohesion",true,false).disabled,"Réunion verrouillée")
 page.find_child("SupportTraining_proteger",true,false).pressed.emit(); await wait_command()
 page = await open_tab(0)
 page.find_child("SupportBriefing_pack",true,false).pressed.emit(); await wait_command()
 check(app.model.clubLife.clubSupport.briefing.selected == "pack", "Briefing réel enregistré")
 page = await open_tab(1)
 # La liste médicale contient aussi les joueurs en reprise (sans blessure) : le choix de protocole ne concerne que les blessés.
 var injured: Dictionary = {}
 for candidate: Dictionary in app.model.clubLife.clubSupport.medical.players:
  if int(candidate.injury) > 0: injured = candidate; break
 check(not injured.is_empty(), "Joueur blessé à suivre (liste : " + str(app.model.clubLife.clubSupport.medical.players.size()) + ")")
 if not injured.is_empty():
  var picker: OptionButton = page.find_child("MedicalProtocol_"+str(injured.id).replace(":","_"),true,false)
  check(picker != null, "Sélecteur de protocole du blessé")
  if picker != null:
   picker.select(0)
   page.find_child("MedicalChoose_"+str(injured.id).replace(":","_"),true,false).pressed.emit(); await wait_command()
   var followed: Array = app.model.clubLife.clubSupport.medical.players.filter(func(x: Dictionary): return x.id == injured.id)
   check(not followed.is_empty() and followed[0].protocol == "prudent", "Protocole du contrôle médical")
 page = await open_tab(2)
 var selected: Dictionary = app.model.clubLife.clubSupport.agents.players[0]
 var q: Dictionary = selected.quotes.filter(func(x:Dictionary):return x.policy=="equilibre")[0]
 var proposal: Button = page.find_child("AgentPropose_"+str(int(q.years))+"_equilibre",true,false)
 check(proposal != null and not proposal.disabled,"Proposition réelle disponible")
 proposal.pressed.emit(); await wait_command()
 page = await open_tab(2)
 page.find_child("AgentConfirm_"+str(q.id).replace(":","_"),true,false).pressed.emit(); await settle()
 var dialog: ConfirmationDialog = app.find_child("AgentSignatureDialog",true,false)
 check(dialog != null and dialog.visible and dialog.dialog_text.contains("34 semaines"),"Confirmation prime et engagement34")
 check(dialog != null and dialog.get_ok_button().text == "Signer la prolongation" and dialog.get_cancel_button().text == "Annuler", "Choix du dialogue en français")
 await capture("signature")
 if dialog != null: dialog.confirmed.emit(); await wait_command()
 check(app.model.clubLife.clubSupport.agents.history[0].status == "signed","Signature par le vrai dialogue")
 var report := FileAccess.open(OS.get_environment("CD_SUPPORT_CAPTURES").path_join("report.json"),FileAccess.WRITE)
 report.store_string(JSON.stringify({"checks":checks,"failures":failures},"  ")); report.close()
 app.closing=true; app.timer.stop(); app.bridge.stop()
 var deadline := Time.get_ticks_msec()+5000
 while app.bridge.child_pid>0 and Time.get_ticks_msec()<deadline: await process_frame
 app.queue_free(); await settle()
 print("SUPPORT UI ",checks," contrôles ; ",failures.size()," échec(s)")
 quit(0 if failures.is_empty() else 1)
`);
const r=spawnSync(godot,[...(process.env.CD_SUPPORT_GRAPHICS==='1'?[]:['--headless']),'--log-file',path.join(root,'godot-live.log'),'--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',script],{encoding:'utf8',windowsHide:true,timeout:120000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(root,'PrototypeGodot'),CD_SUPPORT_CAPTURES:root}});const log=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),log);console.log(log);console.log('Preuves support '+root);if(r.error)throw r.error;assert.equal(r.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
