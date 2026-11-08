extends RefCounted
## Couleurs de données : sens fourni par l'appelant, jamais déduit d'une finance
## ou d'une règle de compétition. Les badges opaques restent lisibles sur sélection.
const T = preload("res://theme.gd")
const PALETTE := {
 "positive": {"ink":Color("24583b"),"fill":Color("dfebdf"),"border":Color("7b9b80")},
 "warning": {"ink":Color("77520b"),"fill":Color("f3e5b9"),"border":Color("b39a51")},
 "negative": {"ink":Color("8a342f"),"fill":Color("f2ded8"),"border":Color("b98275")},
 "neutral": {"ink":Color("5d5952"),"fill":Color("e8e1d6"),"border":Color("b6ad9f")}
}
const RESULTS := {
 "V":{"role":"positive","label":"Victoire","plural":"Victoires"},
 "N":{"role":"warning","label":"Nul","plural":"Nuls"},
 "D":{"role":"negative","label":"Défaite","plural":"Défaites"}
}

static func palette(role: String) -> Dictionary:
 return PALETTE.get(role, PALETTE.neutral).duplicate()

static func number_text(value: Variant) -> String:
 if not (value is int or value is float): return "—"
 var number := float(value)
 if not is_finite(number) or number != floor(number): return "—"
 return str(int(number))

static func count_text(value: Variant) -> String:
 var text := number_text(value)
 return text if text != "—" and float(value) >= 0 else "—"

static func difference_text(first: Variant, second: Variant) -> String:
 if count_text(first) == "—" or count_text(second) == "—": return "—"
 return str(int(first) - int(second))

static func badge(text: String, role: String, description: String, width: int = 26) -> PanelContainer:
 var colors := palette(role)
 var panel := PanelContainer.new()
 panel.name = "SemanticBadge"
 panel.custom_minimum_size = Vector2(width, 20)
 panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
 panel.mouse_filter = Control.MOUSE_FILTER_PASS
 panel.tooltip_text = description
 panel.accessibility_name = description
 var style := T.box(colors.fill, 3, colors.border)
 style.content_margin_left = 3; style.content_margin_right = 3
 style.content_margin_top = 1; style.content_margin_bottom = 1
 panel.add_theme_stylebox_override("panel", style)
 var label := Label.new()
 label.name = "Value"
 label.text = text
 label.add_theme_font_size_override("font_size", 12)
 label.add_theme_color_override("font_color", colors.ink)
 label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 label.mouse_filter = Control.MOUSE_FILTER_IGNORE
 panel.add_child(label)
 panel.set_meta("semantic_role", role if PALETTE.has(role) else "neutral")
 panel.set_meta("semantic_text", text)
 return panel

static func count_badge(value: Variant, code: String, width: int = 26) -> PanelContainer:
 var outcome: Dictionary = RESULTS.get(code, {})
 var text := count_text(value)
 var known := text != "—" and not outcome.is_empty()
 var description := str(outcome.get("plural", "Résultat")) + " : " + (text if text != "—" else "donnée non renseignée")
 var result := badge(text, str(outcome.get("role", "neutral")) if known else "neutral", description, width)
 result.set_meta("outcome_code", code)
 return result

static func outcome_badge(value: Variant, width: int = 20) -> PanelContainer:
 var code := value as String if value is String else ""
 var outcome: Dictionary = RESULTS.get(code, {})
 return badge(code if not outcome.is_empty() else "—", str(outcome.get("role", "neutral")), str(outcome.get("label", "Résultat non renseigné")), width)

static func recent_form(values: Variant, limit: int = 6) -> HBoxContainer:
 var row := HBoxContainer.new()
 row.name = "RecentForm"
 row.add_theme_constant_override("separation", 3)
 row.tooltip_text = "Résultats de championnat conservés · du plus ancien au plus récent"
 var recent: Array = values.slice(maxi(0, values.size() - maxi(0, limit))) if values is Array else []
 if recent.is_empty():
  row.add_child(badge("—", "neutral", "Aucun résultat de championnat conservé", 20))
 else:
  for value in recent: row.add_child(outcome_badge(value))
 return row

static func legend(compact: bool = true) -> HBoxContainer:
 var row := HBoxContainer.new()
 row.name = "ResultLegend"
 row.add_theme_constant_override("separation", 8)
 for code in ["V", "N", "D"]:
  var item := HBoxContainer.new()
  item.add_theme_constant_override("separation", 3)
  item.add_child(outcome_badge(code, 18))
  var label := Label.new()
  label.text = str(RESULTS[code].label if compact else RESULTS[code].plural)
  label.add_theme_font_size_override("font_size", 12)
  label.add_theme_color_override("font_color", Color("20282c"))
  item.add_child(label)
  row.add_child(item)
 return row
