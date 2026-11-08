extends SceneTree
const S = preload("res://ui/data_semantics.gd")
const Office = preload("res://ui/office_view.gd")
const ClubViews = preload("res://ui/club_views.gd")
const T = preload("res://theme.gd")
var checks := 0
var failures: Array[String] = []
var metrics: Array = []
var capture := OS.get_environment("CD_SEMANTIC_CAPTURE") == "1"
var proof := OS.get_environment("CD_SEMANTIC_PROOF")
var live_app: Control
var live_metrics: Array = []
class AppFixture extends Control:
 var model: Dictionary = {}
 var accent := Color("cc4d57")
 var management_ui: Dictionary = {}
 var table_division := "elite"
 var catalogue: Array = []
 var route := "Bureau"
 var commands := 0
 func _navigate(next: String): route = next
 func _render(): pass
 func _command(_name: String, _payload: Dictionary = {}): commands += 1

func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
 checks += 1
 if not ok:
  failures.append(message)
  if failures.size() <= 12: printerr("FAIL ", message)
func fixture() -> Dictionary:
 var rows: Array = []
 for i in 14:
  rows.append({"id":100+i,"name":"Club des Rives " + str(i+1),"rank":i+1,"played":12,"won":9-mini(i,8),"drawn":1+i%2,"lost":2+mini(i,8)-i%2,"pf":242-i*4,"pa":180+i*3,"points":42-i*2,"form":["V","V","N","D","V","D","V","N"]})
 rows[2].points = -2
 rows[4].name = "Union des Rives et des Hauts Plateaux"
 rows[5].erase("lost")
 rows[5].erase("points")
 rows[5].erase("pf")
 rows[5].form = ["V","?","N"]
 var club: Dictionary = rows[4].duplicate(true)
 club.goal = "Rester dans la course"
 return {"club":club,"meta":{"leagueId":"elite"},"league":rows,"leagues":[{"id":"elite","name":"Élite · fixture sans simulation","rows":rows}]}
func contrast(a: Color,b: Color) -> float:
 var first := a.srgb_to_linear().get_luminance()
 var second := b.srgb_to_linear().get_luminance()
 return (maxf(first,second)+0.05)/(minf(first,second)+0.05)
func semantic_nodes(node: Node) -> Array[Node]:
 var result: Array[Node] = []
 for child in node.find_children("*","PanelContainer",true,false):
  if child.has_meta("semantic_role"):result.append(child)
 return result
func inspect_contrast(node: Node) -> void:
 for panel in semantic_nodes(node):
  var label: Label = panel.get_node("Value")
  var fg := label.get_theme_color("font_color")
  var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
  check(style.bg_color.a==1.0,"Fond du badge opaque sur sélection et hover")
  check(contrast(fg,style.bg_color)>=4.5,"Contraste du vrai badge >=4,5")
  check(not panel.tooltip_text.is_empty(),"Contexte disponible dans tooltip")
  check(not panel.accessibility_name.is_empty(),"Contexte accessible fourni")
func build_page(viewport: Vector2i) -> AppFixture:
 root.mode = Window.MODE_WINDOWED
 root.size = viewport
 root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
 root.content_scale_size = viewport
 var app := AppFixture.new()
 app.theme = T.paper()
 app.model = fixture()
 app.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root.add_child(app)
 var background := ColorRect.new()
 background.color = Color("191b1c")
 background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 app.add_child(background)
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
 app.add_child(margin)
 var row := HBoxContainer.new()
 row.add_theme_constant_override("separation",16)
 margin.add_child(row)
 var frame := PanelContainer.new()
 frame.custom_minimum_size.x = 340
 frame.add_theme_stylebox_override("panel",T.box(Color("f3eddf"),3))
 row.add_child(frame)
 var office := VBoxContainer.new()
 office.name = "OfficeTableStudy"
 frame.add_child(office)
 Office._table(office,app)
 var tables := ClubViews.tables(app)
 tables.name = "FullTableStudy"
 tables.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 row.add_child(tables)
 return app
func run() -> void:
 if OS.get_environment("CD_SEMANTIC_APP") == "1":
  await real_pages()
  return
 if proof.is_empty():
  push_error("Dossier de preuve explicite requis")
  quit(1);return
 DirAccess.make_dir_recursive_absolute(proof)
 root.title = "Étude DA · données sémantiques · prototype externe"
 var marker_path := proof.path_join("profile-marker.txt")
 var marker := FileAccess.open(marker_path,FileAccess.WRITE)
 marker.store_string("fixture de profil, sans carrière ni moteur\n");marker.close()
 var marker_sha := FileAccess.get_sha256(marker_path)
 for missing in [null,-1,INF,NAN,"3",true]: check(S.count_text(missing)=="—","Donnée absente/invalide n'invente aucun zéro")
 check(S.count_text(0)=="0","Zéro public conservé")
 check(S.number_text(-3)=="-3","Points négatifs connus conservés, sans règle inventée")
 check(S.count_text(3.0)=="3","Entier JSON flottant conservé")
 check(S.difference_text(24,19)=="5","Différence du score conservée")
 check(S.difference_text(null,19)=="—","Différence absente non inventée")
 for viewport in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]:
  seed(71445)
  var expected_first := randi()
  var expected_second := randi()
  seed(71445)
  check(randi()==expected_first,"Précondition RNG reproductible")
  var app := build_page(viewport)
  var before := JSON.stringify(fixture())
  for i in 8: await process_frame
  check(JSON.stringify(app.model)==before,"Toutes les valeurs et l'ordre du modèle restent inchangés")
  check(app.commands==0,"Le rendu n'envoie aucune commande")
  check(randi()==expected_second,"Le rendu ne tire pas le RNG UI")
  check(FileAccess.get_sha256(marker_path)==marker_sha,"Le profil de contrôle n'a pas été écrit")
  var grid: GridContainer = app.find_child("OfficeStandingsGrid",true,false)
  check(grid.columns==7,"Bureau : sept colonnes dont D")
  var win: PanelContainer = app.find_child("OfficeStanding_104_won",true,false).get_child(0)
  var drawn: PanelContainer = app.find_child("OfficeStanding_104_drawn",true,false).get_child(0)
  var lost: PanelContainer = app.find_child("OfficeStanding_104_lost",true,false).get_child(0)
  check(win.get_node("Value").text=="5" and drawn.get_node("Value").text=="1" and lost.get_node("Value").text=="6","Compteurs V/N/D connus conservés")
  check(win.get_theme_stylebox("panel").bg_color!=drawn.get_theme_stylebox("panel").bg_color and drawn.get_theme_stylebox("panel").bg_color!=lost.get_theme_stylebox("panel").bg_color,"Trois fonds sémantiques distincts")
  var missing: PanelContainer = app.find_child("OfficeStanding_105_lost",true,false).get_child(0)
  check(missing.get_node("Value").text=="—","Colonne D absente affiche —")
  var full: Control = app.find_child("StandingsRow_104",true,false)
  for pair in [["won","5"],["drawn","1"],["lost","6"]]:
   var full_badge: PanelContainer=full.find_child("StandingCount_"+pair[0],true,false)
   check(full_badge.get_node("Value").text==pair[1],"Classement complet : compteur connu conservé")
  var negative_points: PanelContainer=app.find_child("StandingsRow_102",true,false)
  check(negative_points.get_child(0).get_child(7).text=="-2","Classement complet : points négatifs publics conservés")
  var unknown_row: PanelContainer=app.find_child("StandingsRow_105",true,false)
  check(unknown_row.get_child(0).get_child(6).text=="—","Classement complet : PF absent laisse la différence inconnue")
  var short_form: HBoxContainer=unknown_row.find_child("RecentForm",true,false)
  var short_codes: Array=[]
  for item in short_form.get_children():short_codes.append(item.get_node("Value").text)
  check(short_codes==["V","—","N"],"Forme courte et emplacement inconnu conservés sans faux match")
  var full_rows := app.find_children("StandingsRow_*","PanelContainer",true,false)
  if viewport.y>=1080:check(full_rows.size()==14,"Grande hauteur : toute la division visible")
  var table_frame: Control=app.find_child("StandingsTableFrame",true,false)
  var context: Control=app.find_child("StandingsContext",true,false)
  check(table_frame!=null and context!=null,"Table et contexte disposent de conteneurs stables")
  if viewport.x>=1920 and table_frame!=null:
   check(table_frame.size.x<=1120,"Table bornée sur écran large")
   check(context.is_visible_in_tree(),"Contexte réel visible sur écran large")
  check((full.get_theme_stylebox("panel") as StyleBoxFlat).border_width_bottom>=2,"Marqueur géométrique du club courant conservé")
  var own: PanelContainer = app.find_child("OfficeStanding_104_club",true,false)
  check((own.get_theme_stylebox("panel") as StyleBoxFlat).border_width_bottom>=2,"Marqueur géométrique Bureau conservé")
  check(app.find_children("ResultLegend","HBoxContainer",true,false).size()==2,"Légende visible dans Bureau et classement")
  var form: HBoxContainer = full.find_child("RecentForm",true,false)
  var codes: Array = []
  for item in form.get_children():codes.append(item.get_node("Value").text)
  check(codes==["N","D","V","D","V","N"],"Six résultats réels, ordre chronologique conservé")
  for accent in [Color("cc4d57"),Color.WHITE,Color.BLACK,Color("ffee00"),Color("001bff")]:
   for amount in [0.0,0.12,0.18,0.23]:
    for field in ["rank","club","played","won","drawn","lost","points"]:
     var cell: PanelContainer = app.find_child("OfficeStanding_104_"+field,true,false)
     var parent_style := cell.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
     parent_style.bg_color = Color("f3eddf").lerp(accent,amount)
     cell.add_theme_stylebox_override("panel",parent_style)
    var full_style := full.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
    full_style.bg_color = Color("f3eddf").lerp(accent,amount)
    full.add_theme_stylebox_override("panel",full_style)
    inspect_contrast(app)
  # Restaurer le vrai fond du club après les variantes de contraste testées.
  for field in ["rank","club","played","won","drawn","lost","points"]:
   var cell: PanelContainer = app.find_child("OfficeStanding_104_"+field,true,false)
   var own_style := cell.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
   own_style.bg_color = Color("f3eddf").lerp(Color(app.accent,1),0.12)
   cell.add_theme_stylebox_override("panel",own_style)
  var normal_full_style := full.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
  normal_full_style.bg_color = Color(app.accent,0.10)
  full.add_theme_stylebox_override("panel",normal_full_style)
  var viewport_rect := Rect2(Vector2.ZERO,Vector2(viewport))
  for badge in semantic_nodes(app):
   if badge.is_visible_in_tree():check(viewport_rect.encloses(badge.get_global_rect()),"Badge entièrement visible à "+str(viewport))
  metrics.append({"size":str(viewport),"semantic_badges":semantic_nodes(app).size(),"grid_width":grid.size.x,"grid_minimum":grid.get_combined_minimum_size().x,"office_width":own.get_parent().size.x})
  if capture and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   var error := root.get_texture().get_image().save_png(proof.path_join("semantic-%d.png"%viewport.x))
   check(error==OK,"Capture écrite")
  app.queue_free()
  await process_frame
 print("SEMANTIC_DATA_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"display":DisplayServer.get_name()}))
 quit(0 if failures.is_empty() else 1)


func settle_app() -> void:
 await create_timer(0.12).timeout
 for i in 6: await process_frame

func wait_live_model() -> bool:
 var deadline := Time.get_ticks_msec() + 30000
 while (live_app.waiting or live_app.model.is_empty()) and Time.get_ticks_msec() < deadline:
  await process_frame
 check(not live_app.waiting and not live_app.model.is_empty(), "Vrai worker disponible")
 live_app.timer.stop()
 await settle_app()
 return not live_app.waiting and not live_app.model.is_empty()

func ask_live(command: String, payload: Dictionary = {}) -> bool:
 live_app._command(command,payload)
 if not await wait_live_model(): return false
 check(live_app.bridge.last_response_ok,"Commande réelle " + command + " : " + live_app.last_error)
 return live_app.bridge.last_response_ok

func close_guide() -> void:
 if is_instance_valid(live_app.coach): live_app.coach.close()

func profile_hashes() -> Dictionary:
 var directory: String = str(live_app.model.meta.dataDir)
 var hashes: Dictionary = {}
 for filename in DirAccess.get_files_at(directory):
  if filename.ends_with(".json"): hashes[filename] = FileAccess.get_sha256(directory.path_join(filename))
 return hashes

func scroll_to_grid() -> void:
 var target: Control = live_app.find_child("OfficeStandingsGrid",true,false)
 if target == null: return
 var parent := target.get_parent()
 while parent != null and parent != live_app:
  if parent is ScrollContainer and parent.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
   var local_y: float = target.get_global_rect().position.y - parent.get_global_rect().position.y + parent.scroll_vertical
   parent.scroll_vertical = maxi(0,roundi(local_y)-4)
  parent=parent.get_parent()
 await settle_app()

func real_capture(label: String) -> void:
 if not capture or DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(proof.path_join(label+".png"))==OK,"Capture réelle " + label)

func real_resize(viewport: Vector2i) -> void:
 root.mode=Window.MODE_WINDOWED
 root.size=viewport
 if DisplayServer.get_name()!="headless": DisplayServer.window_set_size(viewport)
 await settle_app()
 check(root.content_scale_size==viewport and live_app.size==Vector2(viewport),"Densité PC native " + str(viewport))

func real_standings(viewport: Vector2i, league: Dictionary) -> void:
 var rows: Array=league.rows
 var displayed := live_app.find_children("StandingsRow_*","PanelContainer",true,false)
 var scroll: ScrollContainer=live_app.find_child("StandingsScroll",true,false)
 check(not displayed.is_empty(),"Vraies lignes du championnat présentes")
 if viewport.y>=1080:check(displayed.size()==rows.size(),"Toute la division %s visible à %s"%[league.id,viewport])
 if viewport.y==720:check(displayed.size()<rows.size(),"720p garde la pagination de division")
 for i in displayed.size():
  check(displayed[i].get_meta("club_id")==rows[i].id,"Ordre natif des clubs conservé")
  check(scroll.get_global_rect().grow(1).encloses(displayed[i].get_global_rect()),"Ligne entière dans la zone visible")
  for pair in [["won","V"],["drawn","N"],["lost","D"]]:
   var badge: PanelContainer=displayed[i].find_child("StandingCount_"+pair[0],true,false)
   check(badge.get_node("Value").text==S.count_text(rows[i].get(pair[0])),"Vrai compteur de division conservé")
 var table: Control=live_app.find_child("StandingsTableFrame",true,false)
 var context: Control=live_app.find_child("StandingsContext",true,false)
 check(context.visible==(viewport.x>=1920),"Contexte latéral réservé aux grands écrans")
 if context.visible:
  check(table.size.x<=1120,"Largeur du vrai tableau bornée")
  var club_name: Label=context.find_child("StandingsContextClubName",true,false)
  check(club_name.size.x>=240 and club_name.size.y<100,"Nom du club en ligne lisible dans le contexte")
 if viewport.y==720:
  var pager: HBoxContainer=live_app.find_child("StandingsPagination",true,false)
  var first_count:=displayed.size()
  var next: Button=pager.get_child(2)
  next.grab_focus();next.pressed.emit();await settle_app()
  var second := live_app.find_children("StandingsRow_*","PanelContainer",true,false)
  check(second[0].get_meta("club_id")==rows[first_count].id,"Suivant atteint la suite exacte des clubs")
  pager=live_app.find_child("StandingsPagination",true,false)
  var previous: Button=pager.get_child(0)
  previous.grab_focus();previous.pressed.emit();await settle_app()
  var restored:=live_app.find_children("StandingsRow_*","PanelContainer",true,false)
  check(restored[0].get_meta("club_id")==rows[0].id,"Précédent restaure la première page")
  var focus:=live_app.get_viewport().gui_get_focus_owner()
  check(focus is Button and focus.is_visible_in_tree(),"Focus clavier conservé après pagination")

func real_pages() -> void:
 if proof.is_empty() or OS.get_environment("CD_GODOT_DATA_DIR").is_empty():
  push_error("Profil et preuve explicites requis")
  quit(2);return
 DirAccess.make_dir_recursive_absolute(proof)
 AudioServer.set_bus_mute(0,true)
 root.mode=Window.MODE_WINDOWED
 root.size=Vector2i(1280,720)
 live_app=load("res://main.tscn").instantiate()
 root.add_child(live_app)
 if is_instance_valid(live_app.coach): live_app.coach.speech.set_muted(true)
 if not await wait_live_model(): quit(1);return
 if not await ask_live("new_career",{"club":0,"mode":"common"}): quit(1);return
 # Laisser les premiers conseils de visite s'enregistrer avant les invariants.
 for route in ["Bureau","Classements"]:
  live_app._navigate(route)
  await settle_app()
  close_guide()
 if not await ask_live("export"): quit(1);return
 var before_export: String = live_app.model.meta.exportText
 var before_model := JSON.stringify(live_app.model)
 var before_files := profile_hashes()
 var before_requests: int = live_app.bridge._next_id
 var genuine_rows: Array = []
 for league: Dictionary in live_app.model.leagues:
  if league.id==live_app.model.meta.leagueId:genuine_rows=league.rows
 check(not genuine_rows.is_empty(),"Vrai classement projeté")
 for viewport in [Vector2i(1280,720),Vector2i(2560,1440)]:
  await real_resize(viewport)
  live_app._navigate("Bureau");await settle_app();close_guide()
  var grid: GridContainer = live_app.find_child("OfficeStandingsGrid",true,false)
  check(grid!=null and grid.columns==7,"Vrai Bureau : colonne D présente")
  if grid==null:break
  var grid_minimum: float = grid.get_combined_minimum_size().x
  var own: Dictionary={}
  for row: Dictionary in genuine_rows:
   if row.id==live_app.model.club.id:own=row
  for item in [["won","V"],["drawn","N"],["lost","D"]]:
   var cell_name: String = ("OfficeStanding_%s_%s"%[str(own.id),item[0]]).validate_node_name()
   var cell: PanelContainer = live_app.find_child(cell_name,true,false)
   check(cell!=null,"Vraie cellule " + str(item[0]))
   if cell!=null:
    var badge: PanelContainer = cell.get_child(0)
    check(badge.get_node("Value").text==S.count_text(own.get(item[0])),"Valeur native exacte " + str(item[0]))
  inspect_contrast(live_app)
  var columns: Control = live_app.find_child("OfficeColumns",true,false)
  check(columns!=null and columns.get_child(2).visible==(viewport.x>1280),"Compacité du vrai Bureau conservée")
  await real_capture("bureau-%d"%viewport.x)
  if viewport.x==1280:
   await scroll_to_grid()
   await real_capture("bureau-1280-cap")
  var action: Button = live_app.find_child("OfficeStandingsAction",true,false)
  check(action!=null and not action.disabled,"Vrai lien classement disponible")
  if action!=null:
   action.grab_focus()
   await settle_app()
   action.pressed.emit()
   await settle_app()
  close_guide()
  check(live_app.route=="Classements","Navigation Bureau vers Classements conservée")
  var list: ScrollContainer=live_app.find_child("StandingsScroll",true,false)
  check(list!=null,"Vrai tableau complet présent")
  if list!=null:
   check(list.get_h_scroll_bar().max_value<=list.get_h_scroll_bar().page+1,"Aucun clipping horizontal du vrai classement " + str(viewport))
  inspect_contrast(live_app)
  var legends := live_app.find_children("ResultLegend","HBoxContainer",true,false)
  check(legends.size()==1,"Légende réelle du classement présente")
  if not legends.is_empty():check(Rect2(Vector2.ZERO,Vector2(viewport)).encloses(legends[0].get_global_rect()),"Légende réelle visible " + str(viewport))
  for league: Dictionary in live_app.model.leagues:
   var tab: Button=live_app.find_child("StandingsDivision_"+str(league.id),true,false)
   check(tab!=null,"Vrai choix de division")
   tab.pressed.emit();await settle_app()
   await real_standings(viewport,league)
   await real_capture("classements-%d-%s"%[viewport.x,league.id])
  live_app.table_division=live_app.model.meta.leagueId
  live_app._render();await settle_app()
  await real_capture("classements-%d"%viewport.x)
  live_metrics.append({"size":str(viewport),"canvas":str(root.content_scale_size),"grid_minimum":grid_minimum,"club_id":live_app.model.club.id,"data_rows":genuine_rows.size()})
 # Redimensionner le tableau vivant, sans reconstruire la page par navigation.
 await real_resize(Vector2i(1920,1080))
 for league: Dictionary in live_app.model.leagues:
  var tab: Button=live_app.find_child("StandingsDivision_"+str(league.id),true,false)
  tab.pressed.emit();await settle_app()
  await real_standings(Vector2i(1920,1080),league)
  await real_capture("classements-1920-%s"%league.id)
 check(live_app.bridge._next_id==before_requests,"Affichage/navigation sans requête métier")
 check(JSON.stringify(live_app.model)==before_model,"Projection complète inchangée par les vraies pages")
 check(profile_hashes()==before_files,"Carrière, guide et préférences JSON inchangés par consultation")
 if await ask_live("export"):
  check(live_app.model.meta.exportText==before_export,"Export complet S/RNG inchangé")
 var result := {"checks":checks,"failures":failures,"metrics":live_metrics,"display":DisplayServer.get_name(),"profile_files":before_files}
 var file:=FileAccess.open(proof.path_join("real-pages-report.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(result,"  "));file.close()
 print("SEMANTIC_APP_CHECKS ",JSON.stringify(result))
 live_app.closing=true
 if is_instance_valid(live_app.coach):live_app.coach.destroy()
 live_app.bridge.stop()
 var deadline:=Time.get_ticks_msec()+2300
 while live_app.bridge.child_pid>0 and Time.get_ticks_msec()<deadline:await process_frame
 live_app.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
