#!/usr/bin/env python3
"""Deuxième couleur de chaque club (présentation : maillots, écussons, vestiaire 3D).

Écrit native/godot/ui/couleurs_clubs.json : {slug: "#rrggbb"}. Même méthode pour tous les clubs : couleur
choisie à la main d'après les couleurs traditionnelles du club ou de sa ville. Un club ajouté sans couleur
fait échouer le script : la choisir ici. Relancer : python3 tools/banque-images/couleurs-clubs.py
"""
import json, os

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MOTEUR = os.path.join(RACINE, "native", "engine")
SORTIE = os.path.join(RACINE, "native", "godot", "ui", "couleurs_clubs.json")
NOIR, BLANC, OR, MARINE, BORDEAUX, SAPIN, CIEL, SANG, ORANGE = "#1b1d20", "#efe9dc", "#d4b340", "#1f2f4f", "#6b1f2b", "#1f4d3a", "#79b7d7", "#a3242c", "#d9822b"
MAIN = {"toulouse": NOIR, "bordeaux-begles": NOIR, "la-rochelle": NOIR, "toulon": NOIR, "pau": BLANC, "bayonne": BLANC,
	"clermont": MARINE, "lyon": NOIR, "montpellier": BLANC, "castres": BLANC, "racing-92": BLANC, "paris": MARINE,
	"perpignan": SANG, "vannes": BLANC, "beziers": MARINE, "biarritz": BLANC, "brive": NOIR, "colomiers": BLANC,
	"grenoble": MARINE, "nice": NOIR, "oyonnax": NOIR, "provence-rugby": MARINE, "narbonne": NOIR, "agen": BLANC,
	"angouleme": NOIR, "aurillac": MARINE, "dax": BLANC, "montauban": BLANC, "nevers": MARINE, "valence-romans": SAPIN,
	# Angleterre, Irlande, Écosse, pays de Galles, Italie, Afrique du Sud, Géorgie
	"prem-bath": NOIR, "prem-bristol": BLANC, "prem-exeter": NOIR, "prem-gloucester": BORDEAUX, "prem-harlequins": CIEL,
	"prem-leicester": BLANC, "prem-newcastle": NOIR, "prem-northampton": OR, "prem-sale": BLANC, "prem-saracens": NOIR,
	"urc-leinster": BLANC, "urc-munster": SANG, "urc-ulster": BLANC, "urc-connacht": BLANC, "urc-glasgow": MARINE,
	"urc-edinburgh": NOIR, "urc-cardiff": NOIR, "urc-dragons": NOIR, "urc-ospreys": NOIR, "urc-scarlets": SANG,
	"urc-benetton": BLANC, "urc-zebre": NOIR, "urc-stormers": BLANC, "urc-bulls": BLANC, "urc-sharks": NOIR,
	"urc-lions": BLANC, "guest-cheetahs": ORANGE, "guest-black-lion": NOIR,
	# Super Rugby Pacific
	"srp-blues": BLANC, "srp-brumbies": OR, "srp-chiefs": NOIR, "srp-crusaders": NOIR, "srp-drua": BLANC,
	"srp-highlanders": OR, "srp-hurricanes": NOIR, "srp-reds": BLANC, "srp-waratahs": BLANC, "srp-force": OR,
	# Japon (League One)
	"jlo-club-68": NOIR, "jlo-club-69": BLANC, "jlo-club-70": NOIR, "jlo-club-71": NOIR, "jlo-club-72": ORANGE,
	"jlo-club-73": BLANC, "jlo-club-74": BLANC, "jlo-club-75": NOIR, "jlo-club-76": BLANC, "jlo-club-77": BLANC,
	"jlo-club-78": BLANC, "jlo-club-79": BLANC, "jlo-club-80": ORANGE, "jlo-club-81": SANG, "jlo-club-82": BLANC,
	"jlo-club-83": SANG, "jlo-club-84": NOIR, "jlo-club-85": BLANC, "jlo-club-86": BLANC, "jlo-club-87": BLANC,
	# Nationale
	"nat-club-88": BLANC, "nat-club-89": BORDEAUX, "nat-club-90": BLANC, "nat-club-91": NOIR, "nat-club-92": BLANC,
	"nat-club-93": NOIR, "nat-club-94": BLANC, "nat-club-95": BLANC, "nat-club-96": SANG, "nat-club-97": NOIR,
	"nat-club-98": NOIR, "nat-club-99": MARINE, "nat-club-100": BLANC, "nat-club-101": NOIR,
	# Championship anglais
	"champ-club-102": OR, "champ-club-103": BLANC, "champ-club-104": NOIR, "champ-club-105": NOIR, "champ-club-106": OR,
	"champ-club-107": MARINE, "champ-club-108": OR, "champ-club-109": BLANC, "champ-club-110": BLANC, "champ-club-111": BLANC,
	"champ-club-112": NOIR, "champ-club-113": NOIR, "champ-club-114": NOIR, "champ-club-115": OR}


def main():
	clubs = list(json.load(open(os.path.join(MOTEUR, "world-registry.json"), encoding="utf-8"))["clubs"])
	for f in ("world-pacific-extension", "world-japan-extension", "world-nationale-extension", "world-champ-extension"):
		clubs += json.load(open(os.path.join(MOTEUR, f + ".json"), encoding="utf-8")).get("clubs", [])
	sortie = {}
	for c in clubs:
		slug = str(c.get("slug", ""))
		if not slug: continue
		if slug not in MAIN: raise SystemExit("Club sans deuxième couleur : %s (%s) — l'ajouter dans MAIN" % (slug, c.get("name")))
		sortie[slug] = MAIN[slug]
	with open(SORTIE, "w", encoding="utf-8") as f:
		json.dump({"note": "Deuxième couleur des clubs (présentation). Généré par tools/banque-images/couleurs-clubs.py.", "couleurs": dict(sorted(sortie.items()))}, f, ensure_ascii=False, indent=1)
		f.write("\n")
	print(len(sortie), "clubs")

if __name__ == "__main__":
	main()
