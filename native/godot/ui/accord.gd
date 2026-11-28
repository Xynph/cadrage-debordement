extends RefCounted
## Accord en nombre des libellés (28/11/2026) : jamais « 1 saison(s) » ni « 0 semaine(s) » à l'écran.
## « (s) » et « (nt) » prennent l'accord du dernier nombre qui les précède dans le même segment (jusqu'au
## « · », au saut de ligne ou au début) : pluriel à partir de 2 (règle française : 0, 1 et 1,5 au singulier).
## Sans nombre dans le segment, on garde le pluriel (titre de colonne, « Montées vers … »).
## Appelé par les deux fabriques de libellés (ui/game_skin.gd, ui/immersive08/components.gd).

static var _nombre: RegEx
static var _marque: RegEx

static func texte(valeur: String) -> String:
	if not valeur.contains("(s)") and not valeur.contains("(nt)"): return valeur
	if _nombre == null:
		_nombre = RegEx.create_from_string("\\d+(?:[.,]\\d+)?")
		_marque = RegEx.create_from_string("\\((s|nt)\\)")
	var sortie := ""
	var depuis := 0
	for m in _marque.search_all(valeur):
		var debut := m.get_start()
		var avant := valeur.substr(0, debut)
		var segment_debut := maxi(maxi(avant.rfind("·"), avant.rfind("\n")), avant.rfind(" — ")) + 1
		var segment := avant.substr(segment_debut)
		var nombres := _nombre.search_all(segment)
		var pluriel := true
		if not nombres.is_empty():
			pluriel = absf(float(nombres[-1].get_string().replace(",", "."))) >= 2.0
		sortie += valeur.substr(depuis, debut - depuis) + (m.get_string(1) if pluriel else "")
		depuis = m.get_end()
	return sortie + valeur.substr(depuis)
