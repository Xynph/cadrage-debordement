"""Planche côte à côte A | B (1920 x 1080) d'une idée : écran entier en haut, zoom sur la bulle (capture 2560) en bas.

  python tools/planches-survols/planche.py E:\\Cadrage-Debordement\\temp\\options-visuel\\survol-ecusson
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

FOND = (32, 45, 45)
CREME = (242, 236, 220)
GRIS = (171, 183, 177)


def police(taille):
    for nom in ("C:/Windows/Fonts/arialbd.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(nom, taille)
        except OSError:
            pass
    return ImageFont.load_default()


def ajuster(image, largeur, hauteur):
    echelle = min(largeur / image.width, hauteur / image.height)
    return image.resize((max(1, round(image.width * echelle)), max(1, round(image.height * echelle))), Image.LANCZOS)


def main(dossier):
    dossier = Path(dossier)
    planche = Image.new("RGB", (1920, 1080), FOND)
    dessin = ImageDraw.Draw(planche)
    for i, lettre in enumerate("AB"):
        x0 = 20 + i * 950
        dessin.text((x0, 10), lettre, fill=CREME, font=police(40))
        ecran = Image.open(dossier / f"{lettre}-1920.png").convert("RGB")
        haut = ajuster(ecran, 930, 523)
        planche.paste(haut, (x0, 60))
        grande = Image.open(dossier / f"{lettre}-2560.png").convert("RGB")
        zone_json = dossier / f"{lettre}-2560.json"
        if zone_json.exists():
            x, y, w, h = json.loads(zone_json.read_text(encoding="utf-8"))["zone"]
            zoom = grande.crop((round(x), round(y), round(x + w), round(y + h)))
        else:
            zoom = grande
        bas = ajuster(zoom, 930, 470)
        planche.paste(bas, (x0 + (930 - bas.width) // 2, 595 + (470 - bas.height) // 2))
    sortie = dossier / "planche.png"
    planche.save(sortie)
    print(sortie)


if __name__ == "__main__":
    main(sys.argv[1])
