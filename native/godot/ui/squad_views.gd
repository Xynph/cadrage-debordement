extends "res://ui/squad_views_marche.gd"
## Vues génériques Effectif, Composition, Préparation et Recrutement, fiche joueur et fenêtres de contrat (découpe sans changement).
## Chaîne d'héritage : socle ← fiche joueur ← liste de l'Effectif ← Composition et Préparation ← Recrutement ← ce fichier (public).
const Parties = preload("res://ui/squad_views_marche.gd")

## Points d'entrée publics (main_rendu, shell, fiches, tests) : redéfinis ici, car `has_method` d'un script ne voit pas les statiques hérités.
static func squad(app: Control) -> Control: return Parties.squad(app)
static func lineup(app:Control) -> Control: return Parties.lineup(app)
static func preparation(app:Control) -> Control: return Parties.preparation(app)
static func market(app:Control) -> Control: return Parties.market(app)
static func comparison(app:Control) -> void: Parties.comparison(app)
static func contract(app:Control,p:Dictionary,recruiting:bool) -> void: Parties.contract(app,p,recruiting)
static func position_label(pos:String,compact:bool=false) -> String: return Parties.position_label(pos,compact)
static func player_load_unavailable_reason(app: Control) -> String: return Parties.player_load_unavailable_reason(app)
static func bleus_resume(app: Control) -> Dictionary: return Parties.bleus_resume(app)
static func quota_line(quota: Dictionary) -> String: return Parties.quota_line(quota)
static func quota_tooltip(quota: Dictionary) -> String: return Parties.quota_tooltip(quota)
static func _positions(source:Array) -> Array: return Parties._positions(source)
static func _profile_contexts(parent:VBoxContainer,p:Dictionary,app:Control) -> void: Parties._profile_contexts(parent,p,app)
