extends RefCounted
## Display convention only. Every engine wage and monetary ledger stays unchanged.
const PERIODS := ["weekly","monthly","annual"]
const CONVENTION := "Affichage uniquement : mois = salaire hebdomadaire × 52 ÷ 12 ; année = salaire hebdomadaire × 52. Les semaines comptables et les débits de la carrière restent inchangés."
static var period := "weekly"

static func configure(value: String) -> bool:
	if value not in PERIODS: return false
	period = value
	return true

static func factor(unit: String = "") -> float:
	var chosen := period if unit.is_empty() else unit
	return 52.0/12.0 if chosen == "monthly" else 52.0 if chosen == "annual" else 1.0

static func period_label(short: bool = false) -> String:
	return {"weekly":"/sem.","monthly":"/mois","annual":"/an"}[period] if short else {"weekly":"par semaine","monthly":"par mois","annual":"par an"}[period]

static func field_label() -> String:
	return "Salaire " + period_label()

static func amount(weekly: Variant) -> String:
	if not (weekly is int or weekly is float) or not is_finite(float(weekly)): return "—"
	var converted := snappedf(float(weekly)*factor(),0.01)
	var negative := converted < 0
	var raw := "%.2f" % absf(converted)
	var pieces := raw.split(".")
	var digits := pieces[0]
	var grouped := ""
	for index in digits.length():
		if index > 0 and (digits.length()-index)%3 == 0: grouped += " "
		grouped += digits[index]
	var decimals := ","+pieces[1] if pieces[1] != "00" else ""
	return ("−" if negative else "") + grouped + decimals + " €"

static func format(weekly: Variant) -> String:
	return amount(weekly)+" "+period_label(true)

static func bind_input(input: SpinBox, weekly: float, minimum: float, maximum: float, _step: float = 100) -> void:
	var rate := factor()
	input.set_meta("salary_period",period)
	input.set_meta("salary_initial_weekly",weekly)
	input.min_value = snappedf(minimum*rate,0.01)
	input.max_value = snappedf(maximum*rate,0.01)
	# Display cents without quantizing the source weekly amount on initialization.
	input.step = 1.0 if period == "weekly" else 0.01
	input.set_value_no_signal(snappedf(weekly*rate,0.01))
	input.set_meta("salary_initial_display",input.value)
	input.suffix = "€ "+period_label(true)
	input.tooltip_text = CONVENTION + " La saisie est arrondie à l’euro hebdomadaire le plus proche avant confirmation."

static func input_weekly(input: SpinBox) -> int:
	if input.has_meta("salary_initial_display") and is_equal_approx(input.value,float(input.get_meta("salary_initial_display"))):
		return roundi(float(input.get_meta("salary_initial_weekly")))
	var unit := str(input.get_meta("salary_period",period))
	return roundi(input.value/factor(unit))

static func set_input_weekly(input: SpinBox, weekly: float) -> void:
	var converted := snappedf(weekly*factor(str(input.get_meta("salary_period",period))),0.01)
	input.set_meta("salary_initial_weekly",weekly)
	input.set_meta("salary_initial_display",converted)
	input.value = converted
