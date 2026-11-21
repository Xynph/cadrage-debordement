extends RefCounted
## Panneau flottant visuel : les joueurs d'une part d'anneau ou d'un poste, en tuiles (portrait, nom, jauge de condition).
## Un clic sur un portrait ou un nom ouvre la fiche du joueur (changement d'écran, le panneau disparaît avec la page).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const G = preload("res://ui/game_skin.gd")
const COLONNES := 6
const TUILE := Vector2(206, 92)

static func ouvrir(canvas: Control, titre: String, couleur: Color, joueurs: Array) -> Panel:
	fermer(canvas)
	var voile := D.button(canvas, Rect2(0, 0, 2248, 1230), "", func(): fermer(canvas), false, "", false, Color.WHITE, "TrainingGroupVeil")
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		voile.add_theme_stylebox_override(etat, C.box(Color(0, 0, 0, 0.55), Color.TRANSPARENT, 0, 0))
	voile.focus_mode = Control.FOCUS_NONE
	voile.tooltip_text = "Fermer"
	var lignes := ceili(float(maxi(1, joueurs.size())) / COLONNES)
	var largeur := COLONNES * (TUILE.x + 10.0) + 38.0
	var hauteur := 120.0 + lignes * (TUILE.y + 10.0) + 24.0
	var panneau := D.panel(canvas, Rect2((2248.0 - largeur) / 2.0, 250, largeur, hauteur), "", "", "", "TrainingGroupPanel")
	D.rect(panneau, Rect2(24, 30, 28, 28), couleur, 6)
	D.text(panneau, 66, 56, titre.to_upper(), 32, C.IVORY, 700, largeur - 340)
	D.chip(panneau, Rect2(largeur - 270, 26, 120, 36), "%d joueur(s)" % joueurs.size(), couleur)
	var fermer_bouton := D.button(panneau, Rect2(largeur - 134, 22, 110, 44), "Fermer", func(): fermer(canvas), false, "", true, Color.WHITE, "TrainingGroupClose")
	D.line(panneau, Vector2(18, 78), Vector2(largeur - 18, 78), Color(C.LINE, .7))
	for i in joueurs.size():
		var p: Dictionary = joueurs[i]
		var x := 19.0 + (i % COLONNES) * (TUILE.x + 10.0)
		var y := 96.0 + (i / COLONNES) * (TUILE.y + 10.0)
		var carte := D.rect(panneau, Rect2(x, y, TUILE.x, TUILE.y), C.Charte.PANNEAU_2, C.Charte.RAYON_CARTE)
		canvas._portrait(carte, p, Rect2(8, 8, 66, 76))
		D.text(carte, 84, 30, str(p.get("name", "")), 21, C.IVORY, 700, TUILE.x - 92)
		D.text(carte, 84, 52, str(p.get("pos", "")), 17, C.MUTED, 500, TUILE.x - 92)
		var condition := clampf(float(p.get("condition", 0)), 0.0, 100.0)
		D.rect(carte, Rect2(84, 66, 62, 8), C.Charte.PANNEAU_3, 4)
		D.rect(carte, Rect2(84, 66, 62.0 * condition / 100.0, 8), C.Charte.couleur_attribut(condition), 4)
		D.text(carte, 154, 76, G.n(roundi(condition)), 19, C.IVORY, 700, 46)
		var cle := str(p.get("id", "")).validate_node_name()
		canvas._person_link(carte, Rect2(8, 8, 66, 76), "player", p, "TrainingGroupPortrait_" + cle)
		canvas._person_link(carte, Rect2(80, 8, TUILE.x - 86, 28), "player", p, "TrainingGroupName_" + cle)
	fermer_bouton.grab_focus()
	return panneau

static func fermer(canvas: Control) -> void:
	for nom in ["TrainingGroupPanel", "TrainingGroupVeil"]:
		var ancien := canvas.find_child(nom, true, false)
		if ancien != null:
			ancien.get_parent().remove_child(ancien)
			ancien.queue_free()
