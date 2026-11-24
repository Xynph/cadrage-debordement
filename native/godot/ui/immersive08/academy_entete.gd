extends "res://ui/immersive08/academy_filtres.gd"
## Écran Formation (découpe de academy_canvas.gd, sans changement) : titre, tuiles de compteurs, onglets et bandeau « passage en groupe ».

# --- En-tête, compteurs, onglets ---------------------------------------------------------------------------------------

func _heading() -> void:
	var titre := Kit.titre_page(self, 0, 44, "Formation", 38, 700)
	titre.name = "AcademyTitle"
	app.heading = titre
	var decider := _compter(roster, "decide")
	var phrase := "La relève · %s" % P.plural(roster.size(), "espoir", "espoirs")
	if decider > 0: phrase += " · %s à trancher avant la fin de saison" % P.plural(decider, "contrat d’espoir", "contrats d’espoir")
	Kit.texte(self, 0, 78, phrase, Charte.IVOIRE_2, 0, 18)
	var suivi := Kit.lien(self, Rect2(Kit.largeur(phrase, 18) + 30, 52, 0, 34), "Suivre les objectifs et gains observés →", func(): Pages.ouvrir(app, "suivi"), "OpenYouthDevelopment", 18)
	suivi.tooltip_text = ""
	var u18 := roster.filter(func(p: Dictionary): return int(p.get("age", 0)) <= 18).size()
	var pepites := _compter(roster, "pepite")
	var recruitment: Dictionary = app.model.get("decisions", {}).get("recruitment", {})
	var places: Variant = recruitment.get("places")
	var capacite: Variant = recruitment.get("capacity")
	var tuiles := [
		["ESPOIRS", G.n(roster.size()), "%d U18 · %d U21" % [u18, roster.size() - u18], "AcademyTileEspoirs", func(): _fixer("status", ""), 262.0],
		["PÉPITES", "★ " + G.n(pepites), "gros potentiel", "AcademyTilePepites", func(): _fixer("status", "pepite"), 262.0],
		["À DÉCIDER", G.n(decider), "contrat à trancher", "AcademyTileDecider", func(): _fixer("status", "decide"), 262.0],
		["PLACES PRO LIBRES", G.n(places) if places is int or places is float else "—", "sur l’effectif de %s" % G.n(capacite) if capacite is int or capacite is float else "à l’effectif", "AcademyTilePlaces", func(): app._navigate("Effectif"), 300.0],
	]
	var x := float(WIDTH) - 4 * 12.0 + 12.0
	for tuile: Array in tuiles: x -= float(tuile[5])
	for index in tuiles.size():
		var tuile: Array = tuiles[index]
		_tuile(x, float(tuile[5]), str(tuile[0]), str(tuile[1]), str(tuile[2]), str(tuile[3]), tuile[4], index == 2)
		x += float(tuile[5]) + 12.0

func _tuile(x: float, largeur: float, etiquette: String, valeur: String, suite: String, id: String, action: Callable, marque: bool) -> void:
	var tuile := Button.new()
	tuile.name = id
	tuile.flat = true
	tuile.focus_mode = Control.FOCUS_ALL
	tuile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tuile.accessibility_name = "%s : %s, %s" % [etiquette.capitalize(), valeur, suite]
	tuile.add_theme_stylebox_override("normal", C.box(Charte.PANNEAU, Color.TRANSPARENT, 16, 0))
	tuile.add_theme_stylebox_override("hover", C.box(Charte.PANNEAU_2, Color.TRANSPARENT, 16, 0))
	tuile.add_theme_stylebox_override("pressed", C.box(Charte.PANNEAU_3, Color.TRANSPARENT, 16, 0))
	var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, 16, 0)
	focus.set_border_width_all(2)
	tuile.add_theme_stylebox_override("focus", focus)
	tuile.pressed.connect(action)
	add_child(tuile)
	D.place(tuile, Rect2(x, 6, largeur, 116))
	if marque: Kit.marqueur(tuile, Rect2(12, 22, 6, 72))
	var gauche := 34 if marque else 16
	D.text(tuile, gauche, 36, etiquette, 16, Charte.IVOIRE_2, 700, largeur - 30)
	var nombre := D.text(tuile, gauche, 84, valeur, 46, Charte.IVOIRE, 800, largeur - 30)
	nombre.add_theme_font_override("font", Charte.TITRE_EXTRA_ITALIQUE)
	D.text(tuile, gauche + Kit.largeur(valeur, 34) + 14, 82, suite, 16, Charte.IVOIRE_2, 600, largeur - gauche - Kit.largeur(valeur, 34) - 22)
	for enfant in tuile.get_children():
		if enfant is Control: (enfant as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

func _fixer(cle: String, valeur: Variant) -> void:
	state[cle] = valeur
	state.tab = 0
	state.table_scroll = 0
	app._render()

func _tabs() -> void:
	var x := 0.0
	for i in TABS.size():
		var libelle: String = TABS[i]
		var choisi := active_tab == i
		var largeur := Kit.largeur(libelle, 19) + 44
		var bouton := Button.new()
		bouton.name = "AcademyImmersiveTab" + str(i)
		bouton.text = libelle
		bouton.focus_mode = Control.FOCUS_ALL
		bouton.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# Charte §7.1 : onglet en pilule ; actif = aplat crème, texte PANNEAU.
		bouton.add_theme_font_override("font", Charte.TITRE_GRAS if choisi else Charte.TITRE)
		bouton.add_theme_font_size_override("font_size", maxi(12, C.px(21)))
		D.tab_state(bouton, Vector2(largeur, 44), choisi, "")
		bouton.icon = null
		var focus := C.box(Color.TRANSPARENT, Charte.IVOIRE, Charte.RAYON_PILULE, 18)
		focus.set_border_width_all(2)
		focus.set_expand_margin_all(2)
		bouton.add_theme_stylebox_override("focus", focus)
		bouton.toggle_mode = true
		bouton.set_pressed_no_signal(choisi)
		bouton.pressed.connect(func(): _open_tab(i))
		add_child(bouton)
		D.place(bouton, Rect2(x, 148, largeur, 44))
		x += largeur + 8
	D.line(self, Vector2(0, 192), Vector2(WIDTH, 192), Charte.FILET)
	_group_upgrade(x)

## Passage à 30 U18 et 30 U21 : lien dans la ligne des onglets ; confirmation EN PLACE ; raison écrite dans la page.
func _group_upgrade(depart: float) -> void:
	var meta: Dictionary = app.model.get("meta", {})
	if int(meta.get("academyGroupPolicy", 0)) >= 2: return
	var apercu: Dictionary = meta.get("academyGroups", {})
	var zone := Rect2(WIDTH, 152, 0, 38)
	if apercu.is_empty():
		var lien := Kit.lien(self, zone, "Vérifier le passage à 30 U18 et 30 U21 →", func(): app._command("academy_groups_preview"), "AcademyGroupsPreview", 18, true)
		lien.tooltip_text = ""
		return
	if not apercu.get("available", false):
		var raison := Kit.lien(self, zone, "Pourquoi la mise à jour attend →", func():
			state.groupes_raison = not bool(state.get("groupes_raison", false))
			app._render(), "AcademyGroupsBlocked", 18, true)
		raison.tooltip_text = ""
		if state.get("groupes_raison", false):
			var note := D.rect(self, Rect2(WIDTH - 900, 196, 900, 70), Charte.PANNEAU_3, 16)
			note.name = "AcademyGroupsReason"
			note.z_index = 5
			var texte := C.wrap(str(apercu.get("reason", "Réessaie après la prochaine intersaison.")), 18, Charte.IVOIRE)
			note.add_child(texte)
			D.place(texte, Rect2(16, 10, 868, 52))
		return
	var texte_confirmation := "Compléter les Crabos et Espoirs des %d clubs ? %d jeunes rejoindront les centres. Les joueurs en place garderont leur fiche et leurs acquis." % [int(apercu.centers), int(apercu.additions)]
	var lien := Kit.lien(self, zone, "Compléter les centres de formation →", func():
		var bloc := EnPlace.ouvrir(app, self, "AcademyGroupsConfirm", "30 U18 et 30 U21 par club", [texte_confirmation], "Compléter les centres", func():
			app._command("academy_groups_enable", {"confirmed": true, "context": apercu.context}))
		D.place(bloc, Rect2(WIDTH - 1000, 200, 1000, 10)), "AcademyGroupsEnable", 18, true)
	lien.tooltip_text = ""
	lien.add_theme_font_override("font", Charte.TITRE_GRAS)

func _open_tab(index: int) -> void:
	state.tab = index
	state.table_scroll = 0
	state.page = 0
	app._render()
	U.focus(app, "AcademyImmersiveTab" + str(index))
