'use strict';
// Écran « Travail du club » (soutien) piloté par les vrais contrôles Godot, sur une carrière Monde préparée par Node
// (tests/helpers/support-ui-prepare.cjs : jour du premier match, un joueur blessé, rendez-vous du club réglés).
// Stabilisée le 14/11 (rouge 3 fois sur 4 avant). Causes corrigées :
//  - un blessé injecté hors moteur ouvre son rendez-vous médical à la première commande acceptée (ici la réunion de
//    soutien) : le jeu bloque alors toute navigation et toute commande tant qu'il n'est pas réglé (comportement voulu) ;
//    la préparation le règle maintenant avant de rendre la sauvegarde ;
//  - nouvelle carrière « common » refusée (seul le mode Monde existe) et briefing demandé en pré-saison (aucune rencontre
//    à préparer : il faut être au jour d'un match) ;
//  - devis d'agent : l'engagement affiche les semaines payées du devis (29 en Monde), pas 34 en dur ;
//  - un moteur local tué (mémoire) laissait toutes les commandes silencieusement ignorées puis un bouton absent et 120 s
//    d'attente : la préparation tourne dans un processus à part (mémoire rendue avant Godot) et le script s'arrête net,
//    avec un message, si le moteur est arrêté ou si le script dépasse 100 s.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),{spawnSync}=require('node:child_process');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;if(!godot){console.log('SKIP native-club-support-ui.cjs : SDK Godot absent (CD_GODOT_EXE ou CD_GODOT_EXECUTABLE) ; réception native non exécutée.');process.exit(0);}const root=fs.mkdtempSync(path.join(require('node:os').tmpdir(),'cd-support-ui-'));
// Sauvegarde Monde (jour du premier match, un blessé, rendez-vous réglés) préparée dans un processus à part.
const prep=spawnSync(process.execPath,['--max-old-space-size=2000',path.resolve(__dirname,'helpers/support-ui-prepare.cjs'),root],{encoding:'utf8',timeout:420000,maxBuffer:64*1024*1024});
if(prep.status!==0){console.log((prep.stdout||'')+(prep.stderr||''));throw new Error('Préparation de la sauvegarde Monde en échec (code '+prep.status+(prep.signal?', signal '+prep.signal:'')+').');}
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
 # Un moteur local arrêté refuse toute commande sans jamais « attendre » : sans ce contrôle, la suite des vérifications
 # passerait sur des réponses périmées et le script finirait par planter sur un bouton absent.
 if app.bridge.child_pid <= 0 or app.connection_error:
  failures.append("Moteur local arrêté · " + str(app.last_error)); printerr("Moteur local arrêté · " + str(app.last_error)); quit(1); return
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
 # Garde-fou : un contrôle manquant ne doit pas laisser Godot tourner jusqu'au délai du test.
 create_timer(100.0).timeout.connect(func() -> void:
  printerr("Délai du script dépassé"); quit(3))
 root.size = Vector2i(1280,720)
 app = load("res://main.tscn").instantiate(); root.add_child(app)
 var startup_deadline := Time.get_ticks_msec() + 45000
 while app.model.is_empty() and Time.get_ticks_msec() < startup_deadline: await process_frame
 await settle()
 # Carrière Monde préparée par Node (rendez-vous réglés, un blessé) : aucune nouvelle carrière ici.
 check(app.model.get("clubLife", {}).get("clubMeetings", {}).get("scene") == null, "Départ sans rendez-vous du club en attente")
 # Pas d'« export » : il matérialise toute la sauvegarde Monde (~50 Mo) en texte, côté moteur puis côté Godot, soit
 # plusieurs centaines de Mo de plus sur une machine où le moteur local pèse déjà ~1,5 Go. Un instantané du moteur et
 # l'empreinte du fichier de sauvegarde suffisent à prouver que naviguer et lire des devis ne change rien.
 await command("snapshot")
 var before: int = app.model.hash()
 var disk: String = str(app.model.meta.dataDir).path_join("donnees.json")
 var bytes: String = FileAccess.get_sha256(disk)
 for dimensions in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
  root.size = dimensions
  for index in 3:
   var page: Node = await open_tab(index)
   if page == null: continue
   var tabs: TabContainer = page.find_child("SupportTabs", true, false)
   check(tabs.get_tab_count() == 3 and tabs.size.y >= 250, "Trois onglets et contenu visible")
   check(page.size.x <= app.body.size.x + 2, "Carnet contenu en largeur")
   await capture("support-"+str(index)+"-"+str(dimensions.x))
 await command("snapshot")
 check(app.model.hash() == before and FileAccess.get_sha256(disk) == bytes, "Navigation et devis purs")
 var page: Node = await open_tab(0)
 var morale: int = app.model.clubLife.clubSupport.diagnostic.morale
 var meeting: Button = page.find_child("SupportMeeting_cohesion", true, false)
 # Plancher de la peau compacte : 28 px (game_skin.gd, G.button), plus 44 px.
 check(meeting != null and not meeting.disabled and meeting.custom_minimum_size.y >= 28, "Réunion réelle disponible · " + str(meeting != null and meeting.disabled) + " · " + str(meeting.custom_minimum_size if meeting != null else Vector2.ZERO))
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
 # Carrière neuve : un blessé n'est pas garanti. Sans blessé, aucun sélecteur de protocole ne doit être proposé.
 if injured.is_empty():
  check(page.find_children("MedicalProtocol_*", "OptionButton", true, false).is_empty(), "Aucun sélecteur de protocole sans joueur blessé")
 else:
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
 check(dialog != null and dialog.visible and dialog.dialog_text.contains("%d semaines payées par saison" % int(q.paidWeeks)),"Confirmation prime et engagement (semaines payées du devis)")
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
const r=spawnSync(godot,[...(process.env.CD_SUPPORT_GRAPHICS==='1'?[]:['--headless']),'--log-file',path.join(root,'godot-live.log'),'--max-fps','120','--path',path.resolve(__dirname,'../native/godot'),'--script',script],{encoding:'utf8',windowsHide:true,timeout:120000,env:{...process.env,CD_GODOT_SELF_TEST:'0',CD_NODE_EXECUTABLE:process.execPath,CD_GODOT_DATA_DIR:path.join(root,'PrototypeGodot'),CD_SUPPORT_CAPTURES:root}});const log=(r.stdout||'')+(r.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),log);fs.rmSync(path.join(root,'PrototypeGodot'),{recursive:true,force:true});console.log(log);console.log('Preuves support '+root);if(r.error){fs.rmSync(path.join(root,'PrototypeGodot'),{recursive:true,force:true});try{console.log(fs.readFileSync(path.join(root,'godot-live.log'),'utf8'));}catch{}throw r.error;}assert.equal(r.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
