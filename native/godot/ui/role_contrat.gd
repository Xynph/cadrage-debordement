extends RefCounted
## Rôle promis au contrat : Titulaire / Rotation / Espoir / Appoint (décision de Léo du 23/11/2026, idée FM 12 ; base
## commune des idées 16 « temps de jeu promis » et 18 « négociation »). Seul endroit des libellés et des couleurs (jetons
## Charte.ROLE_*). Donnée moteur : squad[].roleContrat = {role, deduit, saison} (native/engine/role-contrat.cjs) ;
## « deduit » : rôle tiré de la hiérarchie (ancien contrat ou signature sans promesse), sinon promis explicitement.
const Charte = preload("res://ui/charte.gd")
const C = preload("res://ui/immersive08/components.gd")

const ROLES := ["titulaire", "rotation", "espoir", "appoint"]
const LIBELLES := {"titulaire": "Titulaire", "rotation": "Rotation", "espoir": "Espoir", "appoint": "Appoint"}
const COULEURS := {"titulaire": Charte.ROLE_TITULAIRE, "rotation": Charte.ROLE_ROTATION, "espoir": Charte.ROLE_ESPOIR, "appoint": Charte.ROLE_APPOINT}

## Rôle du contrat en cours d'un joueur de la projection ("" sans contrat professionnel).
static func role(player: Dictionary) -> String:
	var r: Variant = player.get("roleContrat")
	return str(r.get("role", "")) if r is Dictionary and str(r.get("role", "")) in ROLES else ""

## Vrai si le rôle a été promis explicitement (signature ou prolongation avec promesse).
static func promis(player: Dictionary) -> bool:
	var r: Variant = player.get("roleContrat")
	return r is Dictionary and str(r.get("role", "")) in ROLES and not bool(r.get("deduit", true))

static func libelle(id: String) -> String:
	return str(LIBELLES.get(id, "—"))

static func couleur(id: String) -> Color:
	return COULEURS.get(id, Charte.GRIS_VERT)

## Rang pour les tris (Titulaire d'abord ; sans rôle en dernier).
static func rang(id: String) -> int:
	var i := ROLES.find(id)
	return i if i >= 0 else ROLES.size()

## Pastille du rôle : fond teinté, mot dans la couleur du rôle (la couleur n'est jamais seule). Pas de survol : la
## pastille s'affiche dans une cellule qui porte elle-même le lien.
static func pastille(id: String, taille: int = 16) -> PanelContainer:
	var teinte := couleur(id)
	var fond := PanelContainer.new()
	fond.name = "RoleContrat_" + (id if not id.is_empty() else "aucun")
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fond.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fond.add_theme_stylebox_override("panel", Charte.style_pilule(Charte.PANNEAU.lerp(teinte, 0.24), Color.TRANSPARENT, 10, 2))
	var mot := Label.new()
	mot.text = libelle(id)
	mot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mot.add_theme_font_override("font", C.BOLD)
	mot.add_theme_font_size_override("font_size", taille)
	mot.add_theme_color_override("font_color", teinte)
	mot.autowrap_mode = TextServer.AUTOWRAP_OFF
	fond.add_child(mot)
	fond.set_meta("role", id)
	return fond
