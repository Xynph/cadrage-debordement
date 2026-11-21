extends RefCounted
## Petite fenêtre « Compétition junior » du Centre (décision de Léo du 21/11/2026 : chaque carte mène quelque part).
## Crabos et Espoirs côte à côte, avec les vrais matchs des jeunes du moteur (clubLife.youthMatches) : bilan en tuiles,
## cinq derniers résultats en cases colorées (lettre + score), rang au classement, prochain match ; pastille vers
## Suivi des jeunes. Échap, ✕ ou clic à côté la ferment.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const Pieces = preload("res://ui/immersive08/petites_pieces.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")

const NOM := "CentreJuniorsFenetre"
const LARGEUR := 1060.0
const HAUTEUR := 640.0
const CATEGORIES := [["Crabos", "crabos", "CentreJuniorsCrabos"], ["Espoirs", "espoirs", "CentreJuniorsEspoirs"]]

static func ouvrir(app: Control, page: Control) -> void:
	var ancienne := page.find_child(NOM, false, false)
	if ancienne != null:
		ancienne.name = NOM + "Fermee"
		ancienne.remove_from_group(PetiteFenetre.GROUPE)
		ancienne.queue_free()
	var donnees: Dictionary = app.model.get("clubLife", {}).get("youthMatches", {})
	var calque := Control.new()
	calque.name = NOM
	page.add_child(calque)
	D.place(calque, Rect2(0, 0, 2248, 1230))
	var fermer := func():
		if is_instance_valid(calque): calque.queue_free()
	PetiteFenetre.enregistrer(calque, fermer)
	var refermer := func(): PetiteFenetre.fermer_derniere(calque.get_tree())
	var voile := Button.new()
	voile.name = NOM + "Voile"
	voile.focus_mode = Control.FOCUS_NONE
	for etat: String in ["normal", "hover", "pressed"]:
		var fond_voile := StyleBoxFlat.new()
		fond_voile.bg_color = Color(Charte.NUIT, .45)
		voile.add_theme_stylebox_override(etat, fond_voile)
	voile.pressed.connect(refermer)
	calque.add_child(voile)
	D.place(voile, Rect2(0, 0, 2248, 1230))
	var fond := D.rect(calque, Rect2((2248 - LARGEUR) / 2.0, 250, LARGEUR, HAUTEUR), Charte.PANNEAU, Charte.RAYON_PANNEAU)
	fond.name = NOM + "Panneau"
	fond.mouse_filter = Control.MOUSE_FILTER_STOP
	var icone := C.icon("trophy", 30, Charte.DORE)
	fond.add_child(icone)
	D.place(icone, Rect2(28, 26, 30, 30))
	var titre := D.text(fond, 70, 52, "COMPÉTITION JUNIOR", 30, Charte.IVOIRE, 800, 600)
	titre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	var croix := Button.new()
	croix.name = NOM + "Fermer"
	croix.text = "✕"
	croix.flat = true
	croix.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	croix.add_theme_font_size_override("font_size", maxi(12, C.px(24)))
	croix.add_theme_color_override("font_color", Charte.IVOIRE_2)
	croix.accessibility_name = "Fermer"
	croix.pressed.connect(refermer)
	fond.add_child(croix)
	D.place(croix, Rect2(LARGEUR - 62, 18, 44, 44))
	var colonne := (LARGEUR - 28.0 * 2.0 - 32.0) / 2.0
	for i in CATEGORIES.size():
		var cat: Array = CATEGORIES[i]
		_colonne(fond, Rect2(28 + i * (colonne + 32.0), 84, colonne, 470), donnees, cat)
	var aller := func():
		PetiteFenetre.fermer_derniere(calque.get_tree())
		app._navigate("Suivi des jeunes")
	Pieces.pastille(fond, 28, HAUTEUR - 64, "Suivi des jeunes", "people", NOM + "Suivi", "", Charte.IVOIRE, Charte.PANNEAU_3, aller)
	croix.grab_focus.call_deferred()

static func _colonne(parent: Control, zone: Rect2, donnees: Dictionary, cat: Array) -> void:
	var boite := D.rect(parent, zone, Charte.PANNEAU_2, Charte.RAYON_CARTE)
	boite.name = str(cat[2])
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var w := zone.size.x
	D.text(boite, 22, 44, str(cat[0]).to_upper(), 28, Charte.DORE, 800, w - 44).add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	var resultats: Array = donnees.get("results", {}).get(str(cat[1]), [])
	var bilan := [0, 0, 0]
	for r: Dictionary in resultats:
		var pour := int(r.get("for", 0))
		var contre := int(r.get("against", 0))
		bilan[0 if pour > contre else 1 if pour == contre else 2] += 1
	var vide := resultats.is_empty()
	var tuile := (w - 44.0 - 20.0) / 3.0
	Pieces.tuile(boite, Rect2(22, 64, tuile, 84), "—" if vide else "▲ %d" % bilan[0], "victoires", Charte.VERT_CLAIR, boite.name + "Victoires", 32)
	Pieces.tuile(boite, Rect2(32 + tuile, 64, tuile, 84), "—" if vide else "= %d" % bilan[1], "nuls", Charte.IVOIRE, boite.name + "Nuls", 32)
	Pieces.tuile(boite, Rect2(42 + tuile * 2, 64, tuile, 84), "—" if vide else "▼ %d" % bilan[2], "défaites", Charte.PERTE, boite.name + "Defaites", 32)
	# Cinq derniers résultats, du plus ancien au plus récent : lettre (forme du signal) + score.
	var derniers := resultats.slice(maxi(0, resultats.size() - 5))
	var case_l := (w - 44.0 - 4 * 10.0) / 5.0
	for j in 5:
		var x := 22 + j * (case_l + 10.0)
		if j >= derniers.size():
			D.rect(boite, Rect2(x, 166, case_l, 100), Charte.PANNEAU_3, 6).mouse_filter = Control.MOUSE_FILTER_IGNORE
			continue
		var r: Dictionary = derniers[j]
		var pour := int(r.get("for", 0))
		var contre := int(r.get("against", 0))
		var couleur: Color = Charte.VERT_CLAIR if pour > contre else Charte.PERTE if pour < contre else Charte.IVOIRE_2
		var case_r := D.rect(boite, Rect2(x, 166, case_l, 100), Charte.PANNEAU_3.lerp(couleur, .22), 6)
		case_r.name = "%sResultat%d" % [boite.name, j]
		case_r.mouse_filter = Control.MOUSE_FILTER_STOP
		case_r.tooltip_text = "%s · %s" % [str(r.get("opponent", "")), str(r.get("competition", ""))]
		var lettre := D.text(case_r, case_l / 2.0, 52, "V" if pour > contre else "D" if pour < contre else "N", 36, couleur, 800, case_l, HORIZONTAL_ALIGNMENT_CENTER)
		lettre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
		lettre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		D.text(case_r, case_l / 2.0, 86, "%d-%d" % [pour, contre], 19, Charte.IVOIRE, 700, case_l, HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rang := _rang(donnees, str(cat[0]))
	Pieces.tuile(boite, Rect2(22, 286, w - 44, 84), "—" if rang.is_empty() else "%de" % int(rang.rang), "classement" if rang.is_empty() else str(rang.competition), Charte.IVOIRE, boite.name + "Rang", 32, "", "trophy")
	var prochain := _prochain(donnees, str(cat[0]))
	Pieces.pastille(boite, 22, 398, "—" if prochain.is_empty() else _date(str(prochain.date)), "calendar", boite.name + "Prochain", "" if prochain.is_empty() else str(prochain.competition), Charte.IVOIRE_2)

static func _rang(donnees: Dictionary, categorie: String) -> Dictionary:
	for competition: Dictionary in donnees.get("competitions", []):
		if str(competition.get("category", "")) != categorie: continue
		for table: Dictionary in competition.get("tables", []):
			var lignes: Array = table.get("rows", [])
			for k in lignes.size():
				if lignes[k].get("own", false): return {"rang": k + 1, "competition": str(competition.get("name", ""))}
	return {}

static func _prochain(donnees: Dictionary, categorie: String) -> Dictionary:
	for match_jeune: Dictionary in donnees.get("upcoming", []):
		if str(match_jeune.get("category", "")) == categorie: return match_jeune
	return {}

static func _date(iso: String) -> String:
	var morceaux := iso.split("-")
	return "%s/%s" % [morceaux[2], morceaux[1]] if morceaux.size() == 3 else iso
