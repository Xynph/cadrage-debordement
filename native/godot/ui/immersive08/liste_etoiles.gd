extends RefCounted
## Effectif : « poste → étoiles » (revue FM27, idée 5, choix de Léo du 22/11/2026).
## Un clic sur un maillot du terrain XV (panneau de gauche) classe la liste par étoiles à ce poste : étoiles = capacité
## au poste uniquement, RELATIVES à notre effectif (bareme_etoiles.gd : notre meilleur joueur au poste = 5). Le poste choisi
## s'affiche en titre au-dessus de la liste, ✕ revient au tri par poste. Badges de statut courts, colorés et
## cliquables derrière le nom (Blessé → fenêtre blessure, Suspendu, Sélection, Offre, Départ, Jeune = 21 ans et moins) ;
## la colonne STATUT ne garde que Titulaire, Remplaçant ou Hors groupe.
const C = preload("res://ui/immersive08/components.gd")
const D = preload("res://ui/immersive08/primitives.gd")
const Charte = preload("res://ui/charte.gd")
const R = preload("res://ui/immersive08/reperes.gd")
const Bareme = preload("res://ui/bareme_etoiles.gd")
const Familiarite = preload("res://ui/familiarite_poste.gd")

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

## Note au poste `numero` (1-15) du moteur (positionRatings) ; -1 si inconnue (joueur non observé).
static func note_poste(joueur: Dictionary, numero: int) -> float:
	if numero < 1 or numero > 15: return -1.0
	var notes: Variant = joueur.get("positionRatings")
	if not notes is Dictionary: return -1.0
	var v: Variant = (notes as Dictionary).get(str(numero))
	return float(v) if Bareme.etoiles_sur_100(v) >= 0.0 else -1.0

## Repère du poste : meilleure note de notre effectif à ce poste (5 étoiles) ; -1 si personne n'est connu.
static func reference_poste(joueurs: Array, numero: int) -> float:
	var notes: Array = []
	for p: Variant in joueurs:
		if p is Dictionary: notes.append(note_poste(p, numero))
	return Bareme.meilleure_note(notes)

## Étoiles (0 à 5, par demi) du joueur au poste, RELATIVES à notre meilleur joueur à ce poste ; -1 si inconnues.
static func etoiles(joueur: Dictionary, numero: int, reference: float) -> float:
	return Bareme.etoiles_relatives(note_poste(joueur, numero), reference)

## Joueurs à 4 étoiles et plus au poste (même repère que la liste).
static func profondeur(joueurs: Array, numero: int) -> int:
	var reference := reference_poste(joueurs, numero)
	var n := 0
	for p: Variant in joueurs:
		if p is Dictionary and etoiles(p, numero, reference) >= 4.0: n += 1
	return n

static func couleur_profondeur(n: int) -> Color:
	if n <= 0: return R.ROUGE
	if n == 1: return R.ORANGE
	if n == 2: return Charte.couleur_attribut(60)
	return R.VERT

# ---------------------------------------------------------------- badges de statut

## Badges du joueur : [{id, t (infobulle), court, c, icone, cible}]. `indispo` (de l'Effectif) : {etat, t, court} si
## blessé, suspendu ou en sélection. Cible = "blessure", "fiche", "selections", "contrat" ou "formation".
static func badges(joueur: Dictionary, indispo: Dictionary = {}) -> Array:
	var sortie: Array = []
	match str(indispo.get("etat", "")):
		"blesse": sortie.append({"id": "Blesse", "t": str(indispo.t), "court": str(indispo.court), "c": R.ROUGE, "icone": "", "cible": "blessure"})
		"suspendu": sortie.append({"id": "Suspendu", "t": str(indispo.t), "court": str(indispo.court), "c": R.ROUGE, "icone": "", "cible": "fiche"})
		"selection": sortie.append({"id": "Selection", "t": str(indispo.t), "court": str(indispo.court), "c": R.BLEU, "icone": "", "cible": "selections"})
	var vente: Variant = joueur.get("sale")
	if vente is Dictionary:
		if vente.get("pending") is Dictionary: sortie.append({"id": "Depart", "t": "Départ prévu", "court": "Départ", "c": R.ROUGE, "icone": "money", "cible": "contrat"})
		elif vente.get("offerId") is String: sortie.append({"id": "Offre", "t": "Offre reçue", "court": "Offre", "c": R.ORANGE, "icone": "money", "cible": "contrat"})
	var age: Variant = joueur.get("age")
	if (age is int or age is float) and int(age) <= AGE_JEUNE:
		sortie.append({"id": "Jeune", "t": "Jeune · %d ans" % int(age), "court": "Jeune", "c": R.VERT, "icone": "", "cible": "formation"})
	return sortie

## Blessé : petite fenêtre « blessure » quand elle existe (fenetre_blessure.gd), sinon la fiche.
const FENETRE_BLESSURE := "res://ui/immersive08/fenetre_blessure.gd"

static func ouvrir_badge(page: Control, app: Control, joueur: Dictionary, b: Dictionary, origine: Control) -> void:
	var id := str(joueur.get("id", ""))
	match str(b.cible):
		"formation":
			app._navigate("Formation")
			return
		"selections":
			app._navigate("Sélections")
			return
		"blessure":
			if ResourceLoader.exists(FENETRE_BLESSURE):
				load(FENETRE_BLESSURE).ouvrir(page, app, id, origine)
				return
	app.selected_player = id
	app.navigation_controller.open_entity({"kind": "player", "id": id, "section": "contract" if b.cible == "contrat" else ""})

## Pose les badges en ligne à partir de x (unités du gabarit), sans dépasser `largeur_max`.
static func poser_badges(page: Control, app: Control, rangee: Control, joueur: Dictionary, indispo: Dictionary, x: float, base: float, largeur_max: float, taille := 18) -> void:
	var depart := x
	for b: Dictionary in badges(joueur, indispo):
		var texte := str(b.court)
		var l := 12.0 + (float(taille) + 9.0 if not str(b.icone).is_empty() else 0.0) + R.largeur(texte, taille) + 2.0 + 12.0
		if x + l - depart > largeur_max: break
		var fond := R.pastille(rangee, x, base, texte, b.c, str(b.icone), "RosterBadge_" + str(b.id), taille)
		var bouton := R.cliquable(fond, ouvrir_badge.bind(page, app, joueur, b, rangee), "RosterBadgeOuvrir_" + str(b.id), str(b.t))
		bouton.accessibility_name = str(b.t) + " · " + str(joueur.get("name", ""))
		if b.cible == "blessure": bouton.add_to_group(&"ouvre_blessure")
		x += l + 6.0

# ---------------------------------------------------------------- titre du poste choisi

## « CENTRE 12 », nombre de joueurs Naturels et Confirmés à ce poste (familiarité, A pastilles / B barres) et ✕,
## alignés à droite de `fin` sur la rangée des pastilles de poste.
static func titre_poste(parent: Control, fin: float, y: float, joueurs: Array, numero: int, effacer: Callable) -> void:
	if numero <= 0: return
	var nom := "%s %d" % [nom_poste(numero).to_upper(), numero]
	var comptes := [0, 0]
	for p: Variant in joueurs:
		if p is Dictionary:
			var n := Familiarite.niveau(p, numero)
			if n == Familiarite.NATUREL: comptes[0] += 1
			elif n == Familiarite.CONFIRME: comptes[1] += 1
	var marques: Array = []
	for i in 2:
		var niv: int = Familiarite.NATUREL if i == 0 else Familiarite.CONFIRME
		marques.append({"n": niv, "texte": "%d %s" % [comptes[i], Familiarite.mot(niv)], "compte": comptes[i]})
	var l_marques := 0.0
	for m: Dictionary in marques:
		m.l = (12.0 + R.largeur(m.texte, 19) + 2.0 + 12.0) if Familiarite.variante() == "A" else Familiarite.largeur(m.n, 20, false) + 8.0 + R.largeur(str(m.compte), 22, 800) + 4.0
		l_marques += m.l + 12.0
	var l_nom := R.largeur(nom, 30, 800)
	var x := fin - 44.0 - 12.0 - l_marques - 16.0 - l_nom
	var titre := D.text(parent, x, y + 32, nom, 30, Charte.IVOIRE, 800, l_nom + 8)
	titre.add_theme_font_override("font", Charte.TITRE_FICHE)
	titre.name = "EtoilesTitrePoste"
	var xm := x + l_nom + 16.0
	for m: Dictionary in marques:
		var aide := "%s · %s" % [Familiarite.mot(m.n), nom_poste(numero)]
		if Familiarite.variante() == "A":
			var pastille := R.pastille(parent, xm, y + 27, m.texte, Familiarite.couleur(m.n) if m.compte > 0 else Charte.IVOIRE_3, "", "FamiliariteCompte_%d" % m.n, 19)
			pastille.tooltip_text = aide
			pastille.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			var lb := Familiarite.poser(parent, xm, y + 28, m.n, 20, "FamiliariteCompte_%d" % m.n, false, "B")
			var chiffre := D.text(parent, xm + lb + 8.0, y + 29, str(m.compte), 22, Familiarite.couleur(m.n) if m.compte > 0 else Charte.IVOIRE_3, 800, 40)
			chiffre.tooltip_text = aide
			chiffre.mouse_filter = Control.MOUSE_FILTER_PASS
		xm += m.l + 12.0
	var fermer := Button.new()
	fermer.name = "EtoilesEffacer"
	fermer.text = "✕"
	fermer.tooltip_text = "Retirer le poste"
	fermer.accessibility_name = "Retirer le poste " + nom_poste(numero)
	fermer.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fermer.focus_mode = Control.FOCUS_ALL
	C.style_bouton_lien(fermer, 22)
	fermer.alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(fermer)
	D.place(fermer, C.reach_rect(Rect2(fin - 44.0, y, 44, 40)))
	fermer.pressed.connect(func(): effacer.call(0))
