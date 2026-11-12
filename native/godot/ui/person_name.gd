extends RefCounted
## Parties d'un nom affiché. Un patronyme peut compter plusieurs mots
## (« LE GAC », « VAN DIJK ») : il n'est jamais réduit à son dernier mot.

static func _capitals(word: String) -> bool:
	return word == word.to_upper() and word != word.to_lower()

## Patronyme : la suite finale de mots en capitales quand un prénom la précède,
## sinon tout ce qui suit le premier mot.
static func surname(full_name: String) -> String:
	var words := full_name.split(" ", false)
	if words.size() < 2:
		return full_name
	var start := words.size()
	while start > 1 and _capitals(words[start - 1]):
		start -= 1
	if start == words.size():
		start = 1
	return " ".join(words.slice(start))

## Initiale du prénom suivie du patronyme.
static func initial_and_surname(full_name: String) -> String:
	var words := full_name.split(" ", false)
	if words.size() < 2:
		return full_name
	return words[0].left(1) + ". " + surname(full_name)
