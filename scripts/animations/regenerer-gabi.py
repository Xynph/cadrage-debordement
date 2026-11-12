#!/usr/bin/env python3
"""Régénère en une commande la scène du Gabi Mixamo pour le jeu, à partir d'un gabi.blend.

  python3 scripts/animations/regenerer-gabi.py <gabi.blend> <dossier de sortie> --godot <Godot 4.7.2>

1. exporter-gabi-mixamo.py (Blender en module Python) : .glb avec carnet et matériaux d'origine ;
2. avec --tete <dossier> : nettete-tete-gabi.py appliquer (tête en texture 2K dédiée, dossier préparé par
   « nettete-tete-gabi.py preparer ») ;
3. convertir-gabi.gd (Godot sans écran) : scène .scn chargée par le jeu.
Sortie : <dossier>/gabi-mixamo.scn (le .glb intermédiaire est gardé à côté pour contrôle).
Le dossier de sortie doit être hors du dépôt public (animations Mixamo, licence).
"""
import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT = ROOT / "native/godot"


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("blend", type=Path, help="gabi.blend : Gabi rigué + une piste NLA par geste")
    p.add_argument("sortie", type=Path, help="dossier de sortie, hors dépôt public")
    p.add_argument("--godot", type=Path, required=True, help="exécutable Godot 4.7.2")
    p.add_argument("--origine", type=Path, default=PROJECT / "guide/assets/gabi.glb", help="Gabi d'origine (carnet, matériaux)")
    p.add_argument("--tete", type=Path, help="dossier préparé par nettete-tete-gabi.py (tête en texture dédiée)")
    a = p.parse_args()
    sortie = a.sortie.resolve()
    if sortie.is_relative_to(ROOT):
        p.error("le dossier de sortie doit être hors du dépôt public")
    sortie.mkdir(parents=True, exist_ok=True)
    glb, scn = sortie / "gabi-mixamo.glb", sortie / "gabi-mixamo.scn"
    subprocess.run([sys.executable, str(Path(__file__).with_name("exporter-gabi-mixamo.py")), "--",
                    str(a.blend.resolve()), str(a.origine.resolve()), str(glb)], cwd=sortie, check=True)
    if a.tete:
        brut = sortie / "gabi-mixamo-sans-tete.glb"
        glb.replace(brut)
        subprocess.run([sys.executable, str(Path(__file__).with_name("nettete-tete-gabi.py")), "appliquer",
                        str(a.tete.resolve()), str(brut), str(glb)], check=True)
    subprocess.run([str(a.godot), "--headless", "--path", str(PROJECT), "--script",
                    str(Path(__file__).with_name("convertir-gabi.gd")), "--", str(glb), str(scn)], check=True)
    print("Scène prête :", scn)


if __name__ == "__main__":
    main()
