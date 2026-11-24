extends "res://ui/squad_views_liste.gd"
## Composition, Préparation et lecture des quotas (découpe de squad_views.gd, sans changement).

# Keep the bound dictionary when a career reset replaces management_ui. Retiring
# controls can only update their former UI state, never the new career's state.
class LineupReading extends HBoxContainer:
	var state: Dictionary
	var outer: ScrollContainer
	var restoring := true
	func _ready() -> void:
		for control: Control in find_children("*","Control",true,false):
			if control.focus_mode != Control.FOCUS_NONE:
				control.focus_entered.connect(func():
					if is_inside_tree() and not restoring: state.focus=str(control.name))
		outer.get_v_scroll_bar().value_changed.connect(func(value:float):
			if is_inside_tree() and not restoring:state.outer=int(value))
		var list:ScrollContainer=find_child("LineupCandidatesScroll",true,false)
		list.get_v_scroll_bar().value_changed.connect(func(value:float):
			if is_inside_tree() and not restoring:state.list=int(value))
		_restore.call_deferred()
	func _restore() -> void:
		if not is_inside_tree():return
		var tree:=get_tree()
		await tree.process_frame
		await tree.process_frame
		if not is_inside_tree() or not is_instance_valid(outer) or not outer.is_inside_tree():return
		var control:Control=find_child(str(state.focus),true,false) if not str(state.focus).is_empty() else null
		if control!=null and control.is_visible_in_tree() and (not control is BaseButton or not control.disabled):control.grab_focus()
		await tree.process_frame
		if not is_inside_tree() or not is_instance_valid(outer) or not outer.is_inside_tree():return
		var list:ScrollContainer=find_child("LineupCandidatesScroll",true,false)
		list.scroll_vertical=int(state.list)
		outer.scroll_vertical=int(state.outer)
		# The eligibility message may shrink after assignment and grow the list.
		# Keep the closest valid offset when its previous bottom no longer exists.
		state.list=list.scroll_vertical
		state.outer=outer.scroll_vertical
		restoring=false

static func lineup(app:Control) -> Control:
	var page:=LineupReading.new()
	page.add_theme_constant_override("separation",14)
	if not app.management_ui.get("lineup") is Dictionary:app.management_ui.lineup={"outer":0,"list":0,"focus":""}
	page.state=app.management_ui.lineup
	if page.state.get("candidate_slot", app.selected_slot) != app.selected_slot:
		page.state.list = 0
		if str(page.state.focus).begins_with("LineupPlayer"):
			page.state.focus = "LineupSlot%02d" % (app.selected_slot + 1)
	page.state.candidate_slot = app.selected_slot
	page.outer=app.body_scroll
	G.fill(page,true)
	page.name="CarnetLineup"
	var pitch:=G.panel(page,1.15)
	if app.size.y<=760:pitch.add_theme_constant_override("separation",3)
	G.chapter(pitch,"02","La feuille de match","Titulaire ou remplaçant : choisis un poste.",app.accent)
	var condition := G.label("Condition du XV · " + P.lineup_condition(app.model), 15)
	condition.name = "LineupCondition"
	pitch.add_child(condition)
	var board:=Board.new()
	board.app=app
	pitch.add_child(board)
	var bench:=G.h(5)
	pitch.add_child(bench)
	for i in 8:
		var slot:=15+i
		var b:=G.button(str(slot+1),func():app.selected_slot=slot;app._render())
		b.name="LineupSlot%02d"%(slot+1)
		G.fill(b)
		if app.selected_slot==slot: b.add_theme_stylebox_override("normal",G.T.box(Color("ddd1bc"),3,G.GOLD))
		bench.add_child(b)
	var side:=G.panel(page,1.0)
	var heading := G.section("Poste %02d" % (app.selected_slot + 1))
	var candidate_count := G.wrap("", 13, G.MUTED)
	candidate_count.name = "LineupCandidateCount"
	heading.add_child(candidate_count)
	side.add_child(heading)
	var selection:Dictionary=app.model.get("selection",{})
	var slots:Array=selection.get("slots",[])
	var selected:Dictionary={}
	for s in slots:
		if int(s.get("slot",-1))==app.selected_slot:selected=s
	var errors:Array=selection.get("errors",[])
	if errors.is_empty():side.add_child(G.label("FEUILLE VALIDE",12,G.GOOD))
	else:side.add_child(G.wrap("\n".join(errors),12,G.ALERT))
	var vacancy := P.reduced_bench_number(app.model)
	if not Espoir.offer(app.model).is_empty():
		var appel := G.button("APPELER UN ESPOIR",func():Espoir.ouvrir(app,false))
		appel.name="LineupCallEspoir"
		appel.tooltip_text=Espoir.vacancy_text(app.model)
		side.add_child(appel)
	if vacancy != 0:
		var action := G.button("MATCH · FEUILLE À 22",func():app._navigate("Match"))
		action.name="LineupOpenMatchAt22"
		action.tooltip_text=P.reduced_bench_vacancy(vacancy)
		action.accessibility_name="Ouvrir le jour de match pour une feuille à 22"
		side.add_child(action)
	var licences: Dictionary = selection.get("nationaleQualification", {})
	if not licences.is_empty():
		var bloc := G.wrap("FFR  ·  4 licences B/C dont 1 C maximum  ·  %d à vérifier" % int(licences.unverified), 11, G.MUTED)
		bloc.name = "NationaleLicenceNotice"
		var note: Dictionary = licences.get("notice", {})
		bloc.tooltip_text = str(note.get("summary", "")) + "\n" + str(note.get("detail", ""))
		side.add_child(bloc)
	# Quota du championnat : JIFF (Top 14, Pro D2) ou EQP (Premiership), même ligne (nom LineupJiffNotice conservé).
	var quota: Dictionary = app.model.get("clubLife", {}).get("jiff", {})
	if bool(quota.get("applies", false)):
		# 13 px et couleur d'état (capture 1280×720 du 18/11 : à 11 px gris atténué, la ligne passait inaperçue) :
		# rouge sous la trajectoire, vert quand la feuille atteint la moyenne exigée, gris sinon.
		var quota_ok := int(quota.get("currentSheet", 0)) + int(quota.get("doublon", 0)) >= int(quota.get("target", 16))
		var quota_bloc := G.wrap(quota_line(quota), 13, G.ALERT if bool(quota.get("alert", false)) else (G.GOOD if quota_ok else G.MUTED))
		quota_bloc.name = "LineupJiffNotice"
		quota_bloc.tooltip_text = quota_tooltip(quota)
		side.add_child(quota_bloc)
	# Protocole des Bleus (liste de 33) : joueurs de la feuille qui doivent souffler ce week-end.
	var bleus := bleus_resume(app)
	if not bleus.is_empty():
		# Capture 1280×720 du 19/11 (8 matchs d'historique) : à 11 px en simple ligne de texte, l'alerte se perdait sous
		# le quota (13 px) et n'offrait aucune action. Encadré rouge à 13 px, accord au pluriel et action du staff.
		var cadre := PanelContainer.new()
		cadre.name = "LineupBleusNotice"
		var fond := StyleBoxFlat.new()
		fond.bg_color = Color(G.ALERT, 0.12)
		fond.border_color = G.ALERT
		fond.set_border_width_all(0)
		fond.border_width_left = 4
		fond.set_corner_radius_all(4)
		fond.content_margin_left = 12; fond.content_margin_right = 10; fond.content_margin_top = 8; fond.content_margin_bottom = 8
		cadre.add_theme_stylebox_override("panel", fond)
		var pile := VBoxContainer.new()
		pile.add_theme_constant_override("separation", 6)
		cadre.add_child(pile)
		var titre := G.wrap(str(bleus.titre), 13, G.ALERT)
		titre.name = "LineupBleusTitle"
		pile.add_child(titre)
		pile.add_child(G.wrap("Protocole de la liste des 33 : au moins 2 repos sur 8 matchs de club. L'aligner quand même coûte la confiance du staff des Bleus.", 12, G.MUTED))
		cadre.tooltip_text = "Liste de 33 joueurs du XV de France : les clubs les laissent hors de la feuille au moins 2 fois sur 8 rencontres. Ligne directrice, ajustable par accord avec le staff des Bleus."
		var echanges: Array = bleus.echanges
		var lignes: Array = bleus.lignes
		# Capture du 19/11 : après 6 matchs sans repos, 9 titulaires d'un coup ; 9 boutons repoussaient la liste des
		# candidats hors de l'écran. Jusqu'à 2 : un bouton par joueur ; au-delà, un seul bouton (échange groupé côté
		# moteur, tout ou rien) et les remplaçants sur une ligne.
		if echanges.size() > 2:
			var detail := G.wrap("Remplaçants du staff : " + "  ·  ".join(lignes), 11, G.MUTED)
			detail.name = "LineupBleusChanges"
			pile.add_child(detail)
			var lot: Array = bleus.lot
			var tous := G.button("FAIRE SOUFFLER LES %d  ·  REMPLAÇANTS DU STAFF" % echanges.size(), func(): app._command("set_lineup", {"changes": lot}))
			tous.name = "LineupBleusRestAll"
			tous.tooltip_text = "\n".join(lignes)
			tous.disabled = not app._live().is_empty()
			pile.add_child(tous)
		else:
			for i in echanges.size():
				var e: Dictionary = echanges[i]
				var faire := G.button("FAIRE SOUFFLER " + str(lignes[i]).replace(" → ", "  →  "), func(): app._command("set_lineup", {"playerId": e.playerId, "slot": e.slot}))
				faire.name = "LineupBleusRest" + str(e.sortant).replace(":", "_")
				faire.tooltip_text = "Remplaçant proposé par le staff au même poste, hors feuille et disponible."
				faire.disabled = not app._live().is_empty()
				pile.add_child(faire)
		side.add_child(cadre)
	var auto:=G.button("SÉLECTION AUTOMATIQUE DU STAFF",func():app._command("auto_lineup"))
	auto.name="LineupAutomatic"
	auto.disabled=not app._live().is_empty()
	side.add_child(auto)
	var quote := Cover.data(app)
	if not quote.is_empty():
		var cover := G.button(Cover.caption(quote), func(): Cover.confirm(app, quote))
		cover.name = "LineupCover"
		Cover.configure(cover, quote)
		side.add_child(cover)
	var list:=G.scroll(side)
	list.get_parent().name="LineupCandidatesScroll"
	var eligible:Variant=selected.get("eligibleIds")
	for p in app.model.get("squad",[]):
		var identity := "%s · %s" % [p.name, p.pos]
		if p.get("playerFacts", {}).get("listeElite", false): identity += " · Liste des 33"
		var metrics := "Condition %s %% · Niveau %s" % [G.n(p.condition), G.rating_text(p,true)]
		var b := G.button("",func():app._command("set_lineup",{"playerId":p.id,"slot":app.selected_slot}))
		b.accessibility_name = identity + " · " + metrics
		b.tooltip_text = b.accessibility_name
		b.set_meta("player_id",str(p.id))
		b.name="LineupPlayer"+str(p.id).replace(":","_")
		b.disabled=not app._live().is_empty() or float(p.get("injury",0))>0 or (eligible is Array and p.id not in eligible)
		if b.disabled:b.tooltip_text+="\nIndisponible ou qualification incompatible avec ce poste. Pendant un match, utilise les remplacements."
		var inset := G.margin(8)
		inset.add_theme_constant_override("margin_top",0)
		inset.add_theme_constant_override("margin_bottom",0)
		inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(inset)
		var row := G.h(8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_child(row)
		var ink := G.MUTED if b.disabled else G.INK
		var name := G.label(identity,14,ink)
		name.name = "LineupCandidateIdentity"
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name)
		var values := G.label(metrics,12,ink)
		values.name = "LineupCandidateMetrics"
		values.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(values)
		list.add_child(b)
	var allowed_count := 0
	for candidate: Button in list.get_children():
		if candidate.disabled: continue
		list.move_child(candidate, allowed_count)
		allowed_count += 1
	var plural := "s" if allowed_count > 1 else ""
	candidate_count.text = "%d candidat%s autorisé%s sur %d" % [allowed_count, plural, plural, list.get_child_count()]
	var remove:=G.button("LIBÉRER CE POSTE",func():app._command("set_lineup",{"playerId":null,"slot":app.selected_slot}))
	remove.name="LineupRemove"
	remove.disabled=not app._live().is_empty()
	side.add_child(remove)
	return page

static func preparation(app:Control) -> Control:
	return preload("res://ui/preparation_view.gd").build(app)

## Ligne du quota de joueurs formés localement : sur la feuille (doublon compris), besoin du prochain match, moyenne, marge.
## `quota` = clubLife.jiff (jiff.cjs). L'alerte (feuille sous la trajectoire de la moyenne exigée) colore la ligne.
## Protocole des Bleus (liste de 33) : joueurs de la feuille qui doivent souffler, remplaçants proposés par le staff
## (clubLife.doublons). Partagé par l'ancienne feuille et par l'écran Composition (tactics_canvas.gd).
## Rend {} si rien à signaler, sinon {noms, lignes, echanges ([{slot, playerId, sortant}]), titre, lot}.
static func bleus_resume(app: Control) -> Dictionary:
	var bleus: Dictionary = app.model.get("clubLife", {}).get("doublons", {})
	if not bool(bleus.get("applies", false)): return {}
	var noms_par_id := {}
	for p: Variant in app.model.get("squad", []):
		if p is Dictionary: noms_par_id[str(p.get("id", ""))] = str(p.get("name", ""))
	var noms: Array = []
	for item: Variant in bleus.get("reposer", []):
		if item is Dictionary and noms_par_id.has(str(item.get("playerId", ""))): noms.append(noms_par_id[str(item.get("playerId", ""))])
	if noms.is_empty(): return {}
	var echanges: Array = []
	var lignes: Array = []
	var lot: Array = []
	for change: Variant in bleus.get("changes", []):
		if not (change is Dictionary): continue
		var sortant := str(noms_par_id.get(str(change.get("sortant", "")), ""))
		var entrant := str(noms_par_id.get(str(change.get("playerId", "")), ""))
		if sortant.is_empty() or entrant.is_empty(): continue
		echanges.append({"slot": int(change.get("slot", 0)), "playerId": change.get("playerId"), "sortant": str(change.get("sortant", ""))})
		lot.append({"slot": int(change.get("slot", 0)), "playerId": change.get("playerId")})
		lignes.append("%s → %s (%d %%)" % [sortant, entrant, int(change.get("entrantCondition", 0))])
	var qui := ", ".join(noms) if noms.size() <= 3 else "%d joueurs de la liste" % noms.size()
	return {"noms": noms, "lignes": lignes, "echanges": echanges, "lot": lot,
		"titre": "BLEUS  ·  %s %s souffler ce week-end" % [qui, "doit" if noms.size() == 1 else "doivent"]}

static func quota_line(quota: Dictionary) -> String:
	var label := str(quota.get("label", "JIFF"))
	var target := int(quota.get("target", 16))
	var current := int(quota.get("currentSheet", 0))
	var doublon := int(quota.get("doublon", 0))
	var line := "%s  ·  %d sur cette feuille" % [label, current]
	if doublon > 0:
		line += " + %d convoqué%s en équipe de France" % [doublon, "s" if doublon > 1 else ""]
	line += "  ·  %d exigés en moyenne" % target
	if quota.get("average") != null:
		line += "  ·  moyenne de la saison %s" % String.num(float(quota.average), 2)
		var margin := int(quota.get("margin", 0))
		if margin != 0:
			line += "  ·  marge %s%d" % ["+" if margin > 0 else "−", absi(margin)]
	if quota.get("need") != null and bool(quota.get("alert", false)):
		line += "  ·  il en faut %d à ce match pour tenir la moyenne" % int(quota.need)
		if bool(quota.get("outOfReach", false)):
			line += " (même 23 ne suffiraient plus)"
	if int(quota.get("deduction", 0)) > 0:
		line += "  ·  retrait de %d point(s) cette saison" % int(quota.deduction)
	return line

static func quota_tooltip(quota: Dictionary) -> String:
	var target := int(quota.get("target", 16))
	if str(quota.get("kind", "jiff")) == "eqp":
		return "Joueurs sélectionnables pour l'Angleterre (EQP). La Premiership exige %d EQP par feuille de 23 en moyenne sur la saison ; en dessous, la ligue inflige une amende (jusqu'à 250 000 £), sans retrait de points." % target
	return "Joueurs issus des filières de formation : 3 saisons en centre de formation français ou 5 saisons de licence en France avant 22 ans. Sous la moyenne de %d par feuille sur la saison, le club perd des points la saison suivante ; à partir de %d, le fonds JIFF verse une prime. Les jours de doublon, les JIFF convoqués en équipe de France comptent dans la feuille du club." % [target, int(quota.get("bonusFrom", 17))]
