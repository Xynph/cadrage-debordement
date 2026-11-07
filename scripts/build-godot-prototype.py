"""Stage native assets and optionally export a self-contained Windows prototype.

No network access. SDK/runtime paths are explicit, never downloaded by this build.
Generated directories stay outside tracked source; an existing output is refused.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "native/godot"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stage(node):
    assets = PROJECT / "assets"
    assets.mkdir(exist_ok=True)
    atlas = ROOT / "dist/assets/club-atlas"
    manifest = json.loads((atlas / "manifest.json").read_text(encoding="utf-8-sig"))
    assert len(manifest["photos"]) == 60
    for item in manifest["photos"]:
        # Stored filenames are relative; never follow source metadata as a path.
        path = atlas / f'{item["slug"]}-{item["kind"]}.webp'
        assert path.is_file(), path
        assert digest(path) == item["sha256"], path
    shutil.copytree(atlas, assets / "club-atlas", dirs_exist_ok=True)
    editorial = assets / "editorial"
    editorial.mkdir(exist_ok=True)
    for n in ("portraits-0.webp", "portraits-1.webp", "manifest.json"):
        shutil.copy2(ROOT / "dist/assets/editorial" / n, editorial / n)
    model = assets / "match3d"
    model.mkdir(exist_ok=True)
    for n in ("quaternius-rugby-athlete.glb", "QUATERNIUS-CC0-v22.md", "ATTRIBUTION.md", "ASSETS-V23-LICENSES.md"):
        shutil.copy2(ROOT / "dist/match3d/assets" / n, model / n)
    script = "process.stdout.write(JSON.stringify(require('./dist/france-clubs.js').clubs))"
    data = subprocess.check_output([str(node), "-e", script], cwd=ROOT)
    (assets / "clubs.json").write_bytes(data)
    print("Staging vérifié : 60 photos, 30 territoires, portraits et modèle CC0.", flush=True)


def build(args):
    target = args.output.resolve()
    if target.exists():
        raise ValueError("Choisir un nouveau dossier de sortie : aucun écrasement autorisé")
    sdk = args.sdk.resolve()
    editor = sdk / "editor/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe"
    template = sdk / "templates/4.7.2-stable/windows_release_x86_64.exe"
    assert editor.is_file() and template.is_file(), "SDK Windows4.7.2 requis"
    target.mkdir(parents=True)
    work = target / "build"
    source = work / "project"
    shutil.copytree(PROJECT, source, ignore=shutil.ignore_patterns(".godot", "*.uid", "*.import", "export_presets.cfg"))
    preset = (PROJECT / "windows-release.cfg").read_text(encoding="utf-8-sig")
    preset = preset.replace("{{RELEASE_TEMPLATE}}", template.as_posix())
    (source / "export_presets.cfg").write_text(preset, encoding="utf-8")
    app = target / "OvalLegacy-PrototypeGodot"
    app.mkdir()
    env = dict(os.environ, APPDATA=str(work / "profile"), LOCALAPPDATA=str(work / "profile-local"))
    Path(env["APPDATA"]).mkdir(parents=True)
    Path(env["LOCALAPPDATA"]).mkdir(parents=True)
    executable = app / "OvalLegacy.exe"
    for name, tail in [("import", ["--import"]), ("export", ["--export-release", "Windows Desktop", str(executable)])]:
        cmd = [str(editor), "--headless", "--path", str(source)] + tail
        result = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                encoding="utf-8", errors="replace", timeout=180,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        (work / f"{name}.log").write_text(result.stdout, encoding="utf-8")
        if result.returncode or "ERROR:" in result.stdout or "SCRIPT ERROR" in result.stdout:
            raise RuntimeError(f"Godot {name} échoué ; consulter {work / (name + '.log')}")
    (app / "runtime").mkdir()
    shutil.copy2(args.node, app / "runtime/node.exe")
    engine = app / "engine"
    shutil.copytree(ROOT / "native/engine", engine)
    # Only loaded core and anonymised common data; no real names/photos or web UI.
    core = engine / "core"
    core.mkdir()
    script = "process.stdout.write(JSON.stringify(require('./native/engine/worker.cjs').CORE_FILES))"
    sources = json.loads(subprocess.check_output([str(args.node), "-e", script], cwd=ROOT))
    for relative in sources:
        path = (ROOT / "dist" / relative).resolve()
        if not path.is_relative_to((ROOT / "dist").resolve()) or "lnr-" in path.name:
            raise ValueError("Module hors périmètre : " + relative)
        destination = core / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
    licenses = app / "Licences"
    shutil.copytree(sdk / "licenses", licenses)
    shutil.copytree(PROJECT / "fonts", licenses / "fontes", ignore=shutil.ignore_patterns("*.import"))
    shutil.copy2(ROOT / "docs/club-atlas-credits.md", licenses / "photos.md")
    shutil.copy2(ROOT / "dist/assets/club-atlas/manifest.json", licenses / "photos-manifest.json")
    shutil.copytree(ROOT / "dist/match3d/assets", licenses / "modele3d",
                    ignore=shutil.ignore_patterns("*.glb", "*.gltf", "*.bin", "*.png", "*.jpg"))
    (app / "LISEZ-MOI.txt").write_text(
        "OVAL LEGACY — RUGBY MANAGER — PRÉALPHA 0.3\n\n"
        "Lancer OvalLegacy.exe. Aucun navigateur, Godot ou Node à installer.\n"
        "Conserver le dossier complet avec runtime et engine. Windows x64.\n\n"
        "Nouvelle carrière : 30 clubs jouables, deux divisions reliées (14 et16).\n"
        "Base commune de1592joueurs aux identités anonymisées.\n"
        "Rugby Réel : importer le ZIP privé depuis Packs et identités.\n"
        "Disponible à la création et dans les paramètres de carrière.\n"
        "Les packs changent les noms/images, pas les statistiques/progrès.\n"
        "Composition à23, entraînement, tactiques, recrutement et contrats.\n"
        "Match3D, phases finales, montées/descentes et saisons suivantes.\n"
        "Les anciennes carrières fictives14 restent importables et jouables.\n\n"
        "Parcours : Nouvelle carrière → club → Composition → Préparation → Match.\n"
        "Pause pour les changements ; Adjoint pour déléguer la fin du match.\n"
        "Valider la journée après le résultat. Menu & sauvegardes pour exporter.\n"
        "Les promotions du centre peuvent compléter une feuille incomplète ;\n"
        "leur coût salarial est annoncé avant confirmation.\n\n"
        "Capacités et finances de jeu, non officielles. Crédits atlas dans Licences.\n"
        "Photos officielles et illustrations IA des packs signalées séparément.\n"
        "Profil séparé : %APPDATA%/CadrageDebordement/PrototypeGodot.\n"
        "Format2026/27 ; lois de match existantes2025, couverture partielle.\n"
        "34 semaines fictives, monde fermé sans Nationale ; stade3D générique.\n"
        "Préalpha à tester ; publication Steam et finition commerciale à venir.\n", encoding="utf-8")
    files = {p.relative_to(app).as_posix(): {"sha256": digest(p), "bytes": p.stat().st_size}
             for p in sorted(app.rglob("*")) if p.is_file()}
    (app / "manifest-build.json").write_text(json.dumps({"prototype": True, "version": "0.3.0", "mode": "common", "files": files}, indent=2), encoding="utf-8")
    archive = target / "OvalLegacy-PrototypeGodot-Windows-x64.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as out:
        for path in sorted(app.rglob("*")):
            if path.is_file():
                out.write(path, path.relative_to(target))
    print(json.dumps({"exe": str(executable), "zip": str(archive), "sha256": digest(archive)}, ensure_ascii=False), flush=True)


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--node", type=Path, default=Path(os.environ.get("CD_NODE_EXECUTABLE", r"C:\Program Files\nodejs\node.exe")))
    p.add_argument("--stage-only", action="store_true")
    p.add_argument("--sdk", type=Path)
    p.add_argument("--output", type=Path)
    options = p.parse_args()
    if not options.node.is_file():
        p.error("Runtime Node explicite introuvable")
    stage(options.node)
    if not options.stage_only:
        if not options.sdk or not options.output:
            p.error("--sdk et --output sont requis pour exporter")
        build(options)
