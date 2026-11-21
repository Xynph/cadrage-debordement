extends RefCounted
## Mini-carte club au survol d'un écusson (planche de Léo du 21/11/2026) : rang, forme (5 derniers résultats en
## pastilles V/N/D), prochain match. Le clic sur l'écusson garde son effet (fiche du club).
## ECUSSON_A : carte compacte horizontale ; ECUSSON_B : carte verticale, grand écusson.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Charte = preload("res://ui/charte.gd")
const Bulle = preload("res://ui/bulle_survol.gd")
const Rebours = preload("res://ui/rebours_match.gd")
## Résultats : couleur franche + lettre (la couleur ne porte jamais seule le signal).
const TEINTES := {"V": Charte.GAIN, "N": Charte.GRIS_VERT, "D": Charte.PERTE}

static func active() -> bool:
	return Bulle.active("ECUSSON")

## Branche la mini-carte sur un écusson (sans effet hors variante ECUSSON_*).
## Le jeu (porteur du modèle) est retrouvé à l'apparition : l'écusson n'a pas besoin de le connaître.
static func lier(ecusson: Control, club: Dictionary) -> void:
	if not active() or club.is_empty() or not club.has("id"): return
	var id := str(club.get("id"))
	Bulle.lier(ecusson, "club:" + id, func(): return construire(Bulle.hote(ecusson), id))

## Ligne du classement du club (rang, points, forme) lue dans tous les championnats publiés.
static func ligne(model: Dictionary, id: String) -> Dictionary:
	var sources: Array = []
	if model.get("league") is Array: sources.append(model.league)
	if model.get("leagues") is Array:
		for l: Variant in model.leagues:
			if l is Dictionary and l.get("rows") is Array: sources.append(l.rows)
	for rows: Array in sources:
		for r: Variant in rows:
			if r is Dictionary and str(r.get("id", r.get("clubId", ""))) == id: return {"row": r, "total": rows.size()}
	return {}

## Prochaine rencontre du club connue du calendrier publié (le nôtre) : {adversaire, domicile, jours} ou {}.
static func prochain(model: Dictionary, id: String) -> Dictionary:
	var aujourd := str(model.get("meta", {}).get("calendarToday", ""))
	var meilleur: Dictionary = {}
	for f: Variant in model.get("calendar", []):
		if not f is Dictionary or f.get("played", false): continue
		var h: Dictionary = f.get("home", {}) if f.get("home") is Dictionary else {}
		var a: Dictionary = f.get("away", {}) if f.get("away") is Dictionary else {}
		if str(h.get("id", "")) != id and str(a.get("id", "")) != id: continue
		var j := Rebours.jours(aujourd, str(f.get("date", "")))
		if j < 0: continue
		if meilleur.is_empty() or j < int(meilleur.jours):
			var dom := str(h.get("id", "")) == id
			meilleur = {"adversaire": a if dom else h, "domicile": dom, "jours": j}
	return meilleur

static func construire(app: Control, id: String) -> Control:
	var model: Dictionary = app.model
	var trouve := ligne(model, id)
	var row: Dictionary = trouve.get("row", {})
	var club: Dictionary = row if not row.is_empty() else {"id": id}
	var suite := prochain(model, id)
	return _verticale(club, row, int(trouve.get("total", 0)), suite) if Bulle.variante() == "ECUSSON_B" else _horizontale(club, row, int(trouve.get("total", 0)), suite)

static func _fond(largeur: float, hauteur: float, club: Dictionary) -> Panel:
	var carte := Panel.new()
	var style := Charte.ombrer(Charte.style_panneau(Charte.PANNEAU, Charte.RAYON_CARTE, 0))
	carte.add_theme_stylebox_override("panel", style)
	carte.custom_minimum_size = Vector2(largeur, hauteur) * C.density
	carte.size = carte.custom_minimum_size
	carte.set_meta("club_id", str(club.get("id", "")))
	return carte

static func _anton(label: Label) -> Label:
	label.add_theme_font_override("font", Charte.TITRE_FICHE)
	return label

static func _rang(row: Dictionary) -> String:
	var r: Variant = row.get("rank")
	if r == null or not P.standings_open(row): return "–"
	return "1er" if int(r) == 1 else "%de" % int(r)

static func _forme(parent: Control, row: Dictionary, x: float, y: float, cote: float, ecart: float) -> float:
	var suite: Array = row.get("form", []) if row.get("form") is Array else []
	suite = suite.slice(-5)
	var largeur := 0.0
	for i in 5:
		var code := str(suite[i]) if i < suite.size() else ""
		var teinte: Color = TEINTES.get(code, Charte.PANNEAU_3)
		var p := D.rect(parent, Rect2(x + i * (cote + ecart), y, cote, cote), teinte, Charte.RAYON_PETIT)
		p.name = "CarteClubForme_%d" % i
		if not code.is_empty(): D.text(p, cote / 2.0, cote * 0.70, code, int(cote * 0.62), Charte.ENCRE, 800, cote, HORIZONTAL_ALIGNMENT_CENTER)
		largeur = (i + 1) * (cote + ecart) - ecart
	return largeur

## Pastille Dom. / Ext. (icône maison / route + mot).
static func _lieu(parent: Control, x: float, y: float, domicile: bool, taille: float = 18) -> float:
	var mot := "DOM." if domicile else "EXT."
	var largeur := 30.0 + taille * 2.6
	var fond := D.rect(parent, Rect2(x, y, largeur, taille * 1.7), Charte.VOILE_VERT if domicile else Charte.PANNEAU_3, Charte.RAYON_PILULE)
	fond.name = "CarteClubLieu"
	var icone := C.icon(C.fixture_location_icon("home" if domicile else "away", true), int(taille), Charte.VERT_CLAIR if domicile else Charte.IVOIRE_2)
	fond.add_child(icone)
	D.place(icone, Rect2(8, taille * 0.35, taille, taille))
	D.text(fond, 12 + taille, taille * 1.22, mot, int(taille), Charte.VERT_CLAIR if domicile else Charte.IVOIRE_2, 800, largeur - taille - 16)
	return largeur

static func _ecusson(parent: Control, club: Dictionary, zone: Rect2) -> void:
	var e := G.crest(club, C.px(minf(zone.size.x, zone.size.y)))
	parent.add_child(e)
	D.place(e, zone)

## A : carte compacte horizontale (600 × 172 au gabarit 2560).
static func _horizontale(club: Dictionary, row: Dictionary, total: int, suite: Dictionary) -> Control:
	var carte := _fond(600, 172, club)
	var liseré := D.rect(carte, Rect2(0, 18, 6, 136), Color(str(club.get("color", "#71322f"))), 3)
	liseré.name = "CarteClubLisere"
	_ecusson(carte, club, Rect2(22, 30, 104, 112))
	_anton(D.text(carte, 146, 46, G.club_name(club).to_upper(), 26, Charte.IVOIRE, 600, 270))
	var rang := D.text(carte, 146, 104, _rang(row), 46, Charte.IVOIRE, 800, 100)
	rang.add_theme_font_override("font", Charte.TITRE_EXTRA)
	rang.name = "CarteClubRang"
	var sur := "/ %d · %s pts" % [total, G.n(row.get("points", 0))] if total > 0 else ""
	D.text(carte, 236, 102, sur, 19, Charte.IVOIRE_2, 600, 170)
	_forme(carte, row, 146, 120, 32, 6)
	# Prochain match : écusson adverse, J-n, Dom./Ext.
	D.line(carte, Vector2(432, 22), Vector2(432, 150), Charte.FILET)
	if suite.is_empty():
		D.text(carte, 452, 98, "—", 30, Charte.IVOIRE_3, 700, 130, HORIZONTAL_ALIGNMENT_CENTER)
		return carte
	D.text(carte, 452, 44, "PROCHAIN", 14, Charte.IVOIRE_3, 700, 130)
	_ecusson(carte, suite.adversaire, Rect2(452, 58, 46, 50))
	var j := D.text(carte, 508, 96, Rebours.texte(int(suite.jours)), 30, Charte.IVOIRE, 800, 80)
	j.add_theme_font_override("font", Charte.TITRE_EXTRA)
	j.name = "CarteClubJours"
	_lieu(carte, 452, 118, bool(suite.domicile), 16)
	return carte

## B : carte verticale, grand écusson sur bandeau (320 × 452 au gabarit 2560).
static func _verticale(club: Dictionary, row: Dictionary, total: int, suite: Dictionary) -> Control:
	var carte := _fond(320, 452, club)
	var bandeau := D.rect(carte, Rect2(0, 0, 320, 150), Charte.PANNEAU_3, Charte.RAYON_CARTE)
	bandeau.name = "CarteClubBandeau"
	D.rect(carte, Rect2(0, 146, 320, 5), Color(str(club.get("color", "#71322f"))))
	_ecusson(carte, club, Rect2(100, 14, 120, 124))
	_anton(D.text(carte, 160, 194, G.club_name(club).to_upper(), 26, Charte.IVOIRE, 600, 292, HORIZONTAL_ALIGNMENT_CENTER))
	for i in 2:
		var tuile := D.rect(carte, Rect2(16 + i * 148, 212, 140, 92), Charte.PANNEAU_2, Charte.RAYON_CARTE)
		tuile.name = "CarteClubTuile_%d" % i
		D.text(tuile, 70, 26, ["RANG", "POINTS"][i], 14, Charte.IVOIRE_3, 700, 130, HORIZONTAL_ALIGNMENT_CENTER)
		var valeur := _rang(row) if i == 0 else G.n(row.get("points", 0))
		var chiffre := D.text(tuile, 70, 74, valeur, 42, Charte.IVOIRE, 800, 130, HORIZONTAL_ALIGNMENT_CENTER)
		chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA)
		if i == 0 and total > 0: D.text(tuile, 70, 88, "/ %d" % total, 13, Charte.IVOIRE_2, 600, 130, HORIZONTAL_ALIGNMENT_CENTER)
	_forme(carte, row, 30, 322, 46, 7)
	D.line(carte, Vector2(16, 388), Vector2(304, 388), Charte.FILET)
	if suite.is_empty():
		D.text(carte, 160, 428, "—", 26, Charte.IVOIRE_3, 700, 200, HORIZONTAL_ALIGNMENT_CENTER)
		return carte
	_ecusson(carte, suite.adversaire, Rect2(24, 398, 42, 46))
	var j := D.text(carte, 80, 436, Rebours.texte(int(suite.jours)), 32, Charte.IVOIRE, 800, 100)
	j.add_theme_font_override("font", Charte.TITRE_EXTRA)
	j.name = "CarteClubJours"
	_lieu(carte, 190, 404, bool(suite.domicile), 17)
	return carte
