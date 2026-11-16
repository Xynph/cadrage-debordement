#!/usr/bin/env python3
"""Calques dérivés de l'illustration du stade (art/immersive08/entry-ground.png) pour l'ouverture.

Produit dans native/godot/intro/ :
  - stade-profondeur.png : carte de profondeur (0 = lointain, 255 = premier plan) pour la parallaxe 2,5D ;
  - stade-lueur.png      : lumières de l'image isolées et diffusées (halo des projecteurs et de la tribune) ;
  - stade-flou.png       : image floutée, fond de l'écran titre.
Coordonnées relevées sur l'image source 1672 x 941 (poteaux, mât du projecteur, tribune).
Usage : python3 tools/intro-stade-calques.py  (Pillow et NumPy requis).
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1] / "native" / "godot"
SOURCE = ROOT / "art" / "immersive08" / "entry-ground.png"
OUT = ROOT / "intro"


def depth_map(width: int, height: int) -> Image.Image:
    y = np.linspace(0.0, 1.0, height)[:, None] * np.ones((1, width))
    py = y * height
    # Ciel et montagnes : lointains ; lisière et tribune : plan moyen ; pelouse : du plan moyen au premier plan.
    depth = np.where(py < 360, 0.04 + 0.06 * py / 360, 0.10 + 0.20 * np.clip((py - 360) / 240, 0, 1))
    pitch = np.clip((py - 600) / (height - 600), 0, 1)
    depth = np.where(py >= 600, 0.30 + 0.70 * pitch ** 1.15, depth)
    image = Image.fromarray(np.uint8(np.clip(depth, 0, 1) * 255), "L")
    draw = ImageDraw.Draw(image)
    stand = int(0.34 * 255)
    # Tribune couverte (toit en pente vers la gauche) et club-house.
    draw.polygon([(884, 462), (1672, 338), (1672, 612), (884, 600)], fill=stand)
    draw.rectangle((745, 545, 846, 600), fill=int(0.30 * 255))
    # Mât du projecteur et sa rampe.
    draw.rectangle((870, 330, 890, 600), fill=int(0.32 * 255))
    draw.rectangle((850, 300, 910, 345), fill=int(0.32 * 255))
    posts = int(0.38 * 255)
    # Poteaux : montants, barre transversale, protections.
    draw.rectangle((1224, 18, 1245, 640), fill=posts)
    draw.rectangle((1445, 118, 1466, 640), fill=posts)
    draw.polygon([(1238, 420), (1462, 446), (1462, 466), (1238, 440)], fill=posts)
    draw.rectangle((1216, 515, 1266, 640), fill=posts)
    draw.rectangle((1444, 525, 1489, 635), fill=posts)
    return image.filter(ImageFilter.GaussianBlur(2.5))


def glow_map(source: Image.Image) -> Image.Image:
    rgb = np.asarray(source).astype(np.float32) / 255.0
    luminance = rgb @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    mask = np.clip((luminance - 0.50) / 0.40, 0, 1) ** 1.6
    # Les nuages clairs ne sont pas des lampes : lueur réduite hors du projecteur ; lampes de tribune renforcées.
    yy, xx = np.mgrid[0:source.height, 0:source.width]
    projector = np.exp(-(((xx - 881) / 60.0) ** 2 + ((yy - 322) / 45.0) ** 2))
    sky = yy < 330
    mask = np.where(sky, mask * (0.12 + 0.88 * projector), mask)
    lamps = (yy > 440) & (yy < 560) & (xx > 900)
    warm = np.clip((rgb[..., 0] - rgb[..., 2]) * 4.0, 0, 1)
    mask = np.where(lamps, np.maximum(mask, np.clip((luminance - 0.30) / 0.35, 0, 1) * warm), mask)
    bright = Image.fromarray(np.uint8(np.clip(rgb * mask[..., None], 0, 1) * 255), "RGB")
    small = bright.resize((source.width // 2, source.height // 2), Image.LANCZOS)
    near = np.asarray(small.filter(ImageFilter.GaussianBlur(5))).astype(np.float32)
    far = np.asarray(small.filter(ImageFilter.GaussianBlur(22))).astype(np.float32)
    combined = np.clip(near * 1.6 + far * 2.8, 0, 255)
    return Image.fromarray(np.uint8(combined), "RGB")


def blurred(source: Image.Image) -> Image.Image:
    small = source.resize((source.width // 2, source.height // 2), Image.LANCZOS)
    return small.filter(ImageFilter.GaussianBlur(9))


def main() -> None:
    source = Image.open(SOURCE).convert("RGB")
    depth_map(*source.size).resize((source.width // 2, source.height // 2), Image.LANCZOS).save(OUT / "stade-profondeur.png", optimize=True)
    glow_map(source).save(OUT / "stade-lueur.png", optimize=True)
    blurred(source).save(OUT / "stade-flou.png", optimize=True)
    for name in ("stade-profondeur.png", "stade-lueur.png", "stade-flou.png"):
        print(name, (OUT / name).stat().st_size, "octets")


if __name__ == "__main__":
    main()
