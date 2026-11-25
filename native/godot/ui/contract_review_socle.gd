extends VBoxContainer
## Chaîne d'héritage : socle (constantes, variables, statiques) ← aides ← corps ← contract_review.gd (public).
## Read-only horizons from the current squad projection. No invented deadlines.
const C = preload("res://ui/immersive08/components.gd")
const Charte = preload("res://ui/charte.gd")
const Pages = preload("res://ui/immersive08/recruitment_pages.gd")
const U = preload("res://ui/management_state.gd")
const G = preload("res://ui/game_skin.gd")
const Sales = preload("res://ui/player_sales_view.gd")
const PetiteFenetre = preload("res://ui/petite_fenetre.gd")
const Bandeau = preload("res://ui/bandeau_filtres.gd")
const Role = preload("res://ui/role_contrat.gd")
const Notation = preload("res://ui/notation_staff.gd")
const STATUS_OPTIONS := ["Tous","Prolongation accessible","Discussion en cours","Échanges clos","Sans contrat renseigné"]
var app: Control
var state: Dictionary
var _rows: VBoxContainer
var _coverage: VBoxContainer
var _count: Label
var _scroll: ScrollContainer
var _season: OptionButton
var _position: OptionButton
var _status_choice: OptionButton
var _precision_choice: OptionButton
var _headers: Dictionary = {}
## Colonnes du tableau : [clé, largeur minimale, poids]. Les poids donnent la place aux noms et aux statuts (1920 : plus aucun texte coupé) ; le tableau
## se partage la largeur du panneau au lieu de la dépasser (1920, 1280, échelle d'interface 90-130 %).
const COLS := [["name", 126, 250], ["pos", 60, 100], ["rating", 40, 50], ["age", 34, 45], ["salary", 62, 105], ["share", 90, 130], ["playtime", 150, 200], ["contractEnd", 152, 170], ["conseil", 140, 175], ["actions", 96, 80]]
const COL_GAP := 4
## Couleurs franches par sens (jamais seules : chaque couleur accompagne un chiffre, une icône ou un mot).
const ORANGE := Color("e0a04a")
const VERT := Color("7fbf7a")
const BLEU := Color("5b9bd5")
const CITRON := Color("d4e35c")
const ROUGE := Color("d9534a")
## Largeur de la page en dessous de laquelle le panneau « Échéances » passe sous le tableau.
const LARGEUR_DEUX_COLONNES := 1500.0
var _columns: BoxContainer
var _fenetre: Control
const SORT_KEYS := ["name","pos","rating","age","salary","share","playtime","contractEnd","conseil"]

## ---- Contrats en un coup d'œil (revue FM27, idée 12, option A retenue par Léo le 23/11/2026) ----
## Compteurs d'échéance en haut (filtres), une ligne par joueur : part de la masse salariale, rôle promis au contrat et
## temps de jeu, échéance colorée, conseil du staff (calculé par le moteur toute l'année).
## Tranches d'échéance : mois restants jusqu'au 30 juin de la dernière saison du contrat.
const TRANCHES := [["0-6", "0-6 mois", Color("d9534a")], ["6-12", "6-12 mois", Color("e0a04a")], ["1-2", "1-2 ans", Color("d4e35c")], ["2+", "2 ans +", Color("7fbf7a")]]
## Conseils du staff (moteur : squad[].conseilStaff, prolongations-staff.cjs) : id → [mot, icône, couleur].
const CONSEILS := {"prolonger": ["Prolonger", "renew", Color("7fbf7a")], "partir": ["Laisser partir", "arrow", Color("d9534a")], "vendre": ["Vendre", "money", Color("e0a04a")], "garder": ["Garder", "check", Color("5b9bd5")], "vente": ["Vente en cours", "mail", Color("a88bd6")], "aucun": ["—", "info", Color("abb7b1")]}
const CONSEIL_ORDRE := ["prolonger", "partir", "vendre", "vente", "garder", "aucun"]
var _ctx: Dictionary = {}

## Mois restants jusqu'au 30 juin de l'année de fin (−1 : échéance inconnue).
static func mois_restants(player: Dictionary, today: String) -> float:
	var end := horizon(player)
	if end < 0: return -1.0
	var parts := today.split("-")
	if parts.size() < 3: return float(end) * 12.0
	var y := int(parts[0])
	var m := int(parts[1])
	var d := int(parts[2])
	return maxf(0.0, float(2026 + end - y) * 12.0 + float(6 - m) + float(30 - d) / 30.0)

static func tranche(mois: float) -> String:
	if mois < 0: return ""
	if mois < 6: return "0-6"
	if mois < 12: return "6-12"
	if mois < 24: return "1-2"
	return "2+"

static func tranche_couleur(id: String) -> Color:
	for t: Array in TRANCHES:
		if t[0] == id: return t[2]
	return Charte.GRIS_VERT

## Repères communs aux lignes : masse salariale totale, minutes de l'homme le plus utilisé, date du jour, effectif.
static func contexte(model: Dictionary) -> Dictionary:
	var squad: Array = model.get("squad", [])
	var total := 0.0
	var ref := 1.0
	for p: Dictionary in squad:
		var w: Variant = p.get("salary")
		if w is int or w is float: total += float(w)
		ref = maxf(ref, float(p.get("minutes", 0)))
	var meta: Dictionary = model.get("meta", {})
	return {"total": total, "ref": ref, "season": int(meta.get("season", 1)), "today": str(meta.get("calendarToday", meta.get("date", ""))), "n": squad.size()}

static func part_masse(player: Dictionary, ctx: Dictionary) -> float:
	var w: Variant = player.get("salary")
	return float(w) / float(ctx.total) if (w is int or w is float) and float(ctx.get("total", 0)) > 0 else -1.0

## Part des minutes de l'homme le plus utilisé (1 = toujours sur le terrain).
static func temps_de_jeu(player: Dictionary, ctx: Dictionary) -> float:
	return clampf(float(player.get("minutes", 0)) / maxf(1.0, float(ctx.get("ref", 1))), 0.0, 1.0)

## Conseil du staff envoyé par le moteur ("aucun" sans contrat professionnel ou hors mode Monde).
static func conseil(player: Dictionary) -> String:
	var c: Variant = player.get("conseilStaff")
	var id := str(c.get("conseil", "")) if c is Dictionary else ""
	return id if CONSEILS.has(id) else "aucun"

static func build(owner_app: Control) -> Control:
	var view: Control = load("res://ui/contract_review.gd").new()
	view.app = owner_app
	view._build()
	return view

static func action_id(prefix: String, player_id: String) -> String:
	return prefix + "_" + player_id.sha256_text().substr(0, 16)

## État de vente court pour la colonne Statut ("" : pas de vente en cours).
static func sale_caption(player: Dictionary) -> String:
	return Sales.short(player)

static func projected_mark(player: Dictionary, key: String) -> String:
	return G.potential_text(player) if key == "potential" else G.rating_text(player,true)

# SquadCanvas preloads this view: resolve its canonical presentation at runtime
# to reuse the principal-role rules without a circular preload dependency.
static func position_caption(player: Dictionary) -> String:
	return load("res://ui/immersive08/squad_canvas.gd").primary_caption(player)

static func position_text(player: Dictionary) -> String:
	var caption := position_caption(player)
	match caption:
		"Troisième ligne aile": return "3E L"
		"Troisième ligne centre": return "8"
		_: return caption

static func horizon(player: Dictionary) -> int:
	var value: Variant = player.get("contractEnd")
	return int(value) if (value is int or value is float) and float(value) == floorf(float(value)) and int(value) >= 0 else -1

static func filtered(players: Array, filters: Dictionary) -> Array:
	var result: Array = []
	for player: Dictionary in players:
		var ending := horizon(player)
		if int(filters.get("season", 0)) > 0 and ending != int(filters.season): continue
		var status := str(filters.get("status", "Tous"))
		var quote: Dictionary = player.get("renewal", {})
		var discussion: String = str(quote.get("negotiation", {}).get("status", ""))
		if status == "Prolongation accessible" and not bool(quote.get("available", false)): continue
		if status == "Discussion en cours" and not discussion in ["counter", "ready"]: continue
		if status == "Échanges clos" and discussion != "withdrawn": continue
		if str(filters.get("status", "Tous")) == "Sans contrat renseigné" and ending >= 0: continue
		if str(filters.get("precision", "Toutes")) == "Échéance connue" and ending < 0: continue
		if str(filters.get("precision", "Toutes")) == "Non renseignée" and ending >= 0: continue
		if str(filters.get("position", "Tous")) != "Tous" and position_caption(player) != str(filters.position): continue
		var query := U.fold(str(filters.get("search", "")).strip_edges())
		if not query.is_empty() and not U.fold(str(player.get("name", "")) + " " + position_caption(player) + " " + position_text(player) + " " + str(player.get("pos", ""))).contains(query): continue
		var ctx: Dictionary = filters.get("ctx", {})
		if not str(filters.get("tranche", "")).is_empty() and tranche(mois_restants(player, str(ctx.get("today", "")))) != str(filters.tranche): continue
		if not str(filters.get("conseil", "")).is_empty() and conseil(player) != str(filters.conseil): continue
		result.append(player)
	var sort_key := str(filters.get("sort", "contractEnd"))
	if not sort_key in SORT_KEYS: sort_key = "contractEnd"
	var descending := bool(filters.get("descending", false))
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		var first: Variant = sort_value(a, sort_key, bool(filters.get("live", false)))
		var second: Variant = sort_value(b, sort_key, bool(filters.get("live", false)))
		if first == null and second != null: return false
		if first != null and second == null: return true
		var comparison := 0
		if first != null:
			if first is String: comparison = U.fold(first).naturalnocasecmp_to(U.fold(str(second)))
			else: comparison = -1 if float(first) < float(second) else 1 if float(first) > float(second) else 0
		if comparison == 0: return str(a.id) < str(b.id)
		return comparison > 0 if descending else comparison < 0)
	return result

static func sort_value(player: Dictionary, key: String, live: bool = false) -> Variant:
	if key in ["rating","potential"]: return Notation.tri_champ(player,key,true)
	if key == "pos": return load("res://ui/immersive08/squad_canvas.gd").sort_value(player, "Poste")
	if key == "contractEnd": return horizon(player) if horizon(player) >= 0 else null
	if key == "share": key = "salary"
	if key == "playtime": key = "minutes"
	if key == "conseil": return CONSEIL_ORDRE.find(conseil(player))
	if key == "renewal": return renewal_reason(player, live) if player.get("renewal") is Dictionary and not player.renewal.is_empty() else null
	var value: Variant = player.get(key)
	if key in ["rating","potential","age","salary","minutes"]:
		return value if (value is int or value is float) and is_finite(float(value)) else null
	return str(value) if value != null and not str(value).strip_edges().is_empty() else null

static func coverage(players: Array, season: int) -> Array:
	var groups: Dictionary = {}
	for player: Dictionary in players:
		var position := position_caption(player)
		if position.strip_edges().is_empty() or position == "—": position = "Poste non renseigné"
		if not groups.has(position): groups[position] = {"position":position,"total":0,"ending":0,"remaining":0,"unknown":0}
		groups[position].total += 1
		var ending := horizon(player)
		if ending < 0: groups[position].unknown += 1
		elif ending <= season: groups[position].ending += 1
		else: groups[position].remaining += 1
	var result: Array = groups.values()
	result.sort_custom(func(a: Dictionary, b: Dictionary):
		if a.ending != b.ending: return a.ending > b.ending
		return str(a.position).naturalnocasecmp_to(str(b.position)) < 0)
	return result

static func renewal_reason(player: Dictionary, live: bool) -> String:
	if live: return "Match en cours : prolongation indisponible"
	var quote: Dictionary = player.get("renewal", {})
	if not str(quote.get("reason", "")).is_empty(): return str(quote.reason)
	if quote.get("negotiation", {}).get("status") == "withdrawn": return "Échanges clos pour cette journée"
	return "Prolongation accessible" if bool(quote.get("available", false)) else "Prolongation indisponible actuellement"

## Forme courte pour la colonne PROLONGATION (le motif complet reste en infobulle).
static func renewal_short(player: Dictionary, live: bool) -> String:
	var full := renewal_reason(player, live)
	if live: return "Match en cours"
	if full.begins_with("Prolongation accessible"): return "Accessible"
	if full.begins_with("Prolongation indisponible"): return "Indisponible"
	if full.begins_with("Échanges clos"): return "Échanges clos"
	if full.begins_with("Prêt entrant"): return "Prêt entrant"
	if full.begins_with("Pré-contrat"): return "Pré-contrat"
	return full

## Texte court de la pastille à côté de la case (le texte complet est en infobulle).
static func delegation_chip(model: Dictionary, enabled: bool) -> String:
	if not enabled: return "Tu gères seul"
	var delegation: Dictionary = model.get("decisions", {}).get("delegation", {}) if model.get("decisions") is Dictionary and model.decisions.get("delegation") is Dictionary else {}
	var label := str(delegation.get("contractsPolicyLabel", ""))
	return "Staff · mars" + (" · " + label if not label.is_empty() else "")

## Texte sous la case selon l'état coché (testable sans interface).
static func delegation_detail(model: Dictionary, enabled: bool) -> String:
	if not enabled: return "Tu gères seul les prolongations : les contrats non prolongés partent à leur échéance."
	var delegation: Dictionary = model.get("decisions", {}).get("delegation", {}) if model.get("decisions") is Dictionary and model.decisions.get("delegation") is Dictionary else {}
	var text := "Le directeur sportif tranche en mars les échéances que tu n'as pas réglées, dans la masse que le club s'autorise et sous le plafond de la ligue ; chaque décision arrive au courrier, annulable."
	var label := str(delegation.get("contractsPolicyLabel", ""))
	if not label.is_empty(): text += " Consigne : %s." % label
	var decided: Array = delegation.get("contractsDecided", []) if delegation.get("contractsDecided") is Array else []
	if not decided.is_empty():
		var kept := 0
		var released := 0
		for entry: Variant in decided:
			if not entry is Dictionary: continue
			# Annulée par le manager : il part ; « prolonger quand même » : il reste.
			var state_name := str(entry.get("state", ""))
			if state_name == "force" or (state_name == "actif" and str(entry.get("decision", "")) == "prolonge"): kept += 1
			elif state_name == "annule" or str(entry.get("decision", "")) == "libere": released += 1
		text += " Cette saison : %d prolongé%s, %d laissé%s partir." % [kept, "s" if kept > 1 else "", released, "s" if released > 1 else ""]
	return text

static func duree_texte(mois: float) -> String:
	if mois < 0: return "?"
	var m := int(floorf(mois))
	if m < 12: return "%d mois" % m
	var ans := m / 12
	var reste := m % 12
	return ("%d an%s" % [ans, "s" if ans > 1 else ""]) + (" %d m" % reste if reste > 0 else "")

static func pourcent(part: float) -> String:
	return "—" if part < 0 else ("%.1f %%" % (part * 100.0)).replace(".", ",")
