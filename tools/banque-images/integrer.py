#!/usr/bin/env python3
"""Intègre au jeu une sélection de la banque d'images (dépôt privé Xynph/rugby-legacy-banque-images).

Usage : python3 tools/banque-images/integrer.py CHEMIN_BANQUE [--lot NOM]

- lit `banque-images.json` de la banque (registre complet : prompts, étiquettes, empreintes) ;
- ne garde que les identifiants listés dans `selection.json` (ce qui sert vraiment aux écrans) ;
- compresse chaque PNG en WebP qualité 88 dans native/godot/art/banque/<catégorie>/<id>.webp
  (les masques et cartes d'ombres recolorables restent sans perte : WebP lossless) ;
- écrit native/godot/art/banque/banque-images.json : le manifeste lu par ui/banque_images.gd
  (fichier, taille, empreinte du WebP, étiquettes, image de repli), sans les prompts.

Relançable : une image déjà à jour (même empreinte source) n'est pas recompressée.
"""
import argparse, hashlib, json, os, sys
from PIL import Image

RACINE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SORTIE = os.path.join(RACINE, "native", "godot", "art", "banque")
SELECTION = os.path.join(os.path.dirname(os.path.abspath(__file__)), "selection.json")
QUALITE = 88

def sha(chemin: str) -> str:
    h = hashlib.sha256()
    with open(chemin, "rb") as f:
        for bloc in iter(lambda: f.read(1 << 20), b""): h.update(bloc)
    return h.hexdigest()

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("banque")
    p.add_argument("--lot", default=None, help="branche ou lot d'origine, noté dans le manifeste")
    a = p.parse_args()
    registre = json.load(open(os.path.join(a.banque, "banque-images.json"), encoding="utf-8"))
    selection = json.load(open(SELECTION, encoding="utf-8"))
    par_id = {i["id"]: i for i in registre["images"]}
    ancien = {}
    chemin_manifeste = os.path.join(SORTIE, "banque-images.json")
    if os.path.exists(chemin_manifeste):
        ancien = {i["id"]: i for i in json.load(open(chemin_manifeste, encoding="utf-8"))["images"]}
    images, manquants = [], []
    for groupe in selection["groupes"]:
        for ident in groupe["ids"]:
            src = par_id.get(ident)
            if src is None or src.get("etat") != "fait": manquants.append(ident); continue
            chemin_src = os.path.join(a.banque, src["fichier"])
            sans_perte = groupe.get("sans_perte", False)
            dest_rel = "%s/%s.webp" % (src["categorie"], ident)
            dest = os.path.join(SORTIE, dest_rel)
            sha_src = sha(chemin_src)
            deja = ancien.get(ident)
            if not (deja and deja.get("source_sha256") == sha_src and os.path.exists(dest)):
                os.makedirs(os.path.dirname(dest), exist_ok=True)
                im = Image.open(chemin_src)
                if sans_perte and im.mode not in ("RGB", "RGBA", "L"): im = im.convert("RGBA")
                elif not sans_perte: im = im.convert("RGBA" if im.mode in ("RGBA", "LA", "PA") or "transparency" in im.info else "RGB")
                if sans_perte: im.save(dest, "WEBP", lossless=True, method=6)
                else: im.save(dest, "WEBP", quality=QUALITE, method=6)
            gris = None
            if src.get("type_rendu") == "carte-ombres":  # luminance moyenne du tissu : neutre pour le shader
                im2 = Image.open(chemin_src).convert("RGBA").resize((128, 128))
                px = [(0.299 * r + 0.587 * g + 0.114 * b) / 255 for r, g, b, a in im2.getdata() if a > 200]
                gris = round(sum(px) / len(px), 3) if px else None
            part = None
            if src.get("type_rendu") == "masque-binaire":  # part du masque en blanc (zones du club)
                mk = Image.open(chemin_src).convert("L").resize((128, 128))
                cle = Image.open(os.path.join(a.banque, par_id[src["masque_de"]]["fichier"])).convert("RGBA").resize((128, 128)) if src.get("masque_de") in par_id else None
                vis = [m for m, px in zip(mk.getdata(), cle.getdata() if cle else [(0, 0, 0, 255)] * 16384) if px[3] > 200]
                part = round(sum(1 for m in vis if m > 127) / len(vis), 3) if vis else None
            et = dict(src.get("etiquettes") or {})
            et.update(groupe.get("etiquettes", {}).get(ident, {}))
            if et.get("resultat") == "défaite": et["resultat"] = "defaite"  # clés sans accent côté code
            images.append({
                "id": ident, "categorie": src["categorie"], "fichier": dest_rel,
                "largeur": src["largeur"], "hauteur": src["hauteur"], "octets": os.path.getsize(dest),
                "sha256": sha(dest), "source_sha256": sha_src, "source_octets": src.get("octets"),
                "repli": groupe.get("repli", src.get("repli_neutre") or ident),
                "etiquettes": {k: v for k, v in et.items() if v not in (None, [], "")},
                **({"gris_moyen": gris} if gris else {}),
                **({"part_blanche": part} if part is not None else {}),
                "synthetique": bool(src.get("synthetique", True)), "outil": src.get("outil"),
            })
    if manquants:
        print("Identifiants absents ou non terminés dans la banque : " + ", ".join(manquants), file=sys.stderr)
        return 1
    gardes = {i["fichier"] for i in images}
    for dossier, _, fichiers in os.walk(SORTIE):
        for f in fichiers:
            rel = os.path.relpath(os.path.join(dossier, f), SORTIE).replace(os.sep, "/")
            if f.endswith(".webp") and rel not in gardes: os.remove(os.path.join(dossier, f))
    manifeste = {
        "schema": "rugby-legacy-banque-images-jeu-v1",
        "source": "Xynph/rugby-legacy-banque-images" + ("@" + a.lot if a.lot else ""),
        "usage": "Illustrations fictives générées par IA (aucun vrai nom, logo ni visage réel). Choix par ui/banque_images.gd.",
        "qualite_webp": QUALITE,
        "images": images,
    }
    with open(chemin_manifeste, "w", encoding="utf-8") as f:
        json.dump(manifeste, f, ensure_ascii=False, indent=1)
        f.write("\n")
    total_src = sum(i["source_octets"] or 0 for i in images); total = sum(i["octets"] for i in images)
    print("%d images, %.1f Mo -> %.1f Mo" % (len(images), total_src / 1e6, total / 1e6))
    return 0

if __name__ == "__main__":
    sys.exit(main())
