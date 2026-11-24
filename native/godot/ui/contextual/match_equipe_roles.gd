extends "res://ui/contextual/match_equipe_consignes.gd"
## Onglet Rôles : buteur, buteur de secours, lanceur en touche et botteur, changés en direct.
## Chaîne d'héritage de la fenêtre : socle ← outils ← terrain ← composition ← cartes ← consignes ← roles ← match_equipe.gd.

## Quatre cartes (deux par ligne) : qui s'en charge, le choix du staff, les candidats sur le terrain avec leur
## note dans l'attribut du rôle. Les règles (joueurs sur le terrain seulement, secours ≠ buteur) restent au moteur.
func _roles() -> void:
	var source: Variant = _pilotage().get("roles")
	var roles: Array = (source.get("roles") if source is Dictionary and source.get("roles") is Array else []).filter(func(r: Variant) -> bool: return r is Dictionary)
	var grille := GridContainer.new()
	grille.name = "TeamRoles"
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", px(16))
	grille.add_theme_constant_override("v_separation", px(16))
	_poser(grille, 24, 96, 1552, 708)
	if roles.is_empty():
		var rien := _texte("Les rôles se fixent avant le coup d'envoi pour cette rencontre.", 16, C.MUTED)
		grille.add_child(rien)
	for role: Dictionary in roles: grille.add_child(_carte_role(role))
	_pied(_pied_roles, ["← Retour à la composition", choisir_onglet.bind("composition"), "TeamToComposition"])

func _pied_roles(infos: HBoxContainer) -> void:
	var texte := _message if not _message.is_empty() else "Le changement vaut dès la prochaine occasion : prochain but, prochaine touche, prochain dégagement."
	infos.add_child(_coupe(_texte(texte, 13, _message_teinte if not _message.is_empty() else C.MUTED)))

func _carte_role(role: Dictionary) -> Control:
	var id := str(role.get("id", ""))
	var designe: Variant = role.get("designe")
	var staff: Variant = role.get("staff")
	var en_jeu: Variant = role.get("enJeu")
	# Rôle désigné par le manager : un seul filet ivoire à gauche (la ligne « En charge » le dit en toutes lettres).
	var cadre := _panneau(_plat(C.PANEL, C.IVORY if designe is Dictionary else Color.TRANSPARENT, 16, "left", 3, true))
	cadre.name = "Role_" + id
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cadre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var colonne := _v(8)
	cadre.add_child(colonne)
	var tete := _h(10)
	tete.add_child(_titre_section(str(role.get("label", "")), 22))
	var attribut := _texte(str(role.get("attribut", "")), 12, C.MUTED)
	attribut.size_flags_vertical = Control.SIZE_SHRINK_END
	tete.add_child(attribut)
	colonne.add_child(tete)
	var qui := _coupe(_texte("", 14, C.IVORY))
	if en_jeu is Dictionary:
		qui.text = "En charge : %s (%d)%s" % [str(en_jeu.get("name", "")), int(en_jeu.get("value", 0)), "" if designe is Dictionary else " · choix du staff"]
	else:
		qui.text = "Personne sur le terrain"
		qui.add_theme_color_override("font_color", C.ALERT)
	colonne.add_child(qui)
	var candidats: Array = (role.get("candidats") if role.get("candidats") is Array else []).filter(func(c: Variant) -> bool: return c is Dictionary)
	var occupe := bool(app.waiting) or _attente == "role"
	# Candidats sur deux colonnes : six au plus tiennent dans la carte sans défiler.
	var liste := GridContainer.new()
	liste.name = "RoleCandidates_" + id
	liste.columns = 2
	liste.add_theme_constant_override("h_separation", px(8))
	liste.add_theme_constant_override("v_separation", px(8))
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colonne.add_child(liste)
	for c: Dictionary in candidats.slice(0, 6):
		liste.add_child(_candidat(id, c, en_jeu is Dictionary and str(en_jeu.get("id", "")) == str(c.get("id", "")), staff is Dictionary and str(staff.get("id", "")) == str(c.get("id", "")), occupe))
	var vide := Control.new()
	vide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonne.add_child(vide)
	var rendre := _bouton("Laisser le staff choisir" + (" (%s)" % str(staff.get("name", "")) if staff is Dictionary else "") + " →", choisir_role.bind(id, ""), "lien", 14, "RoleStaff_" + id)
	rendre.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rendre.disabled = occupe or not designe is Dictionary
	colonne.add_child(rendre)
	return cadre

## Ligne d'un candidat : portrait, numéro et nom, note dans l'attribut ; filet épais et coche s'il est en charge.
func _candidat(role: String, c: Dictionary, choisi: bool, du_staff: bool, occupe: bool) -> Button:
	var bouton := _bouton("", choisir_role.bind(role, str(c.get("id", ""))), "segment", 14, "Role_%s_%d" % [role, int(c.get("num", 0))])
	if choisi:
		_style_segment(bouton, true)
		bouton.icon = null  # La coche va dans la rangée (le bouton n'a pas de texte, son contenu est en enfants).
	bouton.set_meta("joueur", str(c.get("id", "")))
	bouton.custom_minimum_size.y = px(44)
	bouton.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bouton.disabled = occupe
	bouton.toggle_mode = false
	var rangee := _h(10)
	S.full(rangee)
	rangee.offset_left = px(8)
	rangee.offset_right = -px(12)
	bouton.add_child(rangee)
	var portrait := _portrait(c, px(32))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(portrait)
	var nom := _coupe(_texte("%d · %s" % [int(c.get("num", 0)), str(c.get("name", ""))], 15, C.IVORY, _gras))
	nom.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(nom)
	if du_staff:
		var marque := _texte("choix du staff", 12, C.MUTED)
		marque.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rangee.add_child(marque)
	var note := _titre(str(int(c.get("value", 0))), 18, C.IVORY)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rangee.add_child(note)
	if choisi: rangee.add_child(_coche(16))
	return bouton
