extends SceneTree
## Maillots et carnations (film du 18 novembre 2026, vue TV 1280×720) : la tenue brun orangé
## de Meadowbridge (#a46e44) avait presque la couleur de la peau et les joueurs paraissaient
## torse nu. Le choix des tenues garde désormais un écart minimal avec les carnations des
## joueurs, sans perdre la teinte du club, et les bords de manches ne sont jamais couleur chair.
## Sans rendu : seules les couleurs choisies sont contrôlées.

const Kit = preload("res://match_kit.gd")
const Athlete = preload("res://match_athlete.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)


func hue_gap(a: Color, b: Color) -> float:
	var gap := absf(a.h - b.h)
	return minf(gap, 1.0 - gap)


func kits(home: String, away: String) -> Array[Dictionary]:
	var colors: Array[Color] = [Color(home), Color(away)]
	return Kit.resolve(colors)


func run() -> void:
	# Le défaut d'origine : la couleur source est bien vue comme une carnation.
	var meadowbridge := Color("a46e44")
	check(Kit.skin_like(meadowbridge), "Meadowbridge (#a46e44) est reconnu proche d'une carnation")
	check(Kit.skin_gap(meadowbridge) < Kit.SKIN_NEAR, "Écart d'origine de Meadowbridge sous le seuil : %.3f" % Kit.skin_gap(meadowbridge))
	# Carnations du jeu : la même liste que les modèles des joueurs.
	for tone in Athlete.SKINS:
		check(Kit.skin_like(Color(str(tone))), "Carnation %s reconnue comme peau" % tone)

	# Meadowbridge à domicile : maillot rendu distinct de la peau, teinte du club gardée.
	var home_kit := kits("#a46e44", "#4e68a0")
	var shirt: Color = home_kit[0].shirt
	check(shirt != meadowbridge, "Le maillot de Meadowbridge est corrigé")
	check(Kit.skin_gap(shirt) >= Kit.SKIN_SAFE_GAP, "Maillot de Meadowbridge loin de toute carnation : %.3f (%s)" % [Kit.skin_gap(shirt), shirt.to_html(false)])
	check(not Kit.skin_like(shirt), "Maillot de Meadowbridge hors des carnations")
	check(hue_gap(shirt, meadowbridge) < 0.02, "Teinte du club conservée : %.3f → %.3f" % [meadowbridge.h, shirt.h])
	check(not Kit.skin_like(home_kit[0].detail), "Bords de manches de Meadowbridge jamais couleur chair (%s)" % (home_kit[0].detail as Color).to_html(false))
	check(home_kit[1].shirt == Color("4e68a0"), "L'adversaire bleu garde son maillot")
	# Meadowbridge à l'extérieur : même correction, l'adversaire garde le sien.
	var away_kit := kits("#4e68a0", "#a46e44")
	check(away_kit[0].shirt == Color("4e68a0"), "Le domicile bleu garde son maillot")
	check(Kit.skin_gap(away_kit[1].shirt) >= Kit.SKIN_SAFE_GAP and hue_gap(away_kit[1].shirt, meadowbridge) < 0.02, "Meadowbridge à l'extérieur : maillot corrigé, même teinte (%s)" % (away_kit[1].shirt as Color).to_html(false))
	check(not Kit.skin_like(away_kit[1].detail), "Meadowbridge à l'extérieur : bords de manches hors des carnations")
	# Deux clubs couleur chair face à face : maillots distincts entre eux et de la peau.
	var both := kits("#a46e44", "#a97543")
	for side in 2:
		check(not Kit.skin_like(both[side].shirt), "Duel de tons chair : maillot %d hors des carnations (%s)" % [side, (both[side].shirt as Color).to_html(false)])
	var a: Color = both[0].shirt
	var b: Color = both[1].shirt
	check(Vector3(a.r, a.g, a.b).distance_to(Vector3(b.r, b.g, b.b)) >= 0.38, "Duel de tons chair : les deux équipes restent distinctes")
	# Orange vif de club (constat « maillot orange ») : corrigé lui aussi.
	var orange := kits("#d88042", "#4e76a2")
	check(Kit.skin_like(Color("d88042")) and not Kit.skin_like(orange[0].shirt), "Orange #d88042 : corrigé hors des carnations (%s)" % (orange[0].shirt as Color).to_html(false))

	# Les tenues qui ne ressemblent pas à la peau ne bougent pas (rouge, vert, bleu, or, ivoire, anthracite).
	for source in ["a12f41", "a73043", "359a66", "6f9ac9", "d4b340", "d43e47", "f0ecdf", "202b35", "4e68a0"]:
		var color := Color(source)
		check(not Kit.skin_like(color) and Kit.skin_safe(color) == color, "Couleur de club inchangée : #" + source)
	# Rouge domicile : le liseré éclairci d'origine reste le sien ; face à Meadowbridge (proche une
	# fois corrigé), l'extérieur passe en tenue alternative, liseré à la couleur corrigée du club.
	var red := kits("#a12f41", "#4e68a0")
	check(red[0].detail == Color("a12f41").lightened(0.4), "Rouge domicile : liseré d'origine conservé")
	var red_mbr := kits("#a12f41", "#a46e44")
	check(red_mbr[1].shirt in [Kit.IVORY, Kit.ANTHRACITE] and red_mbr[1].detail == Kit.skin_safe(meadowbridge), "Rouge contre Meadowbridge : tenue alternative, liseré du club hors carnation")

	# Balayage des couleurs possibles : aucune tenue choisie ne se confond avec la peau.
	var corrected := 0
	var worst := INF
	for h in 50:
		for s in range(2, 11):
			for v in range(2, 11):
				var source := Color.from_hsv(h / 50.0, s / 10.0, v / 10.0)
				var safe := Kit.skin_safe(source)
				if safe != source:
					corrected += 1
					worst = minf(worst, Kit.skin_gap(safe))
					check(hue_gap(safe, source) < 0.02 or safe == Kit.ANTHRACITE or safe.s < 0.15, "Teinte gardée pour #%s → #%s" % [source.to_html(false), safe.to_html(false)])
				check(not Kit.skin_like(safe), "Jamais couleur chair : #%s → #%s" % [source.to_html(false), safe.to_html(false)])
	check(corrected > 0 and worst >= Kit.SKIN_SAFE_GAP - 0.0001, "Écart minimal après correction : %.3f sur %d couleurs corrigées" % [worst, corrected])
	print("MATCH_MAILLOT_PEAU ", JSON.stringify({"checks": checks, "corriges": corrected, "ecart_min": worst, "meadowbridge": shirt.to_html(false)}))
	print("MATCH_MAILLOT_PEAU_CHECKS %d failures=%d" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
