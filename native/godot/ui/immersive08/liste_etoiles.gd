extends RefCounted
## Effectif : « poste → étoiles » (revue FM27, idée 5, choix de Léo du 22/11/2026).
## Un clic sur un maillot du terrain XV (panneau de gauche) classe la liste par étoiles à ce poste : étoiles = capacité
## au poste uniquement, sur l'échelle ABSOLUE commune (bareme_etoiles.gd, note au poste du moteur). Le poste choisi
## s'affiche en titre au-dessus de la liste, ✕ revient au tri par poste. Badges de statut courts, colorés et
## cliquables derrière le nom (Offre, Départ, Jeune = 21 ans et moins) ; blessé, suspendu et sélection restent dans
## la colonne STATUT (la pastille Blessé ouvre la fenêtre blessure).
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Bareme = preload("res://ui/bareme_etoiles.gd")

const NOMS := ["Pilier gauche", "Talonneur", "Pilier droit", "Deuxième ligne", "Deuxième ligne", "3e ligne aile",
	"3e ligne aile", "Numéro 8", "Demi de mêlée", "Demi d’ouverture", "Ailier", "Centre", "Centre", "Ailier", "Arrière"]
const SIGLES := {1: "PG", 2: "T", 3: "PD", 4: "2L", 5: "2L", 6: "3L", 7: "3L", 8: "N8", 9: "DM", 10: "DO", 11: "AL",
	12: "C", 13: "C", 14: "AL", 15: "AR"}
const AGE_JEUNE := 21

static func nom_poste(numero: int) -> String:
	return str(NOMS[numero - 1]) if numero >= 1 and numero <= 15 else ""

## Poste principal du joueur en abrégé (PG, T, 2L, DO…) ; "" si inconnu.
static func abrege(joueur: Dictionary) -> String:
	var source: Variant = joueur.get("primaryPositions", [joueur.get("primaryPosition")])
	if source is Array:
		for v: Variant in source:
			if (v is int or v is float) and SIGLES.has(int(v)): return str(SIGLES[int(v)])
	return ""

## Étoiles (0 à 5, par demi) du joueur au poste `numero` : note au poste du moteur sur le barème absolu ; -1 si inconnue.
static func etoiles(joueur: Dictionary, numero: int) -> float:
	if numero < 1 or numero > 15: return -1.0
	var notes: Variant = joueur.get("positionRatings")
	if not notes is Dictionary: return -1.0
	return Bareme.etoiles_sur_100((notes as Dictionary).get(str(numero)))

## Joueurs à 4 étoiles et plus au poste.
static func profondeur(joueurs: Array, numero: int) -> int:
	var n := 0
	for p: Variant in joueurs:
		if p is Dictionary and etoiles(p, numero) >= 4.0: n += 1
	return n

static func couleur_profondeur(n: int) -> Color:
	if n <= 0: return R.ROUGE
	if n == 1: return R.ORANGE
	if n == 2: return Charte.couleur_attribut(60)
	return R.VERT

# ---------------------------------------------------------------- badges de statut

## Badges du joueur : [{id, t (infobulle), court, c, icone, cible}] ; cible = "contrat" ou "formation".
static func badges(joueur: Dictionary) -> Array:
	var sortie: Array = []
	var vente: Variant = joueur.get("sale")
	if vente is Dictionary:
		if vente.get("pending") is Dictionary: sortie.append({"id": "Depart", "t": "Départ prévu", "court": "Départ", "c": R.ROUGE, "icone": "money", "cible": "contrat"})
		elif vente.get("offerId") is String: sortie.append({"id": "Offre", "t": "Offre reçue", "court": "Offre", "c": R.ORANGE, "icone": "money", "cible": "contrat"})
	var age: Variant = joueur.get("age")
	if (age is int or age is float) and int(age) <= AGE_JEUNE:
		sortie.append({"id": "Jeune", "t": "Jeune · %d ans" % int(age), "court": "Jeune", "c": R.VERT, "icone": "", "cible": "formation"})
	return sortie

static func ouvrir_badge(app: Control, joueur: Dictionary, b: Dictionary) -> void:
	if str(b.cible) == "formation":
		app._navigate("Formation")
		return
	var id := str(joueur.get("id", ""))
	app.selected_player = id
	app.navigation_controller.open_entity({"kind": "player", "id": id, "section": "contract"})

## Pose les badges en ligne à partir de x (unités du gabarit), sans dépasser `largeur_max`.
static func poser_badges(app: Control, rangee: Control, joueur: Dictionary, x: float, base: float, largeur_max: float, taille := 18) -> void:
	var depart := x
	for b: Dictionary in badges(joueur):
		var texte := str(b.court)
		var l := 12.0 + (float(taille) + 9.0 if not str(b.icone).is_empty() else 0.0) + R.largeur(texte, taille) + 2.0 + 12.0
		if x + l - depart > largeur_max: break
		var fond := R.pastille(rangee, x, base, texte, b.c, str(b.icone), "RosterBadge_" + str(b.id), taille)
		var bouton := R.cliquable(fond, ouvrir_badge.bind(app, joueur, b), "RosterBadgeOuvrir_" + str(b.id), str(b.t))
		bouton.accessibility_name = str(b.t) + " · " + str(joueur.get("name", ""))
		x += l + 6.0

# ---------------------------------------------------------------- titre du poste choisi

## « ★ CENTRE 12 », pastille « n × ★4+ » et ✕, alignés à droite de `fin` sur la rangée des pastilles de poste.
static func titre_poste(parent: Control, fin: float, y: float, joueurs: Array, numero: int, effacer: Callable) -> void:
	if numero <= 0: return
	var nom := "★ %s %d" % [nom_poste(numero).to_upper(), numero]
	var prof := profondeur(joueurs, numero)
	var texte_prof := "%d × ★4+" % prof
	var l_nom := R.largeur(nom, 30, 800)
	var l_prof := 12.0 + R.largeur(texte_prof, 19) + 2.0 + 12.0
	var x := fin - 44.0 - 12.0 - l_prof - 16.0 - l_nom
	var titre := D.text(parent, x, y + 32, nom, 30, Charte.IVOIRE, 800, l_nom + 8)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "EtoilesTitrePoste"
	var pastille := R.pastille(parent, x + l_nom + 16.0, y + 27, texte_prof, couleur_profondeur(prof), "", "EtoilesProfondeur", 19)
	pastille.tooltip_text = "Joueurs à 4 étoiles et plus · %s" % nom_poste(numero)
	pastille.mouse_filter = Control.MOUSE_FILTER_PASS
	var fermer := Button.new()
	fermer.name = "EtoilesEffacer"
	fermer.text = "✕"
	fermer.tooltip_text = "Retirer les étoiles"
	fermer.accessibility_name = "Retirer les étoiles du poste " + nom_poste(numero)
	fermer.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fermer.focus_mode = Control.FOCUS_ALL
	C.style_bouton_lien(fermer, 22)
	fermer.alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(fermer)
	D.place(fermer, C.reach_rect(Rect2(fin - 44.0, y, 44, 40)))
	fermer.pressed.connect(func(): effacer.call(0))
