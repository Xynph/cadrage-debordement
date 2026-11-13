extends SceneTree
const Staff = preload("res://ui/staff_view.gd")
const Career = preload("res://ui/staff_career_view.gd")
class Host extends Control:
	var model := {"clubLife":{}, "club":{"id":0}}
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); printerr(message)
func words(node: Node) -> String:
	var result := str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): result += words(child)
	return result
func run() -> void:
	var generated := {"id":"completion:test:doctor", "name":"Nolan Leroux", "role":"medical", "roleLabel":"Médecin", "sourceKind":"generated", "identityStatus":"fictional", "portraitStatus":"synthetic", "appearanceBankVersion":2, "age":42, "ageBasis":"estimated", "clubId":0, "contractEnd":2}
	var reference := {"id":"staff:reference:test", "name":"Référence test", "role":"Médecin", "sourceSeason":"2026/27", "observedAt":"2026-11-08", "portraitStatus":"anonymous"}
	var host := Host.new(); root.add_child(host)
	var initial := VBoxContainer.new(); host.add_child(initial)
	var before := generated.duplicate(true)
	Staff._person(host, initial, generated)
	check(words(initial).contains(generated.name) and words(initial).contains(generated.role), "Staff directory shows the character normally")
	check(not words(initial).contains("RÉFÉRENCE") and not words(initial).contains("Relevé le"), "No false source citation for generated identity")
	var career := VBoxContainer.new(); host.add_child(career)
	Career._person(host, career, generated, {"available":false,"roles":{}}, true)
	check(words(career).contains(generated.name) and not words(career).to_lower().contains("fictif"), "Staff career has no character-origin warning")
	var original := VBoxContainer.new(); host.add_child(original)
	Staff._person(host, original, reference)
	check(words(original).contains(reference.name) and not words(original).to_lower().contains("fictif"), "Existing staff also appears normally")
	check(generated == before, "Rendering does not mutate the staff identity")
	check(not words(initial).to_lower().contains("fictif") and not words(initial).contains("généré"), "Staff directory has no origin warning")
	host.queue_free(); await process_frame
	print("STAFF_FICTIONAL_LABELS ", JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
