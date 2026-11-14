extends RefCounted
# Only known, authored projection clauses are adapted here. Callers identify the
# domain and field explicitly; player names, quotations, errors and drafts never
# pass through a general text filter. Career data and provenance stay untouched.
const CLAUSES = {
	"support": {
		"Arbitrages fictifs du jeu. ": "",
		"Le suivi médical générique ne représente ni une commotion, ni un protocole HIA, ni un avis de santé.": "Les commotions et les protocoles HIA ne sont pas couverts par ce suivi.",
		" Les budgets sont fictifs.": ""
	},
	"academy": {
		"Recrutement au centre à partir de16 ans dans cette simulation.": "Recrutement au centre à partir de 16 ans.",
		"44 centres fictifs simulés ; compétitions juniors indépendantes, sans homologation officielle.": "44 centres de formation et leurs compétitions juniors. Les autorisations nécessaires restent à vérifier."
	},
	"relationships": {
		"Relations, traits et réactions simulés. ": ""
	},
	"strategy": {
		" Montants de jeu fictifs.": "",
		"Le score d’organisation suit les projets et missions. Seul le bilan moteur modifie la confiance du président ; ces projets ne donnent pas de bonus de match.": "L’organisation du club évolue avec les projets et les missions. La confiance du président dépend du bilan ; ces projets n’améliorent pas directement les performances en match.",
		"Prévisions fictives : aucune recette de billetterie supplémentaire encaissée. Les matchs conservent leur recette moteur unique.": "Prévisions de fréquentation : aucune recette de billetterie supplémentaire n’est comptabilisée. La recette de chaque match reste enregistrée une seule fois."
	},
	"playbook": {
		"Ces compromis de simulation ne garantissent aucun résultat.": "Ces choix ne garantissent aucun résultat."
	},
	"scouting": {
		"Agents libres majeurs issus des centres ou du bassin abstrait des petits clubs.": "Agents libres majeurs issus des centres de formation ou des petits clubs.",
		"Mission existante : 5 000 € fictifs, deux journées de travail, tous agents libres répondant aux critères.": "Mission : 5 000 €, deux journées de travail, tous les agents libres répondant aux critères.",
		"Bassin des petits clubs (simulation abstraite)": "Petits clubs"
	},
	"performance": {
		"essais et tirs de pénalité attribués par les scènes du moteur.": "essais et tirs de pénalité issus des actions enregistrées.",
		"Statistiques collectives du moteur ; les données absentes restent inconnues.": "Statistiques collectives des rencontres ; les données absentes restent inconnues."
	},
	"youth": {
		"Repère de simulation à 18 ans, pas une homologation de compétition.": "Repère de parcours : 18 ans."
	},
	"competition": {
		"Calendrier fictif personnalisé.": "Calendrier personnalisé.",
		"14 clubs aller-retour : carrière fictive jouable avec les phases finales historiques.": "14 clubs aller-retour : une carrière peut être lancée avec les phases finales prévues."
	},
	"interclub": {
		"Garde de jeu fictive : 28 professionnels après départ": "Effectif minimum après un départ : 28 professionnels",
		"Accord de libération anticipée fictif.": "Accord de libération anticipée.",
		"Offres fictives recalculées à la clôture : salaire, indemnité, besoin public et identifiant départagent les clubs.": "Les offres sont réexaminées à la clôture selon le salaire, l’indemnité et les besoins des clubs."
	}
}

static func notice(domain: String, source: Variant) -> String:
	var text := "" if source == null else str(source)
	for clause: String in CLAUSES.get(domain, {}): text = text.replace(clause, CLAUSES[domain][clause])
	return text.strip_edges()

# Two retired system-news templates can still exist in saved careers. Match
# their authored structure and replace only the trailing origin marker. Names
# and all unrelated quotations remain byte-for-byte intact.
static var _legacy_competition: RegEx
static var _legacy_direct: RegEx

static func news(source: String) -> String:
	if _legacy_competition == null:
		var space := "[ \\x{00A0}\\x{202F}]"
		var amount := "[0-9]+(?:" + space + "[0-9]{3})*" + space + "€"
		_legacy_competition = RegEx.new()
		_legacy_competition.compile("^.+ rejoint .+ après concurrence entre [1-9][0-9]* club\\(s\\), pour " + amount + " \\(accord fictif\\)\\.$")
		_legacy_direct = RegEx.new()
		_legacy_direct.compile("^.+ rejoint .+ depuis .+ : accord fictif de " + amount + ", fin de contrat (?:S[1-9][0-9]*|[0-9]{4}-[0-9]{4})\\.$")
	# Courrier historique de fin de saison : « N contrat(s) expire(nt) » devient un accord correct.
	var legacy_expiry := " contrat(s) expire(nt) "
	var at_expiry := source.find(legacy_expiry)
	if at_expiry > 0 and source.substr(0, at_expiry).is_valid_int():
		var count := source.substr(0, at_expiry).to_int()
		return source.substr(0, at_expiry) + (" contrat expire " if count == 1 else " contrats expirent ") + source.substr(at_expiry + legacy_expiry.length())
	if _legacy_competition.search(source) != null:
		return source.trim_suffix(" (accord fictif).") + "."
	if _legacy_direct.search(source) != null:
		var marker := " : accord fictif de "
		var at := source.rfind(marker)
		return source.left(at) + " : accord de " + source.substr(at + marker.length())
	return source
