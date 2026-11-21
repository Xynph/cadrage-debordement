extends RefCounted
## Mini-courbe d'évolution au survol d'un chiffre (planche de Léo du 21/11/2026), sans clic ; le clic garde son effet.
## Séries gardées par le moteur : trésorerie (finance.cashHistory, un relevé par semaine jouée, 70 semaines).
## Le moral et la condition ne sont pas historisés : pas de bulle sur ces chiffres tant que le moteur ne les garde pas.
## COURBE_A : courbe remplie dans une bulle ; COURBE_B : mini-histogramme des variations par semaine.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Bulle = preload("res://ui/bulle_survol.gd")
const SEMAINES := 10
const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]

static func active() -> bool:
	return Bulle.active("COURBE")

## Série [{date, valeur}] du chiffre `cle` (« cash »), les SEMAINES derniers relevés ; [] si le moteur ne la garde pas.
static func serie(model: Dictionary, cle: String) -> Array:
	var sortie: Array = []
	if cle == "cash":
		var h: Variant = model.get("finance", {}).get("cashHistory", [])
		if h is Array:
			for r: Variant in (h as Array).slice(-SEMAINES):
				if r is Dictionary and r.get("cash") != null: sortie.append({"date": str(r.get("date", "")), "valeur": float(r.cash)})
	return sortie

static func lier(app: Control, controle: Control, cle: String, titre: String) -> void:
	if not active() or not is_instance_valid(controle): return
	if serie(app.model, cle).size() < 2: return
	Bulle.lier(controle, "courbe:" + cle, func(): return construire(app, cle, titre))

static func euros_courts(v: float, signe: bool = false) -> String:
	var prefixe := ("+" if v > 0 else "−" if v < 0 else "") if signe else ("−" if v < 0 else "")
	var a := absf(v)
	if a >= 1_000_000.0: return prefixe + ("%.2f M€" % (a / 1_000_000.0)).replace(".", ",")
	if a >= 1000.0: return prefixe + "%d k€" % roundi(a / 1000.0)
	return prefixe + "%d €" % roundi(a)

static func date_courte(date: String) -> String:
	var p := date.split("-")
	if p.size() < 3 or not p[1].is_valid_int(): return date
	return "%d %s" % [int(p[2].substr(0, 2)), MOIS[clampi(int(p[1]) - 1, 0, 11)]]

static func construire(app: Control, cle: String, titre: String) -> Control:
	var s := serie(app.model, cle)
	var histogramme := Bulle.variante() == "COURBE_B"
	var largeur := 470.0
	var hauteur := 268.0
	var bulle := Panel.new()
	bulle.add_theme_stylebox_override("panel", Charte.ombrer(Charte.style_panneau(Charte.PANNEAU, Charte.RAYON_CARTE, 0)))
	bulle.custom_minimum_size = Vector2(largeur, hauteur) * C.density
	bulle.size = bulle.custom_minimum_size
	var premier := float(s[0].valeur)
	var dernier := float(s[-1].valeur)
	var ecart := dernier - premier
	var teinte := Charte.GAIN if ecart >= 0.0 else Charte.PERTE
	D.text(bulle, 22, 34, titre.to_upper(), 15, Charte.IVOIRE_3, 700, 200)
	var chiffre := D.text(bulle, 22, 82, euros_courts(dernier), 40, Charte.IVOIRE, 800, 230)
	chiffre.add_theme_font_override("font", Charte.TITRE_EXTRA)
	chiffre.name = "MiniCourbeValeur"
	# Écart sur la période : flèche (forme) + couleur + montant.
	var mot := ("▲ " if ecart >= 0.0 else "▼ ") + euros_courts(ecart, true)
	var pastille := D.rect(bulle, Rect2(largeur - 190, 46, 168, 36), Charte.VOILE_VERT if ecart >= 0.0 else Color(Charte.PERTE, 0.16), Charte.RAYON_PILULE)
	pastille.name = "MiniCourbeEcart"
	D.text(pastille, 84, 25, mot, 19, teinte, 800, 160, HORIZONTAL_ALIGNMENT_CENTER)
	D.text(bulle, largeur - 22, 34, "%d SEM." % s.size(), 14, Charte.IVOIRE_3, 700, 120, HORIZONTAL_ALIGNMENT_RIGHT)
	var trace := Trace.new()
	trace.name = "MiniCourbeTrace"
	trace.histogramme = histogramme
	trace.teinte = teinte
	var valeurs: Array[float] = []
	for r: Dictionary in s: valeurs.append(float(r.valeur))
	trace.valeurs = valeurs
	bulle.add_child(trace)
	D.place(trace, Rect2(22, 100, largeur - 44, 128))
	D.text(bulle, 22, 254, date_courte(str(s[0].date)), 14, Charte.IVOIRE_3, 600, 120)
	D.text(bulle, largeur - 22, 254, date_courte(str(s[-1].date)), 14, Charte.IVOIRE_3, 600, 120, HORIZONTAL_ALIGNMENT_RIGHT)
	return bulle

## A : courbe remplie (aire translucide + trait + point final) ; B : barres des variations semaine par semaine
## autour d'un axe zéro (vert au-dessus, rouge en dessous).
class Trace extends Control:
	const Charte = preload("res://ui/charte.gd")
	var valeurs: Array[float] = []
	var histogramme := false
	var teinte := Color.WHITE

	func _draw() -> void:
		if valeurs.size() < 2: return
		var w := size.x
		var h := size.y
		if histogramme:
			var deltas: Array[float] = []
			for i in range(1, valeurs.size()): deltas.append(valeurs[i] - valeurs[i - 1])
			var m := 1.0
			for d in deltas: m = maxf(m, absf(d))
			var zero := h / 2.0
			draw_line(Vector2(0, zero), Vector2(w, zero), Charte.FILET, 2.0)
			var pas := w / deltas.size()
			for i in deltas.size():
				var d := deltas[i]
				var haut := absf(d) / m * (h / 2.0 - 4.0)
				var x := pas * i + pas * 0.18
				var r := Rect2(x, zero - haut if d >= 0 else zero, pas * 0.64, maxf(2.0, haut))
				draw_rect(r, Charte.GAIN if d >= 0 else Charte.PERTE)
			return
		var mini: float = valeurs.min()
		var maxi: float = valeurs.max()
		var etendue := maxf(1.0, maxi - mini)
		var points := PackedVector2Array()
		for i in valeurs.size():
			points.append(Vector2(w * i / (valeurs.size() - 1), 6.0 + (h - 12.0) * (1.0 - (valeurs[i] - mini) / etendue)))
		var aire := points.duplicate()
		aire.append(Vector2(w, h))
		aire.append(Vector2(0, h))
		draw_colored_polygon(aire, Color(teinte, 0.22))
		draw_line(Vector2(0, h), Vector2(w, h), Charte.FILET, 2.0)
		draw_polyline(points, teinte, 3.0, true)
		draw_circle(points[-1], 6.0, teinte)
		draw_circle(points[-1], 3.0, Charte.PANNEAU)
