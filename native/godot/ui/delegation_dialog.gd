extends ConfirmationDialog
## « Déléguer le match » avant le coup d'envoi (écran Match). Une case « Confier aussi la composition au staff »,
## cochée par défaut, décochable : cochée, le staff refait la feuille du jour avec la sélection automatique
## (comme le bouton « Sélection du staff », règle JIFF comprise) avant le match ; décochée, la feuille du
## joueur est jouée telle quelle. Le choix est mémorisé dans la carrière (decisions.delegation.matchLineup)
## et proposé tel quel la fois suivante.
## Commandes : begin_match { delegated: true, composition } puis delegate (chaînées par app.queued_action).
const C = preload("res://ui/immersive08/components.gd")
const Dialogs = preload("res://ui/immersive08/dialogs.gd")
const Avis = preload("res://guide/gabi_avis.gd")

var app: Control
var case_composition: CheckBox
var detail: Label

## Valeur mémorisée du choix (cochée tant que le joueur n'a rien décidé, y compris sur une ancienne sauvegarde).
static func composition_confiee(model: Dictionary) -> bool:
	var delegation: Variant = model.get("decisions", {}).get("delegation") if model.get("decisions") is Dictionary else null
	return not (delegation is Dictionary and delegation.get("matchLineup", true) == false)

static func ouvrir(owner_app: Control) -> ConfirmationDialog:
	if owner_app.waiting or not owner_app._live().is_empty() or not owner_app.model.get("next") is Dictionary: return null
	owner_app._clear_dialogs()
	var dialog: ConfirmationDialog = load("res://ui/delegation_dialog.gd").new()
	dialog.app = owner_app
	dialog._build()
	return dialog

func _build() -> void:
	name = "MatchDelegationDialog"
	title = "Déléguer le match"
	get_ok_button().text = "DÉLÉGUER LE MATCH"
	get_cancel_button().text = "ANNULER"
	app._prepare_dialog(self, 640)
	var body := C.v(12)
	body.name = "MatchDelegationBody"
	body.custom_minimum_size.x = 600
	add_child(body)
	body.add_child(C.wrap("L’adjoint joue la rencontre à votre place, du coup d’envoi au coup de sifflet final. Vous retrouverez le résultat, le récit et les notes du match.", 18, C.IVORY))
	case_composition = CheckBox.new()
	case_composition.name = "MatchDelegationComposition"
	case_composition.text = "Confier aussi la composition au staff"
	case_composition.button_pressed = composition_confiee(app.model)
	case_composition.tooltip_text = "Le staff refait la feuille du jour avec la sélection automatique avant le match : les joueurs fatigués sont remplacés, la règle JIFF reste respectée."
	case_composition.custom_minimum_size.y = 36
	case_composition.add_theme_font_size_override("font_size", maxi(16, C.px(20)))
	case_composition.toggled.connect(func(_value: bool): _detail())
	body.add_child(case_composition)
	detail = C.wrap("", 16, C.MUTED)
	detail.name = "MatchDelegationDetail"
	body.add_child(detail)
	_detail()
	confirmed.connect(_valider)
	confirmed.connect(queue_free)
	canceled.connect(queue_free)
	app.add_child(self)
	Dialogs.show_centered(self, Vector2i(640, 210))
	get_ok_button().call_deferred("grab_focus")

func _detail() -> void:
	var fatigue := Avis.fatigue_donnees(app.model)
	var fatigues := int(fatigue.get("count", 0)) if not fatigue.is_empty() else 0
	if case_composition.button_pressed:
		detail.text = "Le staff refait la feuille avant le coup d’envoi : les joueurs fatigués se reposent, les mieux placés jouent. Vous pouvez décocher pour garder votre feuille."
	else:
		detail.text = "Votre feuille est jouée telle quelle%s. Sans rotation, le groupe s’épuise de semaine en semaine." % (" : %d titulaire%s sous 70 %% de condition" % [fatigues, "s" if fatigues > 1 else ""] if fatigues > 0 else "")

func _valider() -> void:
	var composition := case_composition.button_pressed
	# Le coup d'envoi puis la délégation du match : la seconde commande part dès la réponse de la première.
	if app._command("begin_match", {"delegated": true, "composition": composition}):
		app.queued_action = {"command": "delegate", "payload": {}, "target_route": ""}
