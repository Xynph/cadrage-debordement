#!/usr/bin/env python3
"""Pose les animations privées (dépôt rugby-reel-donnees, dossier animations/) à côté du jeu installé.

  python3 scripts/animations/poser-animations-privees.py <clone de rugby-reel-donnees> <dossier du jeu>

Copie animations/gabi-mixamo.scn et animations/mixamo-match.res dans <dossier du jeu>/animations/,
là où le jeu les cherche quand CD_GABI_MIXAMO et CD_MATCH_ANIMATIONS sont absentes
(native/godot/donnees_privees.gd). Vérifie l'empreinte SHA-256 de chaque copie.

À lancer après l'installation ou la mise à jour du jeu, sur le PC : jamais dans la chaîne de
livraison publique (le ZIP publié dans les Releases d'un dépôt public redistribuerait des fichiers
Mixamo, ce que la licence interdit).
"""
import argparse
import hashlib
import shutil
from pathlib import Path

FICHIERS = ("gabi-mixamo.scn", "mixamo-match.res")


def empreinte(chemin):
    h = hashlib.sha256()
    with open(chemin, "rb") as f:
        for bloc in iter(lambda: f.read(1 << 20), b""):
            h.update(bloc)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("donnees", type=Path, help="clone du dépôt privé rugby-reel-donnees")
    p.add_argument("jeu", type=Path, help="dossier qui contient l'exécutable du jeu")
    a = p.parse_args()
    source = a.donnees / "animations"
    if not any(a.jeu.glob("*.exe")) and not any(a.jeu.glob("*.x86_64")):
        p.error(f"aucun exécutable du jeu dans {a.jeu}")
    cible = a.jeu / "animations"
    cible.mkdir(exist_ok=True)
    for nom in FICHIERS:
        origine = source / nom
        if not origine.is_file():
            print("absent, ignoré :", origine)
            continue
        copie = cible / nom
        temporaire = copie.with_suffix(copie.suffix + ".part")
        shutil.copyfile(origine, temporaire)
        if empreinte(temporaire) != empreinte(origine):
            temporaire.unlink()
            raise SystemExit(f"copie altérée : {nom}")
        temporaire.replace(copie)
        print("posé :", copie)


if __name__ == "__main__":
    main()
