extends RefCounted
## Notes et affectations de la Tactique : projections moteur exclusivement.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const Notation = preload("res://ui/notation_staff.gd")

class PlayerButton extends Button:
	var drag_player := ""
	var source_slot := -1
	var target_slot := -1
	var drag_caption := ""
	var make_payload: Callable
	var accepts_payload: Callable
	var apply_payload: Callable
	## Aperçu qui suit la souris (tuile portrait) ; sinon le nom dans une pastille.
	var make_preview: Callable
	## Pendant un glisser, sur la place survolée : `apercu_depot.call(bouton, data)` pose la pastille au poste du joueur
	## traîné (nœud « TacticsDropPreview ») ; retiré quand la souris part ou que le glisser finit.
	var apercu_depot: Callable
	## État visuel du glisser : 1 = place possible (contour vert), 2 = survolée et possible, -1 = survolée et refusée.
	var etat_depot := 0
	func _ready() -> void:
		mouse_exited.connect(func(): if etat_depot == 2 or etat_depot == -1: _etat(1 if _possible() else 0))
	func _input(event: InputEvent) -> void:
		var viewport:=get_viewport()
		if event.is_action_pressed("ui_cancel") and viewport.gui_is_dragging():
			viewport.gui_cancel_drag()
			viewport.set_input_as_handled()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_BEGIN: _etat(1 if _possible() else 0)
		elif what == NOTIFICATION_DRAG_END: _etat(0)
	func _possible() -> bool:
		var viewport := get_viewport()
		if viewport == null or not viewport.gui_is_dragging() or target_slot < 0 or not accepts_payload.is_valid(): return false
		var data: Variant = viewport.gui_get_drag_data()
		return data is Dictionary and accepts_payload.call(data, target_slot)
	func _etat(valeur: int, data: Variant = null) -> void:
		if valeur == etat_depot: return
		etat_depot = valeur
		set_meta("depot", valeur)
		var ancien := get_node_or_null("TacticsDropPreview")
		if ancien != null:
			remove_child(ancien)
			ancien.queue_free()
		if valeur == 2 and apercu_depot.is_valid(): apercu_depot.call(self, data)
		queue_redraw()
	func _draw() -> void:
		if etat_depot == 0: return
		var couleur := Charte.PERTE if etat_depot == -1 else Charte.CONDITION
		var epaisseur := 4.0 if etat_depot != 1 else 2.0
		var fond := StyleBoxFlat.new()
		fond.bg_color = Color(couleur, 0.22 if etat_depot != 1 else 0.08)
		fond.border_color = couleur
		fond.set_border_width_all(int(epaisseur))
		fond.set_corner_radius_all(int(Charte.RAYON_CARTE * C.density))
		draw_style_box(fond, Rect2(Vector2.ZERO, size))
		if etat_depot == -1:
			var police := get_theme_default_font()
			var t := int(minf(size.y * .5, 44.0))
			var largeur := police.get_string_size("✕", HORIZONTAL_ALIGNMENT_LEFT, -1, t).x
			draw_string(police, Vector2((size.x - largeur) / 2.0, size.y / 2.0 + t * .35), "✕", HORIZONTAL_ALIGNMENT_LEFT, -1, t, Charte.PERTE)
	func _get_drag_data(_at: Vector2) -> Variant:
		if drag_player.is_empty() or not make_payload.is_valid(): return null
		var data: Variant = make_payload.call(drag_player,source_slot)
		if data == null: return null
		var preview: Control = make_preview.call() if make_preview.is_valid() else null
		if preview == null:
			var pastille := PanelContainer.new()
			# Aperçu du glisser aux jetons de la charte : panneau-3, rayon 6, sans cadre, texte ivoire.
			pastille.add_theme_stylebox_override("panel",C.box(C.SELECTED,Color.TRANSPARENT,Charte.RAYON_PETIT,12))
			pastille.add_child(C.label(drag_caption,20,C.IVORY,false,500))
			preview = pastille
		preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
		set_drag_preview(preview)
		return data
	func _can_drop_data(_at: Vector2,data: Variant) -> bool:
		var ok: bool = target_slot>=0 and accepts_payload.is_valid() and accepts_payload.call(data,target_slot)
		# Retour visuel sur la place survolée : vert + pastille au poste du joueur traîné, ou rouge ✕ (refus du jeu).
		if target_slot >= 0 and data is Dictionary and data.get("kind") == "tactics_player" and str(data.get("player_id", "")) != drag_player:
			_etat(2 if ok else -1, data)
		return ok
	func _drop_data(_at: Vector2,data: Variant) -> void:
		_etat(0)
		if _can_drop_data(_at,data) and apply_payload.is_valid():apply_payload.call(data,target_slot)

static func state(app: Control) -> Dictionary:
	if not app.management_ui.get("tactics_reading") is Dictionary:
		app.management_ui.tactics_reading={"mode":"bench","player_id":"","scroll":0,"focus":""}
	return app.management_ui.tactics_reading

## Index de lecture le temps d'une construction de l'écran (lecture_debut / lecture_fin) : places, joueurs et sources
## lus une fois au lieu d'un parcours de la feuille et de l'effectif à chaque appel (61 joueurs × 23 places). Hors de
## cette fenêtre, aucune mémoire : la projection du moteur peut changer entre deux rendus.
static var _lecture: Dictionary = {}

static func lecture_debut(model: Dictionary) -> void:
	var slots := {}
	var sources := {}
	for assignment: Dictionary in model.get("selection",{}).get("slots",[]):
		var index: Variant=assignment.get("slot")
		if (index is int or index is float) and not slots.has(int(index)):slots[int(index)]=assignment
		var id: Variant=assignment.get("playerId")
		if id is String and not sources.has(id):sources[id]=int(assignment.slot)
	var joueurs := {}
	for person: Dictionary in model.get("squad",[]):
		var cle:=str(person.get("id",""))
		if not joueurs.has(cle):joueurs[cle]=person
	_lecture={"model":model,"slots":slots,"sources":sources,"joueurs":joueurs}

static func lecture_fin() -> void:
	_lecture={}

static func _index(model: Dictionary) -> Dictionary:
	return _lecture if not _lecture.is_empty() and is_same(_lecture.model,model) else {}

static func slot(model: Dictionary,index: int) -> Dictionary:
	var lu:=_index(model)
	if not lu.is_empty():return lu.slots.get(index,{})
	for assignment: Dictionary in model.get("selection",{}).get("slots",[]):
		if assignment.get("slot")==index:return assignment
	return {}

static func player(model: Dictionary,id: String) -> Dictionary:
	var lu:=_index(model)
	if not lu.is_empty():return lu.joueurs.get(id,{})
	for person: Dictionary in model.get("squad",[]):
		if str(person.get("id",""))==id:return person
	return {}

static func source(model: Dictionary,id: String) -> int:
	var lu:=_index(model)
	if not lu.is_empty():return lu.sources.get(id,-1)
	for assignment: Dictionary in model.get("selection",{}).get("slots",[]):
		if assignment.get("playerId")==id:return int(assignment.slot)
	return -1

static func number(model: Dictionary,index: int) -> int:
	var projected: Variant=slot(model,index).get("positionNumber")
	if (projected is int or projected is float) and projected>=1 and projected<=15 and projected==int(projected):return int(projected)
	return index+1 if index>=0 and index<15 else 0

static func rating(model: Dictionary,person: Dictionary,index: int) -> Variant:
	var position:=number(model,index)
	var ratings: Variant=person.get("positionRatings")
	if position==0 or not ratings is Dictionary:return null
	var value: Variant=ratings.get(str(position))
	if not (value is int or value is float) or not is_finite(float(value)) or value<0 or value>100:return null
	return value

## Rôle de chaque numéro (les deux 2e ligne, les deux 3e ligne aile, les deux centres, les deux ailiers se valent).
const ROLES := [1, 2, 3, 4, 4, 6, 6, 8, 9, 10, 11, 12, 12, 11, 15]

## Familiarité du joueur avec le poste de la place `index` : 3 poste naturel (même rôle que son poste principal),
## 2 deuxième poste (même rôle qu'un poste secondaire), 1 dépanne, -1 inconnue (sans poste principal, place hors XV).
static func familiarite(model: Dictionary,person: Dictionary,index: int) -> int:
	var position:=number(model,index)
	var primary: Variant=person.get("primaryPosition")
	if position<1 or position>15 or not (primary is int or primary is float) or int(primary)<1 or int(primary)>15:return -1
	var role: int=ROLES[position-1]
	if ROLES[int(primary)-1]==role:return 3
	for secondary: Variant in person.get("secondaryPositions",[]):
		if (secondary is int or secondary is float) and int(secondary)>=1 and int(secondary)<=15 and ROLES[int(secondary)-1]==role:return 2
	return 1

## Note au poste de la place `index` en LETTRE (Notation.lettre_poste, échelle du Niveau, jamais de chiffre) :
## {bas, haut} ; -1 si la place n'a pas de poste ou si le moteur ne projette pas de note valide.
static func lettre(model: Dictionary,person: Dictionary,index: int) -> Dictionary:
	if rating(model,person,index)==null:return {"bas":-1,"haut":-1}
	return Notation.lettre_poste(model,person,number(model,index),true)

## Note au poste principal du joueur en lettre ({bas: -1} sans poste principal ni note projetée).
static func lettre_principale(model: Dictionary,person: Dictionary) -> Dictionary:
	var principal: Variant=person.get("primaryPosition")
	var notes: Variant=person.get("positionRatings")
	if not (principal is int or principal is float) or not notes is Dictionary:return {"bas":-1,"haut":-1}
	var v: Variant=notes.get(str(int(principal)))
	if not ((v is int or v is float) and is_finite(float(v))):return {"bas":-1,"haut":-1}
	return Notation.lettre_poste(model,person,int(principal),true)

static func rating_text(model: Dictionary,person: Dictionary,index: int) -> String:
	return Notation.texte_note(lettre(model,person,index)) if rating(model,person,index)!=null else "—"

static func positions(person: Dictionary) -> String:
	var result: PackedStringArray=[]
	var primary: Variant=person.get("primaryPosition")
	if primary is int or primary is float:result.append(str(int(primary)))
	for secondary: Variant in person.get("secondaryPositions",[]):
		if secondary is int or secondary is float:result.append(str(int(secondary)))
	return " · ".join(result) if not result.is_empty() else str(person.get("pos","—"))

static func editable(app: Control) -> bool:
	return not app.waiting and app._live().is_empty() and app.model.get("meta",{}).get("phase")!="ended"

static func eligible(app: Control,id: String,index: int) -> bool:
	return editable(app) and not player(app.model,id).is_empty() and id in slot(app.model,index).get("eligibleIds",[])

static func payload(app: Control,id: String,from: int) -> Variant:
	if not editable(app) or player(app.model,id).is_empty() or source(app.model,id)!=from:return null
	return {"kind":"tactics_player","player_id":id,"source_slot":from,"club_id":app.model.get("club",{}).get("id")}

static func can_drop(app: Control,data: Variant,target: int) -> bool:
	if not data is Dictionary or data.get("kind")!="tactics_player":return false
	if not data.get("player_id") is String or not data.get("source_slot") is int:return false
	var club_id:Variant=app.model.get("club",{}).get("id")
	if typeof(data.get("club_id"))!=typeof(club_id) or data.get("club_id")!=club_id:return false
	var id: String=data.player_id
	if source(app.model,id)!=data.source_slot or slot(app.model,target).get("playerId")==id:return false
	return eligible(app,id,target)

static func apply(app: Control,data: Variant,target: int) -> bool:
	if not can_drop(app,data,target):return false
	app.selected_slot=target
	var reading:=state(app)
	reading.player_id="";reading.focus="LineupSlot%02d" % (target+1)
	app._command("set_lineup",{"playerId":data.player_id,"slot":target})
	return true

## Joueur affecté à une place de la feuille (0-22), ou {}.
static func occupant(model: Dictionary,index: int) -> Dictionary:
	var id: Variant=slot(model,index).get("playerId")
	return {} if id==null else player(model,str(id))

## Le joueur est-il formé à ce poste de première ligne (1, 2 ou 3) ? Qualifications projetées par le moteur
## (qualifiedFrontRowPositions) ; à défaut, éligibilité du moteur au maillot correspondant.
static func forme_premiere_ligne(model: Dictionary,person: Dictionary,poste: int) -> bool:
	if person.is_empty():return false
	var qualifs: Variant=person.get("qualifiedFrontRowPositions")
	if qualifs is Array:
		for value: Variant in qualifs:
			if (value is int or value is float) and int(value)==poste:return true
		return false
	return str(person.get("id","")) in slot(model,poste-1).get("eligibleIds",[])

static func premiere_ligne_formee(model: Dictionary,person: Dictionary) -> bool:
	return forme_premiere_ligne(model,person,1) or forme_premiere_ligne(model,person,2) or forme_premiere_ligne(model,person,3)

## Règle de la première ligne (loi 3, docs/rugby-rules-reference.md, saison 2026/27) lue sur la feuille : pour chaque
## poste (pilier gauche, talonneur, pilier droit), le titulaire, le remplaçant désigné et le nombre de formés parmi
## eux ; `formes` = joueurs distincts de la feuille formés en première ligne ; `cible` = 6 pour une feuille à 23.
## La validité de la feuille reste celle du moteur (selection.valid / errors) : ceci n'est qu'une lecture.
static func premiere_ligne(model: Dictionary) -> Dictionary:
	var lu:=_index(model)
	if lu.has("premiere"):return lu.premiere
	var libelles := {1:"Pilier gauche",2:"Talonneur",3:"Pilier droit"}
	var banc_defaut := {2:15,1:16,3:17}
	var postes: Array=[]
	for poste in [1,2,3]:
		var remplacant: int=banc_defaut[poste]
		for index in range(15,23):
			if int(slot(model,index).get("positionNumber",-1))==poste:remplacant=index;break
		var titulaire_joueur:=occupant(model,poste-1)
		var remplacant_joueur:=occupant(model,remplacant)
		var formes:=int(forme_premiere_ligne(model,titulaire_joueur,poste))+int(forme_premiere_ligne(model,remplacant_joueur,poste))
		postes.append({"poste":poste,"libelle":libelles[poste],"titulaire":poste-1,"remplacant":remplacant,"formes":formes})
	var vus:={}
	for index in 23:
		var person:=occupant(model,index)
		if premiere_ligne_formee(model,person):vus[str(person.id)]=true
	var resultat:={"postes":postes,"formes":vus.size(),"cible":6}
	if not lu.is_empty():lu.premiere=resultat
	return resultat

## Place de première ligne (n° 1-3 ou leurs remplaçants désignés) ?
static func place_premiere_ligne(model: Dictionary,index: int) -> bool:
	if index>=0 and index<3:return true
	for poste: Dictionary in premiere_ligne(model).postes:
		if int(poste.remplacant)==index:return true
	return false

static func wire(button: PlayerButton,app: Control,id: String,index: int,target: int,caption: String) -> void:
	button.drag_player=id;button.source_slot=index;button.target_slot=target;button.drag_caption=caption
	button.make_payload=func(player_id: String,from: int):return payload(app,player_id,from)
	button.accepts_payload=func(data: Variant,to: int):return can_drop(app,data,to)
	button.apply_payload=func(data: Variant,to: int):return apply(app,data,to)
