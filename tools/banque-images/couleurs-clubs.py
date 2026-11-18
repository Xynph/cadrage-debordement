#!/usr/bin/env python3
"""Deuxième couleur de chaque club (présentation : maillots, écussons, vestiaire 3D).

Écrit native/godot/ui/couleurs_clubs.json : {slug: "#rrggbb"}. Clubs du championnat de France de base :
couleur choisie à la main (association traditionnelle de la ville) ; autres clubs (identités fictives) :
couleur tirée d'une palette de club, la première qui tranche assez avec la couleur principale (ordre stable
par club). Relancer après l'ajout de clubs : python3 tools/banque-images/couleurs-clubs.py
"""
import colorsys, hashlib, json, os

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MOTEUR = os.path.join(RACINE, "native", "engine")
SORTIE = os.path.join(RACINE, "native", "godot", "ui", "couleurs_clubs.json")
NOIR, BLANC, OR, MARINE, BORDEAUX, SAPIN, CIEL, SANG = "#1b1d20", "#efe9dc", "#d4b340", "#1f2f4f", "#6b1f2b", "#1f4d3a", "#79b7d7", "#a3242c"
PALETTE = [NOIR, BLANC, OR, MARINE, BORDEAUX, SAPIN, CIEL]
MAIN = {"toulouse": NOIR, "bordeaux-begles": NOIR, "la-rochelle": NOIR, "toulon": NOIR, "pau": BLANC, "bayonne": BLANC,
	"clermont": MARINE, "lyon": NOIR, "montpellier": BLANC, "castres": BLANC, "racing-92": BLANC, "paris": MARINE,
	"perpignan": SANG, "vannes": BLANC, "beziers": MARINE, "biarritz": BLANC, "brive": NOIR, "colomiers": BLANC,
	"grenoble": MARINE, "nice": NOIR, "oyonnax": NOIR, "provence-rugby": MARINE, "narbonne": NOIR, "agen": BLANC,
	"angouleme": NOIR, "aurillac": MARINE, "dax": BLANC, "montauban": BLANC, "nevers": MARINE, "valence-romans": SAPIN}

def rgb(h): h = h.lstrip("#"); return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
def lum(c): return sum(w * v for w, v in zip((0.299, 0.587, 0.114), rgb(c)))
def ecart(a, b):
	ha, la, sa = colorsys.rgb_to_hls(*rgb(a)); hb, lb, sb = colorsys.rgb_to_hls(*rgb(b))
	dh = min(abs(ha - hb), 1 - abs(ha - hb)) * (min(sa, sb) > 0.2)
	return abs(lum(a) - lum(b)) + dh

def choisir(slug, couleur):
	ordre = sorted(PALETTE, key=lambda c: hashlib.sha256((slug + c).encode()).hexdigest())
	for c in ordre:
		if ecart(couleur, c) >= 0.35: return c
	return BLANC if lum(couleur) < 0.5 else NOIR

def main():
	clubs = list(json.load(open(os.path.join(MOTEUR, "world-registry.json"), encoding="utf-8"))["clubs"])
	for f in ("world-pacific-extension", "world-japan-extension", "world-nationale-extension", "world-champ-extension"):
		clubs += json.load(open(os.path.join(MOTEUR, f + ".json"), encoding="utf-8")).get("clubs", [])
	sortie = {}
	for c in clubs:
		slug, couleur = str(c.get("slug", "")), str(c.get("color", "#596368"))
		if slug: sortie[slug] = MAIN.get(slug) or choisir(slug, couleur)
	with open(SORTIE, "w", encoding="utf-8") as f:
		json.dump({"note": "Deuxième couleur des clubs (présentation). Généré par tools/banque-images/couleurs-clubs.py.", "couleurs": dict(sorted(sortie.items()))}, f, ensure_ascii=False, indent=1)
		f.write("\n")
	print(len(sortie), "clubs")

if __name__ == "__main__":
	main()
