extends RefCounted
## Compte à rebours du prochain match dans la barre du haut (planche de Léo du 21/11/2026) : écusson adverse + J-n,
## cliquable → avant-match (route « Match ») : écusson adverse, J-n (« AUJ. » le jour du match), pastille Dom./Ext.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const P = preload("res://ui/immersive08/projection.gd")
const Charte = preload("res://ui/charte.gd")
const PLEINE := 262.0
const COURTE := 194.0
const ECART := 20.0

## Jours entre deux dates « AAAA-MM-JJ » (-1 si illisibles).
static func jours(de: String, a: String) -> int:
	if de.length() < 10 or a.length() < 10: return -1
	var t0 := Time.get_unix_time_from_datetime_string(de.substr(0, 10) + "T12:00:00")
	var t1 := Time.get_unix_time_from_datetime_string(a.substr(0, 10) + "T12:00:00")
	return roundi((t1 - t0) / 86400.0)

## « J-2 », « AUJ. » le jour du match.
static func texte(n: int) -> String:
	return "AUJ." if n <= 0 else "J-%d" % n

## Prochain match du club : {adversaire, domicile, jours} ou {}.
static func prochain(model: Dictionary) -> Dictionary:
	var f := P.next_fixture(model)
	if f.is_empty(): return {}
	var nous := str(model.get("club", {}).get("id", ""))
	var h: Dictionary = f.get("home", {}) if f.get("home") is Dictionary else {}
	var a: Dictionary = f.get("away", {}) if f.get("away") is Dictionary else {}
	var dom := str(h.get("id", "")) == nous
	var n := jours(str(model.get("meta", {}).get("calendarToday", "")), str(f.get("date", "")))
	if n < 0: return {}
	return {"adversaire": a if dom else h, "domicile": dom, "jours": n}

## Pose le compte à rebours dans la barre (coordonnées de la barre, bord droit `droite`) ; renvoie la largeur prise
## (écart compris), 0 sans match à venir ou sur le Bureau.
## `place` : largeur disponible (écart compris) ; forme pleine (pastille DOM./EXT. avec le mot), forme courte
## (pastille icône seule) si elle manque, rien en dessous.
static func poser(barre: Control, app: Control, droite: float, hauteur: float, y: float, style: Callable, place: float = INF) -> float:
	# Le Bureau a déjà son bloc « Prochain match » ; l'avant-match et le direct sont la destination elle-même.
	if str(app.get("route")) in ["Bureau", "Match"]: return 0.0
	if app.has_method("_live") and not (app.call("_live") as Dictionary).is_empty(): return 0.0
	var suite := prochain(app.model)
	if suite.is_empty(): return 0.0
	var court := place < PLEINE + ECART
	if court and place < COURTE + ECART: return 0.0
	var largeur := COURTE if court else PLEINE
	var bouton: Button = style.call("ImmersiveMatchCountdown", true, Charte.RAYON_PILULE)
	bouton.accessibility_name = "Avant-match · %s · %s" % [texte(int(suite.jours)), G.club_name(suite.adversaire)]
	bouton.tooltip_text = bouton.accessibility_name
	bouton.pressed.connect(func(): app._navigate("Match"))
	barre.add_child(bouton)
	D.place(bouton, Rect2(droite - largeur, y, largeur, hauteur))
	_ecusson(bouton, suite.adversaire, Rect2(10, (hauteur - 40) / 2.0, 40, 40))
	var j := D.text(bouton, 58, hauteur / 2.0 + 11, texte(int(suite.jours)), 32, Charte.IVOIRE, 800, 80)
	j.add_theme_font_override("font", Charte.TITRE_EXTRA)
	j.name = "ReboursJours"
	var dom := bool(suite.domicile)
	var pastille := D.rect(bouton, Rect2(140, (hauteur - 30) / 2.0, 42 if court else 110, 30), Charte.VOILE_VERT if dom else Charte.PANNEAU_3, Charte.RAYON_PILULE)
	pastille.name = "ReboursLieu"
	var icone := C.icon(C.fixture_location_icon("home" if dom else "away", true), 18, Charte.VERT_CLAIR if dom else Charte.IVOIRE_2)
	pastille.add_child(icone)
	D.place(icone, Rect2(12, 6, 18, 18))
	# Mot à 18 au gabarit 2560 : jamais sous le plancher de 12 px réels.
	if not court: D.text(pastille, 36, 21, "DOM." if dom else "EXT.", 18, Charte.VERT_CLAIR if dom else Charte.IVOIRE_2, 800, 66)
	for n: Node in bouton.find_children("*", "Control", true, false): (n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return largeur + ECART

static func _ecusson(parent: Control, club: Dictionary, zone: Rect2) -> void:
	var e := G.crest(club, C.px(minf(zone.size.x, zone.size.y)))
	parent.add_child(e)
	D.place(e, zone)
