extends RefCounted
## Notes de match enregistrées (clubLife.matchNotes, moteur match-notes.cjs) : moyenne de saison,
## forme (5 dernières notes en pastilles colorées), historique des matchs et homme du match.
## Même pastille que l'entracte (match_tableau_widgets.gd : vert 7 et plus, or dès 6, rouge dessous).

const Tableau = preload("res://ui/contextual/match_tableau_widgets.gd")
const D = preload("res://ui/immersive08/primitives.gd")

static func bilan(model: Dictionary) -> Dictionary:
	var vie: Variant = model.get("clubLife", {})
	var notes: Variant = vie.get("matchNotes", {}) if vie is Dictionary else {}
	return notes if notes is Dictionary else {}

static func joueur(model: Dictionary, id: String) -> Dictionary:
	var joueurs: Variant = bilan(model).get("joueurs", {})
	if joueurs is Dictionary and joueurs.get(id) is Dictionary:
		return joueurs.get(id)
	return {}

static func texte_note(valeur: Variant) -> String:
	if valeur == null:
		return "—"
	return ("%.1f" % float(valeur)).replace(".", ",")

static func forme(donnees: Dictionary) -> Array:
	var f: Variant = donnees.get("forme", [])
	return f if f is Array else []

## Pastille de note (fond teinté, chiffre plein), placée en coordonnées de maquette.
static func pastille(parent: Control, rectangle: Rect2, valeur: float, densite := 0.5) -> Control:
	var note := Tableau.Note.new()
	note.valeur = valeur
	note.densite = densite
	parent.add_child(note)
	D.place(note, rectangle)
	return note

## Forme récente : cinq emplacements, la plus récente à droite ; emplacement vide = trait discret.
static func pastilles(parent: Control, origine: Vector2, valeurs: Array, cote := Vector2(42, 26), ecart := 6.0, densite := 0.42) -> Control:
	var groupe := Control.new()
	groupe.name = "NotesForme"
	groupe.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(groupe)
	D.place(groupe, Rect2(origine, Vector2(cote.x * 5 + ecart * 4, cote.y)))
	var depart := 5 - valeurs.size()
	for i in 5:
		var zone := Rect2(Vector2(i * (cote.x + ecart), 0), cote)
		if i < depart:
			# Match pas encore joué : un simple trait discret, pas une case vide.
			var trait_ := Rect2(zone.position + Vector2(zone.size.x * 0.25, zone.size.y * 0.5 - 1.5), Vector2(zone.size.x * 0.5, 3))
			var vide := D.rect(groupe, trait_, Color(1, 1, 1, 0.16), 2)
			vide.name = "FormeVide" + str(i)
		else:
			pastille(groupe, zone, float(valeurs[i - depart]), densite).name = "FormeNote" + str(i)
	var textes: Array[String] = []
	for v: Variant in valeurs:
		textes.append(texte_note(v))
	groupe.tooltip_text = "Forme : " + (" · ".join(textes) if not textes.is_empty() else "aucun match noté") + "\n(5 derniers matchs, le plus récent à droite)"
	return groupe
