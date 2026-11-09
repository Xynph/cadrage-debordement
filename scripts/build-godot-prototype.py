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
import wave
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "native/godot"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_voice_assets(project):
    voice = project / "guide/assets/voice"
    recordings = json.loads((voice / "manifest.json").read_text(encoding="utf-8-sig"))
    dialogues = json.loads((project / "guide/dialogues.json").read_text(encoding="utf-8-sig"))
    fragments = [fragment for page in dialogues["pages"] for fragment in page["fragments"]]
    expected = {fragment["id"]: fragment["text"] for fragment in fragments}
    assert len(expected) == len(fragments), "IDs de dialogue uniques requis"
    assert all(isinstance(text, str) and 0 < len(text) <= 181 for text in expected.values()), "Bulles courtes requises"
    assert all(fragment.get("audioStatus") in (None, "pending") for fragment in fragments), "État audio inconnu"
    pending = {fragment["id"] for fragment in fragments if fragment.get("audioStatus") == "pending"}
    clips = recordings["clips"]
    recorded = {clip["id"] for clip in clips}
    assert clips and len(recorded) == len(clips), "IDs vocaux uniques et enregistrements requis"
    assert recorded == expected.keys() - pending, "Chaque texte sans audio doit être explicitement en attente ; aucun clip obsolète admis"
    for clip in clips:
        assert clip["text"] == expected[clip["id"]]
        assert hashlib.sha256(clip["text"].encode("utf-8")).hexdigest() == clip["text_sha256"]
        filename = clip["file"]
        assert Path(filename).name == filename and filename.endswith(".wav"), "WAV relatif requis"
        path = voice / filename
        assert digest(path) == clip["sha256"], "Empreinte vocale différente : " + filename
        with wave.open(str(path), "rb") as wav:
            assert wav.getsampwidth() == 2 and wav.getnchannels() == 1 and wav.getnframes() > wav.getframerate() / 2
    assert (voice / "CREDITS.txt").is_file() and list(voice.glob("LICENSE*.txt")), "Provenance et licences vocales requises"
    return {"status": "provisional" if pending else "complete", "total": len(expected), "recorded": len(recorded), "pending": len(pending), "pendingIds": sorted(pending)}


def voice_notice(coverage):
    plural = "s" if coverage["recorded"] != 1 else ""
    notice = f"Voix de Gabi : {coverage['recorded']} réplique{plural} enregistrée{plural} et lue{plural} localement.\n"
    if coverage["pending"]:
        plural = "s" if coverage["pending"] != 1 else ""
        notice += f"{coverage['pending']} réplique{plural} en attente d'enregistrement.\n"
    return (notice + "En cas d'enregistrement absent ou illisible, une voix système peut le remplacer\n"
            "si elle est disponible. Le texte reste toujours affiché.\n"
            "Crédits et licences des voix : Licences/voix-coach.\n")


def stage(node):
    for compiler in ("build-staff-registry.cjs", "build-rugby-common.cjs", "build-world-registry.cjs"):
        subprocess.run([str(node), str(ROOT / "scripts" / compiler), "--check"], cwd=ROOT, check=True)
    voice_coverage = validate_voice_assets(PROJECT)
    assets = PROJECT / "assets"
    assets.mkdir(exist_ok=True)
    (assets / "voice-coverage.json").write_text(json.dumps(voice_coverage, ensure_ascii=False, indent=2), encoding="utf-8")
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
    print(f"Staging vérifié : registres anonymisés, {voice_coverage['recorded']}/{voice_coverage['total']} bulles enregistrées, {voice_coverage['pending']} en attente explicite ; 60 photos, 30 territoires, portraits et modèle CC0.", flush=True)


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
    voice_coverage = validate_voice_assets(source)
    preset = (PROJECT / "windows-release.cfg").read_text(encoding="utf-8-sig")
    preset = preset.replace("{{RELEASE_TEMPLATE}}", template.as_posix())
    (source / "export_presets.cfg").write_text(preset, encoding="utf-8")
    app = target / "OvalLegacy27-PrototypeGodot"
    app.mkdir()
    env = dict(os.environ, APPDATA=str(work / "profile"), LOCALAPPDATA=str(work / "profile-local"))
    Path(env["APPDATA"]).mkdir(parents=True)
    Path(env["LOCALAPPDATA"]).mkdir(parents=True)
    executable = app / "OvalLegacy27.exe"
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
        # This one module contains active progression code, no roster identities.
        allowed_progression = relative == path.name == "lnr-v11-aging.js"
        if not path.is_relative_to((ROOT / "dist").resolve()) or ("lnr-" in path.name and not allowed_progression):
            raise ValueError("Module hors périmètre : " + relative)
        destination = core / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
    licenses = app / "Licences"
    shutil.copytree(sdk / "licenses", licenses)
    shutil.copytree(PROJECT / "fonts", licenses / "fontes", ignore=shutil.ignore_patterns("*.import"))
    shutil.copy2(ROOT / "docs/club-atlas-credits.md", licenses / "photos.md")
    shutil.copy2(PROJECT / "guide/assets/NOTICE.md", licenses / "coach-original.md")
    shutil.copy2(PROJECT / "guide/assets/NOTICE-coach-poses.md", licenses / "coach-16-poses.md")
    voice_licenses = licenses / "voix-coach"
    voice_licenses.mkdir()
    for document in (PROJECT / "guide/assets/voice").iterdir():
        if document.suffix in (".txt", ".md"):
            shutil.copy2(document, voice_licenses / document.name)
    shutil.copy2(ROOT / "dist/assets/club-atlas/manifest.json", licenses / "photos-manifest.json")
    shutil.copytree(ROOT / "dist/match3d/assets", licenses / "modele3d",
                    ignore=shutil.ignore_patterns("*.glb", "*.gltf", "*.bin", "*.png", "*.jpg"))
    (app / "LISEZ-MOI.txt").write_text(
        "OVAL LEGACY 27 — RUGBY MANAGER — PRÉALPHA 0.7\n\n"
        "Lancer OvalLegacy27.exe. Aucun navigateur, Godot ou Node à installer.\n"
        "Conserver le dossier complet avec runtime et engine. Windows x64.\n\n"
        "Nouvelle carrière : Monde (56 clubs jouables) ou France (30 clubs).\n"
        "Chaque édition partage ses joueurs et statistiques entre les packs.\n"
        "Importez un pack personnalisé à la création ou dans les paramètres.\n"
        "Disponible à la création et dans les paramètres de carrière.\n"
        "Les packs changent les noms/images, pas les statistiques/progrès.\n"
        "Composition à23, entraînement, tactiques, recrutement et contrats.\n"
        "Staffs par club, centre de formation, dossier adverse et besoins de recrutement.\n"
        "Presse : 500 questions, cinq réponses dont Humour et relations avec les journalistes.\n"
        "Vestiaire, rivalités, sponsors, projets, supporters et mobilité du manager.\n"
        "Formation de base dans le monde ; réseau Espoirs avancé dans l’édition France.\n"
        "Six rubriques et sous-menus ; Ctrl+K pour chercher, Alt+flèches pour revenir.\n"
        "Club → Histoire compare les saisons réellement archivées.\n"
        "Carnet du coach : notes sur la carrière et les joueurs, conservées à l'import.\n"
        "Match → Journal permet de relire et filtrer les faits du match.\n"
        "Paramètres : Confort / Son / Affichage ; volumes interface et stade séparés.\n"
        "Plein écran au lancement ; mode fenêtré disponible dans Affichage.\n"
        "Gabi : aide vocale locale, petites bulles et16poses illustrées.\n"
        f"{voice_notice(voice_coverage)}"
        "Match3D, phases finales, montées/descentes françaises et saisons suivantes.\n"
        "Monde : 58 clubs, 56 jouables, quatre championnats et deux coupes d’Europe.\n"
        "Les anciennes carrières 14/30 restent importables et jouables.\n\n"
        "Parcours : Nouvelle carrière → club → Composition → Préparation → Match.\n"
        "Pause pour les changements ; Adjoint pour déléguer la fin du match.\n"
        "Valider la journée après le résultat. Menu & sauvegardes pour exporter.\n"
        "Les promotions du centre peuvent compléter une feuille incomplète ;\n"
        "leur coût salarial est annoncé avant confirmation.\n\n"
        "Capacités et finances de jeu, non officielles. Crédits atlas dans Licences.\n"
        "Photos officielles et illustrations IA des packs signalées séparément.\n"
        "Profil séparé : %APPDATA%/CadrageDebordement/PrototypeGodot.\n"
        "Format2026/27 ; lois de match existantes2025, couverture partielle.\n"
        "Monde : 46 semaines de gestion, calendriers sourcés et générés identifiés.\n"
        "France historique : 34 semaines, sans Nationale ; stade3D générique.\n"
        "Préalpha à tester ; publication Steam et finition commerciale à venir.\n", encoding="utf-8")
    modding = app / "Packs"
    modding.mkdir()
    example = {"schema": "cd-identity-pack-v1", "id": "mon-club", "name": "Mon univers", "version": "1.0.0",
               "databaseId": "rugby-common-2026-10-31-v1", "rightsStatus": "user-provided",
               "clubs": [{"id": 0, "name": "Les Albatros XV"}],
               "players": [{"id": "lnr:2399", "name": "Mon premier joueur"}], "assets": []}
    with zipfile.ZipFile(modding / "Exemple-identites.zip", "w", zipfile.ZIP_DEFLATED) as example_zip:
        example_zip.writestr("pack.json", json.dumps(example, ensure_ascii=False, indent=2))
    staff = json.loads((ROOT / "native/engine/staff-registry.json").read_text(encoding="utf-8-sig"))
    staff_id = staff["clubs"][0]["members"][0]["id"]
    example_v2 = dict(example, schema="cd-identity-pack-v2", id="mon-univers-staff", name="Mon univers avec staff",
                      staff=[{"id": staff_id, "name": "Mon entraîneur"}])
    with zipfile.ZipFile(modding / "Exemple-staff-identites.zip", "w", zipfile.ZIP_DEFLATED) as example_zip:
        example_zip.writestr("pack.json", json.dumps(example_v2, ensure_ascii=False, indent=2))
    world = json.loads((ROOT / "native/engine/world-registry.json").read_text(encoding="utf-8"))
    world_staff = json.loads((ROOT / "native/engine/world-staff-registry.json").read_text(encoding="utf-8"))
    assert world["clubCount"] == len(world["clubs"]) == len(world_staff["clubs"]) == 58
    assert sum(len(c["players"]) for c in world["clubs"]) == world["playerCount"]
    example_world = dict(example_v2, id="mon-univers-monde", name="Mon univers mondial", databaseId=world["id"],
                         clubs=[{"id": 30, "name": "Les Albatros XV"}],
                         players=[{"id": world["clubs"][30]["players"][0]["id"], "name": "Mon premier joueur"}],
                         staff=[{"id": world_staff["clubs"][30]["members"][0]["id"], "name": "Mon entraîneur"}])
    with zipfile.ZipFile(modding / "Exemple-identites-monde.zip", "w", zipfile.ZIP_DEFLATED) as example_zip:
        example_zip.writestr("pack.json", json.dumps(example_world, ensure_ascii=False, indent=2))
    (modding / "LIRE-MOI.txt").write_text(
        "PACKS OVAL LEGACY 27\n\nÀ la création, ouvrir la page des packs puis Importer un pack ZIP.\n"
        "En carrière : Menu → Paramètres → Importez un pack personnalisé.\n"
        "Après analyse, installer puis sélectionner le pack. La base anonymisée reste disponible.\n\n"
        "Exemple-identites.zip contient un pack de noms sans images. Décompresser, modifier\n"
        "pack.json puis zipper ce fichier à la racine du ZIP. Les IDs sont stables ;\n"
        "les noms et images peuvent être partiels. Aucune statistique ne change.\n"
        "Pour les images PNG/JPEG/WebP, déclarer assets [{id,path,sha256,bytes}], puis\n"
        "référencer leur id dans clubs[].logo ou players[].portrait.\n"
        "players[].synthetic=true signale une illustration IA. Les chemins restent relatifs.\n"
        "Exemple-staff-identites.zip utilise cd-identity-pack-v2 : staff[] contient\n"
        "id, name et éventuellement portrait/synthetic. Les IDs staff sont distincts\n"
        "des joueurs ; consulter engine/staff-registry.json pour les correspondances.\n"
        "Le format v1 reste accepté ; les statistiques ne sont pas importées.\n"
        "Exemple-identites-monde.zip cible la nouvelle édition Monde. Ses IDs sont dans\n"
        "engine/world-registry.json et engine/world-staff-registry.json. Choisir l’édition\n"
        "correspondante avant d’importer ; les préférences sont séparées.\n"
        "Les images personnalisées sont fournies séparément dans les packs importés.\n",
        encoding="utf-8")
    files = {p.relative_to(app).as_posix(): {"sha256": digest(p), "bytes": p.stat().st_size}
             for p in sorted(app.rglob("*")) if p.is_file()}
    (app / "manifest-build.json").write_text(json.dumps({"prototype": True, "version": "0.7.0", "name": "Oval Legacy 27", "edition": 27, "mode": "world", "database": world["id"], "clubs": world["clubCount"], "players": world["playerCount"], "files": files}, indent=2), encoding="utf-8")
    archive = target / "OvalLegacy27-PrototypeGodot-Windows-x64.zip"
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
