extends AcceptDialog
## Offres reçues pour les joueurs du club (moteur : native/engine/vente-joueurs.cjs, vue `sales` et `squad[].sale`).
## Ouverte depuis Recrutement (« Offres reçues »), la fiche d'un joueur (carte Marché des transferts), l'Effectif
## (vue Contrats) et le courrier « offre_transfert » de la Réception. Réponses : accepter (confirmation : caisse,
## effectif après la vente, part rendue au budget de transferts), demander plus une fois (+5, +10 ou +15 %),
## refuser ; retrait d'un joueur proposé. Hors période des mutations, accepter conclut un accord effectif à l'ouverture.
## Affichage seul : le moteur valide chaque réponse et rend la raison d'un refus, écrite telle quelle.
const G = preload("res://ui/carnet_skin.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const EnPlace = preload("res://ui/confirmation_en_place.gd")
## Tailles demandées au thème carnet (game_skin.reading_size : 18 → 13 px, 23 → 16 px) ; lisible() relève le reste à 13 px.
const TEXTE := 18
const NOTE := 18
const LISIBLE := 13
var app: Control
var rows: VBoxContainer
var message: Label
var pending := false

## Bouton d'accès (écrans au gabarit libre) : « Offres reçues · n ».
static func caption(model: Dictionary) -> String:
	var n := (sales(model).get("offers", []) as Array).size()
	return "Offres reçues · %d" % n if n > 0 else "Offres reçues"

static func sales(model: Dictionary) -> Dictionary:
	var data: Variant = model.get("sales")
	return data if data is Dictionary else {}

## État de vente d'un joueur de l'effectif en une phrase ("" : rien à signaler).
static func status(player: Dictionary) -> String:
	var sale: Variant = player.get("sale")
	if not sale is Dictionary: return ""
	if sale.get("pending") is Dictionary: return str(sale.pending.get("label", "Vente en attente."))
	if sale.get("offerId") is String: return "Offre reçue : à traiter dans Offres reçues."
	if bool(sale.get("listed", false)): return "Proposé aux autres clubs · valeur estimée " + G.euros(sale.get("value", 0))
	return ""

## État court pour une colonne (« Départ prévu », « Offre reçue », « En vente ») ; "" sinon.
static func short(player: Dictionary) -> String:
	var sale: Variant = player.get("sale")
	if not sale is Dictionary: return ""
	if sale.get("pending") is Dictionary: return "Départ prévu"
	if sale.get("offerId") is String: return "Offre reçue"
	if bool(sale.get("listed", false)): return "En vente"
	return ""

## Proposer ou retirer un joueur (commande sale_list) ; la raison d'un blocage est écrite à côté du bouton.
static func toggle(owner_app: Control, player: Dictionary) -> bool:
	var sale: Dictionary = player.get("sale", {}) if player.get("sale") is Dictionary else {}
	return owner_app._command("sale_list", {"playerId":str(player.get("id", "")), "listed":not bool(sale.get("listed", false))})

static func open(owner_app: Control) -> AcceptDialog:
	owner_app._clear_dialogs()
	var view: AcceptDialog = load("res://ui/player_sales_view.gd").new()
	view.app = owner_app
	view._build()
	return view

func _build() -> void:
	name = "PlayerSales"
	title = "Offres reçues"
	get_ok_button().text = "FERMER"
	app._prepare_dialog(self, 900)
	var scroll := ScrollContainer.new()
	scroll.name = "PlayerSalesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	var body := G.v(10)
	G.fill(body, true)
	scroll.add_child(body)
	message = G.wrap("", TEXTE)
	message.name = "SalesMessage"
	message.visible = false
	body.add_child(message)
	rows = G.v(10)
	rows.name = "SalesRows"
	body.add_child(rows)
	_redraw()
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	app.add_child(self)
	app.bridge.model_changed.connect(_on_model)
	app.bridge.command_failed.connect(_on_failure)
	Dialogs.show_centered(self, Vector2i(900, 600))
	lisible(body)

func _clear() -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()

func _redraw() -> void:
	_clear()
	var data := sales(app.model)
	var window: Dictionary = data.get("window", {}) if data.get("window") is Dictionary else {}
	var periode := G.wrap(_window_text(window), TEXTE, G.INK)
	periode.name = "SalesWindow"
	rows.add_child(periode)
	var accords: Array = data.get("pending", [])
	if not accords.is_empty():
		rows.add_child(G.section("Ventes en attente"))
		for accord: Dictionary in accords:
			var line := G.wrap(str(accord.get("label", "")), TEXTE, G.INK)
			line.name = "SalePending_" + str(accord.get("id", "")).validate_node_name()
			rows.add_child(line)
	rows.add_child(G.section("Offres reçues"))
	var offers: Array = data.get("offers", [])
	if offers.is_empty():
		var empty := G.wrap("Aucune offre en cours. Propose un joueur aux autres clubs depuis sa fiche ou l’Effectif : les offres arrivent à la fin de la semaine. Les clubs peuvent aussi faire une offre pour tes meilleurs joueurs.", TEXTE)
		empty.name = "SalesEmpty"
		rows.add_child(empty)
	for offer: Dictionary in offers: _offer_card(offer)
	var listed: Array = data.get("listed", [])
	rows.add_child(G.section("Joueurs proposés aux autres clubs"))
	if listed.is_empty():
		rows.add_child(G.wrap("Aucun joueur proposé pour l’instant.", TEXTE))
	for entry: Dictionary in listed:
		var row := G.h(10)
		row.name = "SaleListed_" + str(entry.get("playerId", "")).validate_node_name()
		rows.add_child(row)
		var text := G.wrap("%s · %s · %s ans · valeur estimée %s" % [str(entry.get("name", "")), str(entry.get("pos", "")), G.n(entry.get("age", "—")), G.euros(entry.get("value", 0))], TEXTE, G.INK)
		G.fill(text)
		row.add_child(text)
		var remove := G.button("RETIRER DU MARCHÉ", func(): _send("sale_list", {"playerId":str(entry.get("playerId", "")), "listed":false}))
		remove.name = "SaleUnlist"
		remove.disabled = app.waiting or pending
		row.add_child(remove)
	lisible(rows)

## Textes et boutons à 13 px au moins (GDD vente-joueurs, 1280×720) : le style immersif des tuiles et des boîtes
## (legacy_style.gd) repose les tailles à l'image suivante avec un plancher de 12 px ; on relève donc aussi après lui.
static func lisible(node: Node) -> void:
	_relever(node)
	if node.is_inside_tree(): node.get_tree().process_frame.connect(func(): _relever(node), CONNECT_ONE_SHOT)
	else: node.tree_entered.connect(func(): lisible(node), CONNECT_ONE_SHOT)

static func _relever(node: Node) -> void:
	if not is_instance_valid(node): return
	var controls: Array[Node] = [node]
	controls.append_array(node.find_children("*", "Label", true, false))
	controls.append_array(node.find_children("*", "Button", true, false))
	for n in controls:
		if (n is Label or n is Button) and (n as Control).get_theme_font_size("font_size") < LISIBLE:
			(n as Control).add_theme_font_size_override("font_size", LISIBLE)

func _window_text(window: Dictionary) -> String:
	if str(window.get("mode", "")) != "fenetres": return "Ventes possibles toute la saison, hors match."
	var periods := PackedStringArray()
	for p: Dictionary in window.get("periods", []):
		periods.append("du %s au %s" % [_day(str(p.get("start", ""))), _day(str(p.get("end", ""))) ])
	var text := "Période des mutations : " + ", ".join(periods) + "."
	if bool(window.get("open", true)): return text + " Elle est ouverte : une vente acceptée est conclue tout de suite."
	return text + " Hors période : une vente acceptée devient un accord effectif le %s ; le joueur reste et joue jusque-là." % str(window.get("reopensLabel", ""))

static func _day(md: String) -> String:
	var months := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
	var parts := md.split("-")
	if parts.size() != 2: return md
	var day := int(parts[1])
	return ("1er" if day == 1 else str(day)) + " " + months[clampi(int(parts[0]) - 1, 0, 11)]

func _offer_card(offer: Dictionary) -> void:
	var id := str(offer.get("id", ""))
	var card := G.card(rows)
	card.name = "SaleOffer_" + id.validate_node_name()
	card.add_child(G.label("%s · %s · %s ans" % [str(offer.get("name", "")), str(offer.get("pos", "")), G.n(offer.get("age", "—"))], 23, G.INK, true))
	var fee := G.wrap("%s propose %s · valeur estimée %s" % [str(offer.get("buyer", "")), G.euros(offer.get("fee", 0)), G.euros(offer.get("value", 0))], TEXTE, G.INK)
	fee.name = "SaleOfferFee"
	card.add_child(fee)
	var details := PackedStringArray()
	details.append("Offre spontanée : tu ne l’avais pas proposé." if bool(offer.get("spontaneous", false)) else "Joueur proposé aux autres clubs.")
	details.append("Valable jusqu’à la fin de la semaine prochaine." if int(offer.get("weeksLeft", 0)) > 0 else "Valable jusqu’à la fin de la semaine.")
	if offer.get("countered") != null: details.append("Tu as déjà demandé +%d %% : accepte ou refuse." % int(offer.countered))
	card.add_child(G.wrap(" ".join(details), NOTE))
	var accept: Dictionary = offer.get("accept", {})
	var counter: Dictionary = offer.get("counter", {})
	var deferred: Variant = offer.get("deferred")
	if deferred is Dictionary and bool(accept.get("available", false)):
		var note := G.wrap(str(deferred.get("note", "")), NOTE, G.INK)
		note.name = "SaleDeferredNote"
		card.add_child(note)
	if not bool(accept.get("available", false)):
		var reason := G.wrap(str(accept.get("reason", "")), TEXTE, G.ALERT)
		reason.name = "SaleAcceptReason"
		card.add_child(reason)
	var actions := G.h(8)
	card.add_child(actions)
	var yes := G.button("ACCEPTER…" if not deferred is Dictionary else "CONCLURE L’ACCORD…", func(): _confirm(offer), true)
	yes.name = "SaleAccept"
	yes.disabled = app.waiting or pending or not bool(accept.get("available", false))
	if yes.disabled and not str(accept.get("reason", "")).is_empty(): yes.tooltip_text = str(accept.reason)
	actions.add_child(yes)
	for percent: Variant in counter.get("percents", [5, 10, 15]):
		var more := G.button("DEMANDER +%d %%" % int(percent), func(): _send("sale_answer", {"offerId":id, "action":"counter", "percent":int(percent)}))
		more.name = "SaleCounter%d" % int(percent)
		more.disabled = app.waiting or pending or not bool(counter.get("available", false))
		if more.disabled: more.tooltip_text = str(counter.get("reason", ""))
		actions.add_child(more)
	var no := G.button("REFUSER", func(): _send("sale_answer", {"offerId":id, "action":"decline"}))
	no.name = "SaleDecline"
	no.disabled = app.waiting or pending
	actions.add_child(no)
	if not bool(counter.get("available", false)) and not str(counter.get("reason", "")).is_empty() and offer.get("countered") == null:
		var why := G.wrap(str(counter.reason), NOTE, G.ALERT)
		why.name = "SaleCounterReason"
		card.add_child(why)

## Lignes de la confirmation (caisse, effectif, budget, feuille, JIFF), aussi lues par le test Godot.
static func confirmation_lines(offer: Dictionary, model: Dictionary) -> Array[Dictionary]:
	var deferred: Variant = offer.get("deferred")
	var later := deferred is Dictionary
	var lines: Array[Dictionary] = []
	var fee := G.euros(offer.get("fee", 0))
	if later:
		lines.append({"id":"SaleConfirmCash", "text":"Caisse : +%s le %s, au départ du joueur." % [fee, str(deferred.get("dateLabel", ""))]})
	else:
		lines.append({"id":"SaleConfirmCash", "text":"Caisse : +%s (après la vente : %s)." % [fee, G.euros(offer.get("cashAfter", 0))]})
	var squad := "Effectif après la vente : %d joueurs professionnels." % int(offer.get("squadAfter", 0))
	var fillers := int(offer.get("fillers", 0))
	if fillers > 0: squad += " Le club signera %d joueur%s de complément pour revenir à 40." % [fillers, "s" if fillers > 1 else ""]
	if later: squad = "Il reste au club et joue jusqu’au %s. " % str(deferred.get("dateLabel", "")) + squad
	lines.append({"id":"SaleConfirmSquad", "text":squad})
	var budget := int(offer.get("budgetReturn", 0))
	var active: Variant = model.get("finance", {}).get("transferBudget")
	if active is Dictionary and bool(active.get("actif", false)):
		lines.append({"id":"SaleConfirmBudget", "text":("Budget de transferts : %s reviennent à l’enveloppe%s." % [G.euros(budget), " à son départ" if later else ""]) if budget > 0 else "Budget de transferts : l’enveloppe est à son plafond, rien n’y revient."})
	if bool(offer.get("onSheet", false)): lines.append({"id":"SaleConfirmSheet", "text":"Il figure sur ta feuille de match : vérifie ta feuille à 23 après la vente."})
	if not str(offer.get("jiff", "")).is_empty(): lines.append({"id":"SaleConfirmJiff", "text":str(offer.jiff)})
	# Conséquences légères (vestiaire, supporters, président) calculées par le moteur.
	var consequences: Array = offer.get("consequences", []) if offer.get("consequences") is Array else []
	if not consequences.is_empty(): lines.append({"id":"SaleConfirmConsequences", "text":" ".join(PackedStringArray(consequences))})
	return lines

## Confirmation EN PLACE (deux temps, aucune fenêtre) : sous la carte de l'offre, phrase d'engagement, lignes de conséquence,
## « Vendre X » / « Annuler » (focus sur Annuler). Le message de réponse du moteur s'affiche en tête de la page.
func _confirm(offer: Dictionary) -> void:
	if pending or app.waiting: return
	var later := offer.get("deferred") is Dictionary
	var heading_text := "%s rejoint %s pour %s. La vente est définitive." % [str(offer.get("name", "")), str(offer.get("buyer", "")), G.euros(offer.get("fee", 0))]
	if later: heading_text = "Accord avec %s : %s partira le %s contre %s. L’accord est définitif." % [str(offer.get("buyer", "")), str(offer.get("name", "")), str(offer.deferred.get("dateLabel", "")), G.euros(offer.get("fee", 0))]
	var lines: Array = [{"id":"SaleConfirmHeading", "text":heading_text}]
	lines.append_array(confirmation_lines(offer, app.model))
	var verbe := ("Conclure l’accord avec " + str(offer.get("buyer", ""))) if later else "Vendre " + str(offer.get("name", ""))
	var card := rows.get_node_or_null("SaleOffer_" + str(offer.get("id", "")).validate_node_name())
	var bloc := EnPlace.ouvrir(app, rows, "SaleConfirmation", "Conclure l’accord" if later else "Vendre " + str(offer.get("name", "")), lines, verbe, func():
		_send("sale_answer", {"offerId":str(offer.get("id", "")), "action":"accept", "confirmed":true}), card)
	lisible(bloc)
func _send(command: String, payload: Dictionary) -> void:
	if pending or app.waiting: return
	pending = true
	message.visible = true
	message.text = "Réponse en cours…"
	if not app._command(command, payload): _on_failure("Action indisponible pour l’instant.")

func _on_model(value: Dictionary) -> void:
	if not is_instance_valid(rows): return
	if pending and app.bridge.last_response_ok and app.last_command in ["sale_answer", "sale_list"]:
		pending = false
		var meta: Dictionary = value.get("meta", {})
		var receipt: Variant = meta.get("saleAnswer", meta.get("saleList"))
		message.visible = receipt is Dictionary
		if receipt is Dictionary: message.text = str(receipt.get("message", ""))
		message.add_theme_color_override("font_color", G.INK)
	_redraw()

func _on_failure(text: String) -> void:
	if not pending: return
	pending = false
	message.visible = true
	message.text = text
	message.add_theme_color_override("font_color", G.ALERT)
	_redraw()
