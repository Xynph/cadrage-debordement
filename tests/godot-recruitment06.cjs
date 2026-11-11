'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const {test}=require('node:test');
const godot=process.env.CD_GODOT_EXE||process.env.CD_GODOT_EXECUTABLE;
test('Recrutement et presse : présentations natives des rapports et relances', {skip:!godot&&'SDK Godot absent : réception non exécutée'},()=>{
const root=fs.mkdtempSync(path.join(process.env.TEMP||require('node:os').tmpdir(),'cd-recruitment06-'));
const {context}=require('./france-harness.cjs'),h=context(10606),decisions=require('../native/engine/decisions.cjs'),press=require('../native/engine/press.cjs');
h.run(`start(0,'fiction');const nativeDecisions=${decisions.toString()};const nativePress=(${press.factory.toString()})();`);
h.run(`{const p=managerPool()[0];S.manager.reports=[{id:'report-ui',playerId:p.id,name:'Émile D’Ávila — profil à comparer à nos solutions',pos:p.pos,family:p.fam,age:25,note:72,potential:81,salary:p.salary,price:p.price,grade:'B',season:1,week:0}];S.round=2;var nativeMandatoryPress=true;nativePress.observeInvitation();const q=nativePress.project().conference.questions[0],source=CDPressQuestionBank.questions.find(source=>source.theme===q.theme&&source.id!==q.id);S.pressConference={version:1,history:[{id:source.id,season:1,week:0,club:0,answerId:'r4',questionText:'Comment voyez-vous le projet ?',answerText:'Nous avançons ensemble, sans promesse de victoire.',journalist:{id:q.journalist.id,name:q.journalist.name,outlet:q.journalist.outlet}}]};}`);
h.run("S.manager.reports.push({...S.manager.reports[0],id:'report-ui2',name:'Zoé — autre rapport daté',note:61,grade:'C'});");
h.prepareNativeProjection();
fs.writeFileSync(path.join(root,'model.json'),h.run('JSON.stringify({decisions:nativeDecisions(),clubLife:{press:nativePress.project()},club:{id:S.club},squad:[],leagues:[],meta:{}})'));
const script=path.join(root,'recruitment.gd');fs.writeFileSync(script,`extends SceneTree
var failures: Array[String] = []
var checks := 0
class App extends Control:
 var model: Dictionary
 var management_ui: Dictionary = {}
 var accent := Color("a72436")
 func _clear_dialogs() -> void:
  for child in get_children():
   if child is AcceptDialog: remove_child(child); child.queue_free()
 func _prepare_dialog(d: AcceptDialog, _width: int) -> void: d.theme = load("res://theme.gd").paper()
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
 checks += 1
 if not value: failures.append(message); printerr(message)
func settle() -> void:
 for i in 8: await process_frame
func run() -> void:
 var app := App.new()
 app.model = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CD_RECRUITMENT06_ROOT").path_join("model.json")))
 root.add_child(app); app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var view = load("res://ui/decision_views.gd")
 view.recruitment(app)
 await settle()
 var dialog: AcceptDialog = app.find_child("RecruitmentNeeds",true,false)
 check(dialog != null,"Dossier recrutement présent")
 if dialog == null: quit(1); return
 var tabs: TabContainer = dialog.find_child("ScoutTabs",true,false)
 check(tabs != null and tabs.get_tab_count() == 3,"Besoins, missions et rapports en sous-onglets")
 if tabs != null: tabs.current_tab = 2; await settle()
 var picker: OptionButton = dialog.find_child("ScoutReportPicker",true,false)
 check(picker != null and picker.item_count == app.model.decisions.recruitment.reports.size(),"Un rapport sélectionné à la fois")
 var card: Control = dialog.find_child("ScoutReport_report-ui",true,false)
 check(card != null,"Rapport humain présenté en carte dédiée")
 if card != null:
  for section in ["ScoutObserved", "ScoutEstimates", "ScoutLimits", "ScoutSource", "ScoutFit"]:
   check(card.find_child(section,true,false) != null,"Section de rapport : " + section)
  var source: Label = card.find_child("ScoutSource",true,false)
  check(source.text.contains("Saison 1") and source.text.contains("suivi 0"),"Source du rapport datée sans inventer une semaine de calendrier")
  var evidence: TabContainer = card.find_child("ScoutEvidenceTabs",true,false)
  check(evidence != null and evidence.get_tab_count() == 3,"Faits, avis et réserves consultables sans empilement")
  for dimensions in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
   root.size = dimensions; await settle()
   check(card.size.x <= dialog.size.x,"Carte contenue dans le dialogue")
  if picker != null:
   picker.select(1); picker.item_selected.emit(1); await settle()
   check(dialog.find_child("ScoutReport_report-ui2",true,false) != null,"Autre rapport accessible par le sélecteur")
   check(dialog.find_child("ScoutReport_report-ui",true,false) == null,"Rapports non empilés après sélection")
   picker.select(0); picker.item_selected.emit(0); await settle()
   check(dialog.find_child("ScoutReport_report-ui",true,false) != null,"Retour au premier rapport sans perte de données")
 app._clear_dialogs()
 var surface := PanelContainer.new();app.add_child(surface);surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 app.set_meta("press_mail_origin", app.model.clubLife.press.conference.invitationId)
 var page: Control = load("res://ui/press_view.gd").build(app)
 surface.add_child(page);await settle()
 var questions: Array = app.model.clubLife.press.conference.questions
 for q: Dictionary in questions:
  if q.has("followUp"):
   var source: Label = page.find_child("PressFollowUp_" + str(q.id),true,false)
   check(source != null and source.text.contains("saison 1"),"Source de relance datée visible")
  for answer: Dictionary in q.answers:
   var option: Button = page.find_child("PressAnswer_"+str(q.id)+"_"+str(answer.id),true,false)
   check(option != null,"Les cinq réponses restent présentes")
   if option != null: check(option.get_theme_font_size("font_size") <= 13,"Corps de réponse compact sans suppression du texte")
 check(page.find_child("PressMemoryNotice",true,false) != null,"Limite des archives expliquée")
 app.queue_free(); await settle()
 print("Recrutement/presse06 headless : ",checks," contrôles ; ",failures.size()," échec(s)")
 quit(0 if failures.is_empty() else 1)
`);
const result=spawnSync(godot,['--headless','--log-file',path.join(root,'godot-engine.log'),'--path',path.resolve(__dirname,'../native/godot'),'--script',script],{encoding:'utf8',windowsHide:true,timeout:60000,env:{...process.env,CD_RECRUITMENT06_ROOT:root}});
const log=(result.stdout||'')+(result.stderr||'');fs.writeFileSync(path.join(root,'godot.log'),log);console.log(log);console.log('Preuves headless : '+root);if(result.error)throw result.error;assert.equal(result.status,0,log);assert.doesNotMatch(log,/SCRIPT ERROR|Parse Error|ERROR:/);
});
