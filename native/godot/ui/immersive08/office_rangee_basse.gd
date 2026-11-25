extends "res://ui/immersive08/office_priorites_groupe.gd"
## Écran Bureau : classement court et sa légende, courrier, prochains matchs de la colonne de Gabi (découpe de office_canvas.gd, sans changement).

# ---------------------------------------------------------------------------------------------------------
# Classement court
# ---------------------------------------------------------------------------------------------------------

static func _standings(card: Panel, app: Control, w: int = 1100) -> void:
	var large := w >= 900
	var rows := short_rows(P.standings(app.model), app.model.club.get("id"), STANDINGS_ROWS if large else 6)
	var zones := Zones.visible(rows)
	var stride := 34
	var rank_x := 72 if not zones.is_empty() else 44
	var name_x := rank_x + 46
	var forme_w := 190 if large else 0
	var pts_x := w - 28 - forme_w - (20 if large else 0)
	var diff_x := pts_x - 90
	var vnd_x := diff_x - 140
	var played_x := vnd_x - 100 if large else diff_x - 110
	_lien(card, w - 20, 14, "Classement complet →", func(): app._navigate("Classements"), "OfficeStandingsAction", 20, true)
	var entetes: Array = [["RG", rank_x, HORIZONTAL_ALIGNMENT_CENTER], ["CLUB", name_x, HORIZONTAL_ALIGNMENT_LEFT], ["J", played_x, HORIZONTAL_ALIGNMENT_CENTER], ["DIFF.", diff_x, HORIZONTAL_ALIGNMENT_RIGHT], ["PTS", pts_x, HORIZONTAL_ALIGNMENT_RIGHT]]
	if large:
		entetes.append(["V-N-D", vnd_x, HORIZONTAL_ALIGNMENT_CENTER])
		entetes.append(["FORME", w - 28 - forme_w, HORIZONTAL_ALIGNMENT_LEFT])
	for entete: Array in entetes: D.text(card, entete[1], 90, entete[0], 16, Charte.IVOIRE_2, 700, 90, entete[2])
	for i in rows.size():
		var club: Dictionary = rows[i]
		var y := 100 + i * stride
		var own: bool = club.get("id") == app.model.club.id
		var box := Rect2(16, y, w - 32, stride)
		if i > 0 and not own and not (i > 0 and rows[i - 1].get("id") == app.model.club.id): D.line(card, Vector2(16, y), Vector2(w - 16, y), Charte.FILET)
		if own: D.rect(card, box, Charte.SELECTION, 8)  # 8 en référence 2560 = 6 px à 1920
		var hit := Office.standing_action(app, club)
		card.add_child(hit)
		D.place(hit, box)
		var zone := Zones.of(club)
		if not zone.is_empty():
			var kind := str(zone.get("kind", ""))
			var edge := D.rect(hit, Rect2(0, 3, 4, stride - 6), Zones.tint(kind))
			edge.name = "StandingsZoneEdge"
			var side := Zones.mark_side(Zones.BUREAU_MARK_PX)
			Zones.mark(hit, kind, Rect2(10, (stride - side) / 2.0, side, side), Zones.tint(kind))
		elif own:
			D.rect(hit, Rect2(0, 3, 4, stride - 6), Charte.club_trait(app.accent))
		var base := y + stride - 10
		var ouvert := P.standings_open(club)
		D.text(card, rank_x, base, G.n(club.get("rank", "—")) if ouvert else "–", 21, Charte.IVOIRE, 700, 40, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(card, name_x, base, G.club_name(club), 21, Charte.club_texte(app.accent) if own else Charte.IVOIRE, 700 if own else 600, played_x - name_x - 40)
		D.text(card, played_x, base, G.n(club.get("played", 0)), 21, Charte.IVOIRE_2, 500, 40, HORIZONTAL_ALIGNMENT_CENTER)
		D.text(card, diff_x, base, "%+d" % (int(club.get("pf", 0)) - int(club.get("pa", 0))), 21, Charte.IVOIRE_2, 500, 80, HORIZONTAL_ALIGNMENT_RIGHT)
		D.text(card, pts_x, base, G.n(club.get("points", 0)), 22, Charte.IVOIRE, 700, 70, HORIZONTAL_ALIGNMENT_RIGHT)
		if large:
			if club.has("won"): D.text(card, vnd_x, base, "%s-%s-%s" % [G.n(club.get("won", 0)), G.n(club.get("drawn", 0)), G.n(club.get("lost", 0))], 21, Charte.IVOIRE_2, 500, 110, HORIZONTAL_ALIGNMENT_CENTER)
			var forme: Variant = club.get("form", [])
			if forme is Array: _forme(card, w - 28 - forme_w, y + 5, forme)
	var bas := 100 + rows.size() * stride
	if not zones.is_empty(): _zone_legend(card, zones, _zone_note(app.model), 26, bas + 22, w - 52)
	if rows.is_empty() or not P.standings_open(rows[0]) and rows.all(func(r: Dictionary): return not P.standings_open(r)):
		D.text(card, 26, bas + 30, "Début de saison : aucun match joué.", 20, Charte.IVOIRE_2, 500, w - 52, HORIZONTAL_ALIGNMENT_LEFT, true)

## Note du règlement de la ligue du club (« Pas de relégation cette saison. »), vide sinon.
static func _zone_note(model: Dictionary) -> String: return Zones.bureau_note(model)  # note courte, sinon complète si elle tient

## Légende courte, limitée aux zones de l'extrait : « ★ Demi-finale directe · ▼ Relégation » (symboles dessinés),
## puis la note du règlement seulement si elle tient sur la même ligne.
static func _zone_legend(card: Panel, zones: Array, note: String, x: float, baseline: float, width: float) -> Control:
	var group := Control.new()
	group.name = "StandingsZoneLegend"
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(group)
	D.place(group, Rect2(x, baseline - 18, width, 24))
	var cursor := 0.0
	var side := Zones.mark_side(Zones.BUREAU_MARK_PX)
	for i in zones.size():
		var kind := str(zones[i].get("kind", ""))
		if i > 0:
			D.text(group, cursor + 10, 18, "·", 18, Charte.IVOIRE_2, 600, 20, HORIZONTAL_ALIGNMENT_CENTER)
			cursor += 20
		var mark := Zones.mark(group, kind, Rect2(cursor, 19 - side, side, side), Zones.tint(kind))
		mark.name = "StandingsZoneLegendMark_" + kind
		var label := D.text(group, cursor + side + 5, 18, Zones.short_label(zones[i]), 18, Charte.IVOIRE, 600)
		label.name = "StandingsZoneLegendItem_%d" % i
		label.set_meta("zone_kind", kind)
		cursor += side + 5 + label.size.x / C.density
	var spoken := Zones.legend_text(zones)
	if not note.is_empty():
		var room := width - cursor - 20
		if C.font(500).get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, C.px(18))).x / C.density <= room:
			var written := D.text(group, cursor + 20, 18, note, 18, Charte.IVOIRE_2, 500)
			written.name = "StandingsZoneNote"
			spoken += ". " + note
	group.set_meta("legend_text", spoken)
	group.accessibility_name = "Zones du classement : " + spoken
	group.tooltip_text = group.accessibility_name
	return group

# ---------------------------------------------------------------------------------------------------------
# Courrier
# ---------------------------------------------------------------------------------------------------------

## Identifiant du message dans la Réception (même calcul que reception_canvas : empreinte + numéro d'occurrence,
## les exemplaires identiques comptés du plus ancien au plus récent).
static func message_ids(messages: Array) -> Array[String]:
	var ids: Array[String] = []
	ids.resize(messages.size())
	var occurrences := {}
	for index in range(messages.size() - 1, -1, -1):
		var texte := str(messages[index])
		occurrences[texte] = int(occurrences.get(texte, 0)) + 1
		ids[index] = texte.sha256_text() + "-" + str(occurrences[texte])
	return ids

static func open_message(app: Control, id: String) -> void:
	if not app.management_ui.has("reception"):
		app.management_ui.reception = {"folder": 0, "category": "Tous", "selected": "", "oldest_first": false, "marks": {}, "scroll": 0}
	app.management_ui.reception.selected = id
	app._navigate("Réception")

static func _journal(card: Panel, app: Control, w: int = 1132) -> void:
	_lien(card, w - 20, 14, "Réception →", func(): app._navigate("Réception"), "OfficeInboxAction", 20, true)
	var messages: Array = app.model.get("messages", [])
	if messages.is_empty():
		D.text(card, 26, 110, "Le journal s’ouvrira avec ta carrière.", 21, Charte.IVOIRE_2, 400, w - 52, HORIZONTAL_ALIGNMENT_LEFT, true)
		return
	var ids := message_ids(messages)
	# « n non lus » : même lecture que la Réception (marques « lu » de l'état de la boîte).
	var marques: Dictionary = app.management_ui.get("reception", {}).get("marks", {}) if app.management_ui.get("reception") is Dictionary else {}
	var non_lus := 0
	for id in ids:
		if not marques.get(id, {}).get("read", false): non_lus += 1
	var etiquette := D.text(card, 24 + _largeur("COURRIER", 26, C.font(800)) + 22, 38, "%d non lu%s" % [non_lus, "s" if non_lus > 1 else ""], 20, Charte.IVOIRE_2, 500, 200, HORIZONTAL_ALIGNMENT_LEFT, true)
	etiquette.name = "OfficeJournalUnread"
	var reception: Script = load("res://ui/immersive08/reception_canvas.gd")
	var avec_categorie: bool = reception != null and reception.has_method("_category")
	if avec_categorie: D.text(card, 26, 84, "SUJET", 16, Charte.IVOIRE_2, 700, 160)
	var x_titre := 230.0 if avec_categorie else 26.0
	D.text(card, x_titre, 84, "TITRE", 16, Charte.IVOIRE_2, 700, 160)
	for i in mini(4, messages.size()):
		var y := 94 + i * 46
		var message := Copy.news(str(messages[i])).replace("l’onglet Contrats", "les fiches joueurs")
		var titre := message.get_slice("\n", 0).get_slice(". ", 0).strip_edges()
		if titre.length() > 92: titre = titre.left(89).strip_edges() + "…"
		if i > 0: D.line(card, Vector2(16, y), Vector2(w - 16, y), Charte.FILET)
		var ligne := _zone(card, Rect2(16, y, w - 32, 44), "", open_message.bind(app, ids[i]), "OfficeJournalMessage" + str(i + 1), 21)
		ligne.tooltip_text = "Ouvrir la lettre · " + titre
		ligne.accessibility_name = ligne.tooltip_text
		# Les lettres « XV de la journée / de la saison » portent la vignette du XV : un clic ouvre l'écran XV type.
		var vignette := _vignette_xv(app, str(messages[i]), Rect2(w - 92, y + 2, 52, 40))
		var reserve := 60 if vignette == null else 108
		if vignette != null: card.add_child(vignette)
		if avec_categorie:
			# Catégorie du courrier : celle que la Réception attribue à la lettre (même fonction, pas de mots-clés ici).
			var categorie := str(reception._category(U.fold(message)))
			D.text(card, 26, y + 29, categorie, 20, Charte.IVOIRE_2, 500, 190, HORIZONTAL_ALIGNMENT_LEFT, true)
		# Blessure : le nom puis une pastille « ✚ 2 sem. » (la phrase complète reste dans l'infobulle de la ligne).
		var blessure := RegEx.create_from_string("^(.+?) (?:s’est blessée?|est blessée?|se blesse) .*?(\\d+) semaine").search(message.get_slice(char(10), 0))
		if blessure != null:
			var nom := blessure.get_string(1)
			D.text(card, x_titre, y + 29, nom, 21, Charte.IVOIRE, 600, w - x_titre - 200, HORIZONTAL_ALIGNMENT_LEFT, true).name = "OfficeJournalTitre" + str(i + 1)
			var marque := R.pastille(card, x_titre + minf(_largeur(nom, 21, C.BODY), w - x_titre - 200) + 16, y + 29, "✚ %s sem." % blessure.get_string(2), R.ROUGE, "", "OfficeJournalBlessure" + str(i + 1))
			var blesses := names_in(app.model, nom)
			if not blesses.is_empty() and blesses[0] is Dictionary and blesses[0].has("id"):
				var cible := {"kind": "player", "id": str(blesses[0].id)}
				if app.navigation_controller.entity_available(cible):
					R.cliquable(marque, func(): app.navigation_controller.open_entity(cible), "OfficeJournalBlessureOuvrir" + str(i + 1), "Fiche de " + nom)
			noms_cliquables(app, card, Rect2(x_titre, y + 8, w - x_titre - 200, 30), nom, 21, C.BODY)
			continue
		D.text(card, x_titre, y + 29, titre, 21, Charte.IVOIRE, 600, w - x_titre - reserve, HORIZONTAL_ALIGNMENT_LEFT, true).name = "OfficeJournalTitre" + str(i + 1)
		noms_cliquables(app, card, Rect2(x_titre, y + 8, w - x_titre - reserve, 30), titre, 21, C.BODY)

## Vignette cliquable du XV (équipe-type de la journée ou de la saison) d'une lettre du courrier ; null si la lettre n'en est pas une.
static func _vignette_xv(app: Control, message: String, zone: Rect2) -> Button:
	if not message.begins_with("XV de ") or not EquipeType.disponible(app.model): return null
	var saison := message.begins_with("XV de la saison")
	var ligues: Array = NotesMatch.bilan(app.model).get("equipeType", {}).get("ligues", [])
	var cible: Dictionary = ligues[0] if not ligues.is_empty() else {}
	var equipe: Variant = cible.get("saison" if saison else "journee")
	if not equipe is Dictionary: return null
	var vignette: Button = EquipeType.vignette(equipe, Rect2(0, 0, zone.size.x, zone.size.y), func(): EquipeType.ouvrir(app, str(cible.get("id", "")), "saison" if saison else "journee"))
	D.place(vignette, zone)
	return vignette

# ---------------------------------------------------------------------------------------------------------
# Prochains matchs (colonne de Gabi ; la colonne reste la même sans Gabi)
# ---------------------------------------------------------------------------------------------------------

## Trois prochains matchs : date, adversaire (blason et nom ouvrent le club), terrain, journée ; la ligne
## ouvre l'avant-match (le prochain) ou le calendrier du jour. `recent` : gardé pour la signature historique.
static func _timeline(card: Panel, app: Control, _recent: Variant, w: int = GABI_WIDTH) -> Callable:
	_titre(card, "PROCHAINS MATCHS")
	_lien(card, w - 20, 12, "Tout le calendrier →", func(): app._navigate("Calendrier"), "OfficeCalendarAction", 20, true)
	var fixtures := Office.upcoming_matches(app.model).slice(0, 3)
	if fixtures.is_empty():
		D.text(card, 25, 100, "Aucune rencontre programmée pour le moment.", 21, Charte.IVOIRE_2, 500, w - 50, HORIZONTAL_ALIGNMENT_LEFT, true)
	for i in fixtures.size():
		var fixture: Dictionary = fixtures[i]
		var y := 62 + i * 42
		var chez_nous: bool = fixture.get("home", {}).get("id") == app.model.club.id
		var adversaire: Dictionary = fixture.get("away", {}) if chez_nous else fixture.get("home", {})
		var lieu := P.fixture_location_kind(fixture, app.model.club.id)
		var mot: String = {"neutral": "Neutre", "home": "Domicile", "away": "Extérieur"}.get(lieu, "Terrain à confirmer")
		var cle := str(fixture.get("id", fixture.get("date", ""))).validate_node_name()
		if i > 0: D.line(card, Vector2(12, y), Vector2(w - 12, y), Charte.FILET)
		var cible := {"kind": "date", "id": fixture.get("date")}
		var ligne: Callable = func():
			if i == 0 and app.model.get("next") is Dictionary and not app.model.next.is_empty(): app._navigate("Préparation")
			elif Office.reading_available(app, cible): app.navigation_controller.open_entity(cible)
			else: app._navigate("Calendrier")
		var tuile := _zone(card, Rect2(12, y, w - 24, 40), "", ligne, "OfficeTimelineTile" + str(i), 20)
		tuile.tooltip_text = ("Préparer le match · " if i == 0 else "Ouvrir le calendrier · ") + Office.timeline_period(fixture)
		tuile.accessibility_name = tuile.tooltip_text
		var date := D.text(card, 26, y + 29, Office.timeline_period(fixture), 19, Charte.IVOIRE, 600, 220)
		date.name = "OfficeTimelineDate%d" % i
		var local := P.fixture_date(fixture, true)
		if not local.is_empty(): Office.describe_fixture(date, local)
		_label_reading(app, card, date, Office.date_reading_target(app, fixture), "OfficeTimelineDateLink_" + cle, date.text)
		var ecusson := Office.opponent_crest(adversaire, 28)
		ecusson.name += str(i)
		card.add_child(ecusson)
		D.place(ecusson, Rect2(262, y + 8, 28, 28))
		Office.reading_overlay(app, card, Rect2(262, y + 8, 28, 28), Office.club_reading_target(app, adversaire), "OfficeTimelineClubCrest_" + cle, G.club_name(adversaire))
		var nom := D.text(card, 300, y + 29, G.club_name(adversaire), 20, Charte.IVOIRE, 600, w - 300 - 190)
		Office.describe_fixture(nom, nom.text + " · " + mot)
		_label_reading(app, card, nom, Office.club_reading_target(app, adversaire), "OfficeTimelineClubName_" + cle, nom.text)
		var marque := C.icon(C.fixture_location_icon(lieu, true), 22, Charte.IVOIRE_2)
		marque.name = "OfficeVenueIcon%d" % i
		card.add_child(marque)
		D.place(marque, Rect2(w - 176, y + 11, 22, 22))
		D.text(card, w - 146, y + 29, mot, 18, Charte.IVOIRE_2, 500, 90, HORIZONTAL_ALIGNMENT_LEFT, true)
		var etape := Office.short_fixture_label(app.model, fixture).get_slice(" · ", 1)
		if etape.is_empty(): etape = Office.short_fixture_label(app.model, fixture)
		D.text(card, w - 24, y + 29, etape.left(8), 18, Charte.IVOIRE_2, 500, 60, HORIZONTAL_ALIGNMENT_RIGHT, true)
	return Callable()
