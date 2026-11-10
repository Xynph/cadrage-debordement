extends RefCounted
## Display convention only. Every engine wage and monetary ledger stays unchanged.
const PERIODS := ["weekly","monthly","annual"]
const CONVENTION := "Montants affichés arrondis à la centaine d’euros. Mois = salaire hebdomadaire × 52 ÷ 12 ; année = salaire hebdomadaire × 52. Les semaines comptables et les débits de la carrière restent inchangés."
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
	var converted := roundf(float(weekly)*factor()/100.0)*100.0
	var negative := converted < 0
	var digits := "%.0f" % absf(converted)
	var grouped := ""
	for index in digits.length():
		if index > 0 and (digits.length()-index)%3 == 0: grouped += " "
		grouped += digits[index]
	return ("−" if negative else "") + grouped + " €"

static func format(weekly: Variant) -> String:
	return amount(weekly)+" "+period_label(true)

static func bind_input(input: SpinBox, weekly: float, minimum: float, maximum: float, _step: float = 100) -> void:
	var rate := factor()
	input.set_meta("salary_period",period)
	input.set_meta("salary_minimum_weekly",minimum)
	input.set_meta("salary_maximum_weekly",maximum)
	input.step = 100.0
	input.min_value = snappedf(minimum*rate,100.0)
	input.max_value = snappedf(maximum*rate,100.0)
	_apply_input_weekly(input,weekly,false)
	input.suffix = "€ "+period_label(true)
	input.tooltip_text = CONVENTION + " La saisie est arrondie à l’euro hebdomadaire le plus proche avant confirmation."

static func input_weekly(input: SpinBox) -> int:
	var unit := str(input.get_meta("salary_period",period))
	var minimum := roundi(float(input.get_meta("salary_minimum_weekly",input.min_value/factor(unit))))
	var maximum := roundi(float(input.get_meta("salary_maximum_weekly",input.max_value/factor(unit))))
	if input.has_meta("salary_initial_display") and input.value == float(input.get_meta("salary_initial_display")):
		return clampi(roundi(float(input.get_meta("salary_initial_weekly"))),minimum,maximum)
	# Converted endpoint labels are rounded too; they still denote the exact
	# weekly bounds, rather than 992 or 99992 euros in the monthly convention.
	if input.value <= input.min_value: return minimum
	if input.value >= input.max_value: return maximum
	return clampi(roundi(input.value/factor(unit)),minimum,maximum)

static func set_input_weekly(input: SpinBox, weekly: float) -> void:
	_apply_input_weekly(input,weekly,true)

static func _apply_input_weekly(input: SpinBox, weekly: float, notify: bool) -> void:
	var rate := factor(str(input.get_meta("salary_period",period)))
	var source := clampf(weekly,float(input.get_meta("salary_minimum_weekly",input.min_value/rate)),float(input.get_meta("salary_maximum_weekly",input.max_value/rate)))
	input.set_value_no_signal(snappedf(source*rate,100.0))
	# Keep the exact source and actual clamped display together. A copied
	# counteroffer may have the same displayed hundred as the preceding offer.
	input.set_meta("salary_initial_weekly",source)
	input.set_meta("salary_initial_display",input.value)
	if notify: input.value_changed.emit(input.value)
