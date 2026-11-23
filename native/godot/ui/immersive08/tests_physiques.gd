extends RefCounted
## Tests physiques avant le match (revue FM27, idée 36 ; choix A de Léo du 23/11/2026) : sous-page de l'avant-match, liste
## façon Effectif (visage, blessure, corps face / dos avec la zone, résultat du test, minutes conseillées sur 80′, forme),
## ouverte depuis la tuile « Ta feuille » (match_avant.gd) et depuis le message du médecin en Réception (bloc_mail).
## Données du moteur (native/engine/tests-physiques.cjs, clubLife.testsPhysiques.tests) : joueurs revenus de blessure,
## test réussi ou échoué, minutes conseillées par le médecin (son estimation, jamais la vraie limite). Un clic sur une
## ligne ouvre la fiche du joueur sur son onglet Blessures.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Charte = preload("res://ui/charte.gd")
const Panneaux = preload("res://ui/immersive08/panneaux_effectif.gd")
const Blessure = preload("res://ui/immersive08/fenetre_blessure.gd")
const ClubMail = preload("res://ui/club_mail.gd")

const PAGE := "tests"
const TYPE_MAIL := "tests_reprise"
## Onglet Blessures de la fiche joueur (player_canvas.gd).
const ONGLET_FICHE := 6
const LARGEUR := 2000.0
const LIGNE := 118.0
## Résultats : ok → [mot, couleur, icône].
const RESULTATS := {true: ["Réussi", R.VERT, "check"], false: ["Échoué", R.ROUGE, "warning"]}

static func _n(v: Variant, d: float = -1.0) -> float:
	return float(v) if (v is int or v is float) and is_finite(float(v)) else d

static func _jj_mm(iso: String) -> String:
	return "%s/%s" % [iso.substr(8, 2), iso.substr(5, 2)] if iso.length() >= 10 else ""

static func _joueur(model: Dictionary, id: String) -> Dictionary:
	for p: Variant in model.get("squad", []):
		if p is Dictionary and str(p.get("id", "")) == id: return p
	return {}

## Tests du moteur pour la prochaine rencontre ({} sans tests).
static func donnees(model: Dictionary) -> Dictionary:
	var t: Variant = model.get("clubLife", {}).get("testsPhysiques", {})
	if not t is Dictionary: return {}
	var tests: Variant = t.get("tests")
	return tests if tests is Dictionary and tests.get("joueurs") is Array and not tests.joueurs.is_empty() else {}

## Lignes affichées : [{j, ok, minutes, type, semaines, retour, libelle, droite}], joueurs de l'effectif seulement.
static func lignes(model: Dictionary) -> Array:
	var out: Array = []
	var tests := donnees(model)
	if tests.is_empty(): return out
	for x: Variant in tests.joueurs:
		if not x is Dictionary: continue
		var j := _joueur(model, str(x.get("id", "")))
		if j.is_empty(): continue
		var type := str(x.get("type", "")) if x.get("type") is String else ""
		out.append({"j": j, "ok": bool(x.get("ok", false)), "minutes": int(_n(x.get("minutes"), 0.0)), "type": type,
			"semaines": int(_n(x.get("semaines"), 1.0)), "retour": str(x.get("retour", "")),
			"libelle": ClubMail.injury_label(model, {"injuryType": type}) if not type.is_empty() else "Blessure",
			"droite": hash(str(j.get("id", "")) + ":cote") % 2 == 0})
	return out

static func mot_minutes(minutes: int) -> String:
	if minutes <= 0: return "Ne pas aligner"
	if minutes >= 80: return "Match entier"
	return "%d′ max" % minutes

static func couleur_minutes(minutes: int) -> Color:
	return R.ROUGE if minutes < 30 else R.VERT if minutes >= 60 else R.ORANGE

## Entrée depuis la tuile « Ta feuille » : lien avec le nombre de joueurs testés et d'échecs.
static func lien(avant: Control, model: Dictionary) -> Array:
	var ls := lignes(model)
	if ls.is_empty(): return []
	var echecs := ls.filter(func(c: Dictionary) -> bool: return not c.ok).size()
	var texte := "Tests physiques · %d%s →" % [ls.size(), (" · %d échec%s" % [echecs, "s" if echecs > 1 else ""]) if echecs > 0 else ""]
	return [texte, func(): avant.ouvrir_page(PAGE), "MatchTestsPhysiques", "Résultats des tests physiques"]

static func ouvrir_fiche(app: Control, id: String) -> void:
	if id.is_empty(): return
	app.management_ui["immersive_player_tab"] = ONGLET_FICHE
	app.navigation_controller.open_entity({"kind": "player", "id": id})

## Corps face et dos, zone touchée en halo (dessin de la fenêtre blessure).
static func corps(parent: Control, rect: Rect2, type: String, droite: bool, nom: String) -> void:
	var largeur := rect.size.x / 2.0 - 4.0
	for i in 2:
		var vue := "F" if i == 0 else "B"
		var s := Blessure.Silhouette.new()
		s.name = nom + vue
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.dessin = Blessure.texture(vue)
		s.point = Blessure.point_zone(type, droite, vue) if not type.is_empty() else Vector2(-1, -1)
		s.rayon = float(Blessure.ZONES.get(type, {}).get("r", 0.0))
		parent.add_child(s)
		D.place(s, Rect2(rect.position.x + i * (largeur + 8.0), rect.position.y, largeur, rect.size.y))

## Barre des minutes conseillées sur 80′ (repères 40 et 60), mot à droite.
static func barre_minutes(parent: Control, x: float, y: float, longueur: float, minutes: int, nom: String) -> void:
	D.rect(parent, Rect2(x, y, longueur, 18), Charte.PANNEAU_3, 4).mouse_filter = Control.MOUSE_FILTER_IGNORE
	if minutes > 0:
		var part := D.rect(parent, Rect2(x, y, longueur * float(minutes) / 80.0, 18), couleur_minutes(minutes), 4)
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		part.name = nom + "Barre"
	for m in [40, 60]: D.line(parent, Vector2(x + longueur * m / 80.0, y - 6), Vector2(x + longueur * m / 80.0, y + 24), Charte.IVOIRE_3, 2)
	D.text(parent, x, y + 50, "0′", 16, Charte.IVOIRE_3, 600, 40)
	D.text(parent, x + longueur - 26, y + 50, "80′", 16, Charte.IVOIRE_3, 600, 40)
	D.text(parent, x + longueur + 20, y + 18, mot_minutes(minutes), 22, couleur_minutes(minutes), 700, 180).name = nom + "Mot"

# ------------------------------------------------------------------ sous-page de l'avant-match

static func page(avant: Control, app: Control, model: Dictionary) -> Control:
	var zone := MarginContainer.new()
	zone.name = "MatchPage"
	C.fill(zone, true)
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right"]: zone.add_theme_constant_override("margin_" + edge, avant.M(32))
	zone.add_theme_constant_override("margin_top", avant.M(20))
	zone.add_theme_constant_override("margin_bottom", avant.M(8))
	var ls := lignes(model)
	var cadre := Panel.new()
	cadre.name = "TestsPhysiquesPage"
	var st := StyleBoxFlat.new()
	st.bg_color = Color(Charte.PANNEAU, .96)
	st.set_corner_radius_all(Charte.RAYON_PANNEAU)
	cadre.add_theme_stylebox_override("panel", Charte.ombrer(st))
	cadre.custom_minimum_size = Vector2(LARGEUR, 190.0 + LIGNE * ls.size() + 20.0) * C.density
	cadre.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cadre.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	zone.add_child(cadre)
	var titre := D.text(cadre, 36, 62, "TESTS PHYSIQUES", 40, Charte.IVOIRE, 700, 600)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	var x := 470.0
	for ok: bool in [true, false]:
		var n := ls.filter(func(c: Dictionary) -> bool: return c.ok == ok).size()
		if n == 0: continue
		var p := R.pastille(cadre, x, 60, "%d %s" % [n, str(RESULTATS[ok][0]).to_lower() + ("s" if n > 1 else "")], RESULTATS[ok][1], RESULTATS[ok][2], "TestsPhysiquesCompte_" + ("reussi" if ok else "echec"), 22)
		x += p.size.x / C.density + 14.0
	var tests := donnees(model)
	var adv := str(tests.get("adversaire", "")) if tests.get("adversaire") is String else ""
	var medecin := str(tests.get("medecin", "")) if tests.get("medecin") is String else ""
	var droite := ("%s · %s" % [adv, _jj_mm(str(tests.get("date", "")))]) if not adv.is_empty() else _jj_mm(str(tests.get("date", "")))
	if not medecin.is_empty(): droite += "  ·  Dr " + medecin
	D.text(cadre, LARGEUR - 836, 60, droite, 20, Charte.IVOIRE_2, 600, 800, HORIZONTAL_ALIGNMENT_RIGHT).name = "TestsPhysiquesRencontre"
	var cols := [[36, "JOUEUR"], [500, "BLESSURE"], [930, "CORPS"], [1100, "TEST"], [1320, "MINUTES CONSEILLÉES"], [1800, "FORME"]]
	D.rect(cadre, Rect2(20, 102, LARGEUR - 40, 46), Charte.BANDEAU_ENTETE, 6)
	for col: Array in cols: D.text(cadre, float(col[0]), 133, str(col[1]), 17, Charte.IVOIRE_3, 700, 360)
	var y := 160.0
	var i := 0
	for c: Dictionary in ls:
		i += 1
		_ligne(cadre, app, c, Rect2(20, y, LARGEUR - 40, LIGNE), i)
		y += LIGNE
	return zone

static func _ligne(cadre: Control, app: Control, c: Dictionary, rect: Rect2, i: int) -> void:
	var j: Dictionary = c.j
	var ligne := Control.new()
	ligne.name = "TestsPhysiquesLigne%d" % i
	ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ligne.set_meta("player_id", str(j.get("id", "")))
	cadre.add_child(ligne)
	D.place(ligne, rect)
	if i % 2 == 0: D.rect(ligne, Rect2(0, 0, rect.size.x, rect.size.y), Charte.PANNEAU_2, 6).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var id := str(j.get("id", ""))
	Panneaux._bouton(ligne, Rect2(0, 0, rect.size.x, rect.size.y), func(): ouvrir_fiche(app, id), "TestsPhysiquesOuvrir%d" % i, str(j.get("name", "")))
	var res: Array = RESULTATS[bool(c.ok)]
	Panneaux._portrait(ligne, j, Rect2(16, 16, 84, 84), res[1], 3)
	D.text(ligne, 118, 52, str(j.get("name", "")), 26, Charte.IVOIRE, 700, 360).name = "TestsPhysiquesNom%d" % i
	D.text(ligne, 118, 86, str(j.get("pos", "")), 20, Charte.IVOIRE_2, 600, 360)
	D.text(ligne, 480, 52, str(c.libelle), 22, R.ROUGE, 700, 400).name = "TestsPhysiquesBlessure%d" % i
	D.text(ligne, 480, 86, "%d sem. · retour %s" % [int(c.semaines), _jj_mm(str(c.retour))], 20, Charte.IVOIRE_2, 600, 400)
	corps(ligne, Rect2(910, 8, 120, rect.size.y - 16), str(c.type), bool(c.droite), "TestsPhysiquesCorps%d" % i)
	R.pastille(ligne, 1080, 70, str(res[0]), res[1], res[2], "TestsPhysiquesTest%d" % i, 22)
	barre_minutes(ligne, 1300.0, 50.0, 220.0, int(c.minutes), "TestsPhysiquesMinutes%d" % i)
	var cond := _n(j.get("condition"))
	D.text(ligne, 1780, 70, "%d %%" % roundi(cond) if cond >= 0 else "?", 26, Charte.couleur_attribut(cond), 700, 110)
	D.line(ligne, Vector2(0, rect.size.y - 1), Vector2(rect.size.x, rect.size.y - 1), Charte.FILET, 1)

# ------------------------------------------------------------------ message du médecin (Réception)

## Liste des tests sous la lettre du médecin (courrier `tests_reprise` de la rencontre en cours), ou null.
static func bloc_mail(app: Control, mail: Dictionary, largeur: float) -> Control:
	if str(mail.get("type", "")) != TYPE_MAIL: return null
	var tests := donnees(app.model)
	if tests.is_empty(): return null
	var ls := lignes(app.model)
	if ls.is_empty(): return null
	var hauteur_ligne := 96.0
	var racine := Panel.new()
	racine.name = "TestsPhysiquesMail"
	var st := StyleBoxFlat.new()
	st.bg_color = Charte.PANNEAU_2
	st.set_corner_radius_all(Charte.RAYON_CARTE)
	racine.add_theme_stylebox_override("panel", st)
	racine.mouse_filter = Control.MOUSE_FILTER_PASS
	var y := 14.0
	var i := 0
	for c: Dictionary in ls:
		i += 1
		var ligne := Control.new()
		ligne.name = "TestsPhysiquesMailLigne%d" % i
		ligne.mouse_filter = Control.MOUSE_FILTER_IGNORE
		racine.add_child(ligne)
		D.place(ligne, Rect2(12, y, largeur - 24, hauteur_ligne))
		var id := str(c.j.get("id", ""))
		Panneaux._bouton(ligne, Rect2(0, 0, largeur - 24, hauteur_ligne), func(): ouvrir_fiche(app, id), "TestsPhysiquesMailOuvrir%d" % i, str(c.j.get("name", "")))
		var res: Array = RESULTATS[bool(c.ok)]
		Panneaux._portrait(ligne, c.j, Rect2(8, 12, 72, 72), res[1], 3)
		D.text(ligne, 96, 44, str(c.j.get("name", "")), 24, Charte.IVOIRE, 700, 300)
		D.text(ligne, 96, 76, str(c.libelle), 19, R.ROUGE, 600, 300)
		corps(ligne, Rect2(410, 6, 96, hauteur_ligne - 12), str(c.type), bool(c.droite), "TestsPhysiquesMailCorps%d" % i)
		R.pastille(ligne, 540, 58, str(res[0]), res[1], res[2], "TestsPhysiquesMailTest%d" % i, 20)
		var bx := 720.0
		var bl := maxf(160.0, minf(260.0, largeur - 24 - bx - 220.0))
		barre_minutes(ligne, bx, 36.0, bl, int(c.minutes), "TestsPhysiquesMailMinutes%d" % i)
		if i < ls.size(): D.line(ligne, Vector2(0, hauteur_ligne - 1), Vector2(largeur - 24, hauteur_ligne - 1), Charte.FILET, 1)
		y += hauteur_ligne
	racine.custom_minimum_size = Vector2(C.px(largeur), C.px(y + 14.0))
	return racine
