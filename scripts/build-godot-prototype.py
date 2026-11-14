"""Stage native assets and optionally export a self-contained Windows prototype.

No network access. SDK/runtime paths are explicit, never downloaded by this build.
Generated directories stay outside tracked source; an existing output is refused.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import wave
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "native/godot"
BUILD_VERSION = "0.7.8"


def source_provenance(expected_commit, root=ROOT):
    if not isinstance(expected_commit, str) or not re.fullmatch(r"[0-9a-f]{40}", expected_commit):
        raise ValueError("--source-commit exige un SHA Git complet de 40 caractères")
    def git(*arguments):
        return subprocess.check_output(["git", *arguments], cwd=root, encoding="utf-8", timeout=10).strip()
    commit, tree = git("rev-parse", "--verify", "HEAD"), git("rev-parse", "--verify", "HEAD^{tree}")
    dirty = git("status", "--porcelain", "--untracked-files=no")
    extra_inputs = git("ls-files", "--others", "--exclude-standard", "--", "native/godot", "native/engine", "dist")
    if commit != expected_commit or not re.fullmatch(r"[0-9a-f]{40}", tree) or dirty or extra_inputs:
        raise ValueError("Provenance refusée : SHA différent, arbre suivi modifié ou ressource distribuée non suivie")
    return {"sourceCommit": commit, "sourceTree": tree}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verified_node_notices(node, directory):
    version = subprocess.check_output(
        [str(node.resolve()), "--version"], encoding="ascii", timeout=10,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
    ).strip()
    if not re.fullmatch(r"v\d+\.\d+\.\d+", version):
        raise ValueError("Version de distribution Node stable requise")
    license_file = directory / f"Node-{version}-LICENSE.txt"
    shasums_file = directory / f"Node-{version}-SHASUMS256.txt"
    if not license_file.is_file() or not license_file.stat().st_size or not shasums_file.is_file():
        raise ValueError(f"Fournir les notices Node {version} de la distribution officielle dans {directory}")
    expected = re.findall(
        r"^([a-fA-F0-9]{64})[ \t]+\*?win-x64/node\.exe[ \t]*$",
        shasums_file.read_text(encoding="ascii"),
        flags=re.MULTILINE,
    )
    runtime_sha = digest(node)
    if [value.lower() for value in expected] != [runtime_sha]:
        raise ValueError(f"Empreinte Node {version} win-x64 absente, ambiguë ou différente du runtime fourni")
    return (license_file, shasums_file), runtime_sha


def copy_build_licenses(sdk_licenses, destination, node_notices):
    shutil.copytree(
        sdk_licenses, destination,
        ignore=shutil.ignore_patterns("Node-v*-LICENSE.txt", "Node-v*-SHASUMS256.txt"),
    )
    for notice in node_notices:
        shutil.copy2(notice, destination / notice.name)


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
    notice = ("Gabi reste silencieux dans cet export : aucune lecture WAV ni synthèse TTS active.\n"
              f"Ses {coverage['recorded']} enregistrements sont conservés comme ressources.\n")
    if coverage["pending"]:
        plural = "s" if coverage["pending"] != 1 else ""
        notice += f"{coverage['pending']} réplique{plural} en attente d'enregistrement.\n"
    return notice + "Crédits et licences des voix : Licences/voix-coach.\n"


def stage(node):
    for compiler in ("build-staff-registry.cjs", "build-rugby-common.cjs", "base-names.cjs", "build-world-registry.cjs"):
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


def stage_windows_qa(project):
    # The official release template ignores --script. Ship named QA main loops,
    # dormant until an override.cfg is added to a verified, disposable QA copy.
    if any(path.name.casefold() == "override.cfg" for path in project.rglob("*")):
        raise ValueError("Un override.cfg de recette ne doit jamais être livré")
    qa = project / "windows_qa"
    qa.mkdir()
    for name in ("windows-resume.gd", "windows-graphics-smoke.gd", "windows-hardware-receipt.gd"):
        shutil.copy2(ROOT / "ci" / name, qa / name)
    (qa / "entry.tscn").write_text('[gd_scene format=3]\n[node name="WindowsReceiptEntry" type="Node"]\n', encoding="utf-8")


def build(args):
    provenance = source_provenance(args.source_commit)
    target = args.output.resolve()
    if target.exists():
        raise ValueError("Choisir un nouveau dossier de sortie : aucun écrasement autorisé")
    sdk = args.sdk.resolve()
    editor = sdk / "editor/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe"
    template = sdk / "templates/4.7.2-stable/windows_release_x86_64.exe"
    assert editor.is_file() and template.is_file(), "SDK Windows4.7.2 requis"
    sdk_licenses = sdk / "licenses"
    node_notices, node_sha = verified_node_notices(args.node, args.node_notices or sdk_licenses)
    stage(args.node)
    target.mkdir(parents=True)
    work = target / "build"
    source = work / "project"
    shutil.copytree(PROJECT, source, ignore=shutil.ignore_patterns(".godot", "*.uid", "*.import", "export_presets.cfg"))
    stage_windows_qa(source)
    project_file = source / "project.godot"
    config, replacements = re.subn(r'^config/version="[^"]+"$', f'config/version="{BUILD_VERSION}"', project_file.read_text(encoding="utf-8"), flags=re.MULTILINE)
    assert replacements == 1, "Version du projet absente ou ambiguë"
    # The SDK can crash while importing several fonts in parallel on Windows.
    # Keep the editor-only build stage serial; the shipped game is unaffected.
    assert "\n[editor]\n" not in config
    config += "\n[editor]\n\nimport/use_multiple_threads=false\n"
    project_file.write_text(config, encoding="utf-8")
    voice_coverage = validate_voice_assets(source)
    preset = (PROJECT / "windows-release.cfg").read_text(encoding="utf-8-sig")
    preset = preset.replace("{{RELEASE_TEMPLATE}}", template.as_posix())
    (source / "export_presets.cfg").write_text(preset, encoding="utf-8")
    app = target / "RugbyLegacy27-PrototypeGodot"
    app.mkdir()
    env = dict(os.environ, APPDATA=str(work / "profile"), LOCALAPPDATA=str(work / "profile-local"))
    Path(env["APPDATA"]).mkdir(parents=True)
    Path(env["LOCALAPPDATA"]).mkdir(parents=True)
    executable = app / "RugbyLegacy27.exe"
    for name, tail in [("import", ["--import"]), ("export", ["--export-release", "Windows Desktop", str(executable)])]:
        cmd = [str(editor), "--headless", "--path", str(source)] + tail
        result = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                encoding="utf-8", errors="replace", timeout=180,
                                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        (work / f"{name}.log").write_text(result.stdout, encoding="utf-8")
        if result.returncode or "ERROR:" in result.stdout or "SCRIPT ERROR" in result.stdout:
            raise RuntimeError(f"Godot {name} échoué ; consulter {work / (name + '.log')}")
    (app / "runtime").mkdir()
    runtime = app / "runtime/node.exe"
    shutil.copy2(args.node, runtime)
    if digest(runtime) != node_sha:
        raise ValueError("Le runtime Node a changé depuis la vérification des notices")
    engine = app / "engine"
    shutil.copytree(ROOT / "native/engine", engine)
    # Niveau réel compilé, sans nom (barème senior V2 des nouvelles carrières Monde) : lu à côté du moteur.
    shutil.copy2(ROOT / "data/world/niveaux-v2.json", engine / "world-niveaux-v2.json")
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
    copy_build_licenses(sdk_licenses, licenses, node_notices)
    shutil.copy2(PROJECT / "art/flags/LICENSE.txt", licenses / "drapeaux.txt")
    shutil.copytree(PROJECT / "fonts", licenses / "fontes", ignore=shutil.ignore_patterns("*.import"))
    shutil.copy2(ROOT / "docs/club-atlas-credits.md", licenses / "photos.md")
    shutil.copy2(ROOT / "docs/scenario-visual-credits.md", licenses / "illustrations-scenario.md")
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
        f"RUGBY LEGACY 27 — PRÉALPHA {BUILD_VERSION}\n\n"
        "Lancer RugbyLegacy27.exe. Aucun navigateur, Godot ou Node à installer.\n"
        "Conserver le dossier complet avec runtime et engine. Windows x64.\n\n"
        "Monde + Champ : 116 clubs, dont 114 jouables. Chaque club démarre avec au moins 40 pros, 30 U18 et 30 U21.\n"
        "Pour compléter les centres d’une ancienne carrière, ouvrez Formation puis vérifiez le passage aux nouveaux effectifs.\n"
        "Le jeu de base et les réalités importées partagent le même catalogue et les mêmes règles.\n"
        "Choisissez un pays ou International, puis une division et un club.\n"
        "À la création, « Importer une autre réalité » ouvre le sélecteur de fichiers ZIP.\n"
        "Disponible à la création et dans les paramètres de carrière.\n"
        "Les packs changent les noms/images, pas les statistiques/progrès.\n"
        "Composition à23, entraînement, tactiques, recrutement et contrats.\n"
        "Staffs par club, centre de formation, dossier adverse et besoins de recrutement.\n"
        "Presse : ouvrez l’invitation dans la Réception et publiez vos réponses pour reprendre la progression.\n"
        "Vestiaire, rivalités, sponsors, projets, supporters et mobilité du manager.\n"
        "Formation de base dans le monde ; réseau Espoirs avancé dans l’édition France.\n"
        "Six rubriques et sous-menus ; Ctrl+K pour chercher, Alt+flèches pour revenir.\n"
        "Club → Histoire compare les saisons réellement archivées.\n"
        "Carnet du coach : notes sur la carrière et les joueurs, conservées à l'import.\n"
        "Match → Journal permet de relire et filtrer les faits du match.\n"
        "Paramètres : Confort / Son / Affichage ; volumes interface et stade séparés.\n"
        "Plein écran au lancement ; mode fenêtré disponible dans Affichage.\n"
        "Gabi est en pause dans cet export. Ses enregistrements et illustrations restent inclus.\n"
        f"{voice_notice(voice_coverage)}"
        "Match3D, phases finales, montées/descentes françaises et saisons suivantes.\n"
        "Monde + Pacifique : 68 clubs, 66 jouables, cinq championnats et deux coupes d’Europe.\n"
        "Monde + Japon : 88 clubs, 86 jouables ; D1/D2 japonaises et barrages aller-retour.\n"
        "La frontière japonaise D2–D3 est fermée et les feuilles se jouent à 23.\n"
        "Monde + Nationale : 102 clubs, 100 jouables, accès et barrage vers la Pro D2.\n"
        "La Nationale 2 ne participe pas à cette édition.\n"
        "Monde + Champ : 116 clubs, 114 jouables, 14 clubs anglais de deuxième division.\n"
        "Aucun échange automatique entre le Champ et le PREM en 2026–27.\n"
        "Les éditions Japon 86, Pacifique 66, Monde 56 et France restent disponibles.\n"
        "Les anciennes carrières 14/30 restent importables et jouables.\n\n"
        "Parcours : Nouvelle carrière → club → Composition → Préparation → Match.\n"
        "Pause pour les changements ; Adjoint pour déléguer la fin du match.\n"
        "Cliquez sur la date pour ouvrir le calendrier. Jour suivant fait avancer la carrière d’un jour.\n"
        "Validez le résultat après le match. Menu & sauvegardes permet d’exporter la carrière.\n"
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
    pacific = json.loads((ROOT / "native/engine/world-pacific-extension.json").read_text(encoding="utf-8"))
    pacific_staff = json.loads((ROOT / "native/engine/world-pacific-staff-extension.json").read_text(encoding="utf-8"))
    assert pacific["baseId"] == world["id"] == pacific_staff["baseId"]
    assert pacific["id"] == pacific_staff["databaseId"] and pacific["version"] == 2
    assert [c["id"] for c in pacific["clubs"]] == list(range(58,68))
    assert [c["id"] for c in pacific_staff["clubs"]] == list(range(58,68))
    assert all(c["members"] for c in pacific_staff["clubs"])
    pacific_count = world["playerCount"] + sum(len(c["players"]) for c in pacific["clubs"])
    japan = json.loads((ROOT / "native/engine/world-japan-extension.json").read_text(encoding="utf-8"))
    japan_staff = json.loads((ROOT / "native/engine/world-japan-staff-extension.json").read_text(encoding="utf-8"))
    assert japan["baseId"] == pacific["id"] == japan_staff["baseId"]
    assert japan["id"] == japan_staff["databaseId"] and japan["version"] == 3
    assert [c["id"] for c in japan["clubs"]] == [c["id"] for c in japan_staff["clubs"]] == list(range(68, 88))
    assert all(c["members"] for c in japan_staff["clubs"])
    assert all(c["key"] == f'jlo:slot-{c["id"]}' for c in japan["clubs"])
    japan_count = pacific_count + sum(len(c["players"]) for c in japan["clubs"])
    nationale = json.loads((ROOT / "native/engine/world-nationale-extension.json").read_text(encoding="utf-8"))
    nationale_staff = json.loads((ROOT / "native/engine/world-nationale-staff-extension.json").read_text(encoding="utf-8"))
    assert nationale["baseId"] == japan["id"] == nationale_staff["baseId"]
    assert nationale["id"] == nationale_staff["databaseId"] and nationale["version"] == 4
    assert [c["id"] for c in nationale["clubs"]] == [c["id"] for c in nationale_staff["clubs"]] == list(range(88, 102))
    assert all(c["members"] for c in nationale_staff["clubs"])
    assert all(c["key"] == f'nat:slot-{c["id"]}' for c in nationale["clubs"])
    nationale_count = japan_count + sum(len(c["players"]) for c in nationale["clubs"])
    champ = json.loads((ROOT / "native/engine/world-champ-extension.json").read_text(encoding="utf-8"))
    champ_staff = json.loads((ROOT / "native/engine/world-champ-staff-extension.json").read_text(encoding="utf-8"))
    assert champ["baseId"] == nationale["id"] == champ_staff["baseId"]
    assert champ["id"] == champ_staff["databaseId"] and champ["version"] == 5
    assert [c["id"] for c in champ["clubs"]] == [c["id"] for c in champ_staff["clubs"]] == list(range(102, 116))
    assert all(c["members"] for c in champ_staff["clubs"])
    assert all(c["key"] == f'champ:slot-{c["id"]}' for c in champ["clubs"])
    champ_count = nationale_count + sum(len(c["players"]) for c in champ["clubs"])
    example_world = dict(example_v2, id="mon-univers-monde", name="Mon univers mondial", databaseId=world["id"],
                         clubs=[{"id": 30, "name": "Les Albatros XV"}],
                         players=[{"id": world["clubs"][30]["players"][0]["id"], "name": "Mon premier joueur"}],
                         staff=[{"id": world_staff["clubs"][30]["members"][0]["id"], "name": "Mon entraîneur"}])
    with zipfile.ZipFile(modding / "Exemple-identites-monde.zip", "w", zipfile.ZIP_DEFLATED) as example_zip:
        example_zip.writestr("pack.json", json.dumps(example_world, ensure_ascii=False, indent=2))
    example_pacific = dict(example_v2, id="mon-univers-pacifique", name="Mon univers Pacifique", databaseId=pacific["id"],
                           clubs=[{"id": 58, "name": "Mon club du Pacifique"}],
                           players=[{"id": pacific["clubs"][0]["players"][0]["id"], "name": "Mon premier joueur"}],
                           staff=[{"id": pacific_staff["clubs"][0]["members"][0]["id"], "name": "Mon entraîneur"}])
    with zipfile.ZipFile(modding / "Exemple-identites-pacifique.zip", "w", zipfile.ZIP_DEFLATED) as example_zip:
        example_zip.writestr("pack.json", json.dumps(example_pacific, ensure_ascii=False, indent=2))
    example_japan = dict(example_v2, id="mon-univers-japon", name="Mon univers Japon", databaseId=japan["id"],
                         clubs=[{"id": 68, "name": "Mon club du Japon"}],
                         players=[{"id": japan["clubs"][0]["players"][0]["id"], "name": "Mon premier joueur"}],
                         staff=[{"id": japan_staff["clubs"][0]["members"][0]["id"], "name": "Mon entraîneur"}])
    with zipfile.ZipFile(modding / "Exemple-identites-japon.zip", "w", zipfile.ZIP_DEFLATED) as example_zip:
        example_zip.writestr("pack.json", json.dumps(example_japan, ensure_ascii=False, indent=2))
    example_nationale = dict(example_v2, id="mon-univers-nationale", name="Mon univers Nationale", databaseId=nationale["id"],
                             clubs=[{"id": 88, "name": "Mon club de Nationale"}],
                             players=[{"id": nationale["clubs"][0]["players"][0]["id"], "name": "Mon premier joueur"}],
                             staff=[{"id": nationale_staff["clubs"][0]["members"][0]["id"], "name": "Mon entraîneur"}])
    with zipfile.ZipFile(modding / "Exemple-identites-nationale.zip", "w", zipfile.ZIP_DEFLATED) as example_zip:
        example_zip.writestr("pack.json", json.dumps(example_nationale, ensure_ascii=False, indent=2))
    example_champ = dict(example_v2, id="mon-univers-champ", name="Mon univers Champ", databaseId=champ["id"],
                          clubs=[{"id": 102, "name": "Mon club du Champ"}],
                          players=[{"id": champ["clubs"][0]["players"][0]["id"], "name": "Mon premier joueur"}],
                          staff=[{"id": champ_staff["clubs"][0]["members"][0]["id"], "name": "Mon entraîneur"}])
    with zipfile.ZipFile(modding / "Exemple-identites-champ.zip", "w", zipfile.ZIP_DEFLATED) as example_zip:
        example_zip.writestr("pack.json", json.dumps(example_champ, ensure_ascii=False, indent=2))
    (modding / "LIRE-MOI.txt").write_text(
        "PACKS RUGBY LEGACY 27\n\nÀ la création, « Importer une autre réalité » ouvre le sélecteur de fichiers ZIP.\n"
        "En carrière : Menu → Paramètres → Importez un pack personnalisé.\n"
        "Après analyse, installer puis sélectionner le pack. La base anonymisée reste disponible.\n\n"
        "Exemple-identites-champ.zip cible la création d’une carrière dans le Monde complet.\n"
        "Les autres exemples ciblent les anciennes carrières compatibles. Décompresser, modifier\n"
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
        "engine/world-registry.json et engine/world-staff-registry.json.\n"
        "Exemple-identites-pacifique.zip cible Monde + Pacifique ; les IDs supplémentaires\n"
        "sont dans engine/world-pacific-extension.json et world-pacific-staff-extension.json.\n"
        "Exemple-identites-japon.zip cible Monde + Japon ; ses nouveaux IDs sont dans\n"
        "engine/world-japan-extension.json et world-japan-staff-extension.json.\n"
        "Exemple-identites-nationale.zip cible Monde + Nationale et les identifiants dans\n"
        "engine/world-nationale-extension.json et world-nationale-staff-extension.json.\n"
        "Exemple-identites-champ.zip cible Monde + Champ et ses nouveaux identifiants dans\n"
        "engine/world-champ-extension.json et world-champ-staff-extension.json.\n"
        "Les images personnalisées sont fournies séparément dans les packs importés.\n",
        encoding="utf-8")
    if source_provenance(args.source_commit) != provenance:
        raise ValueError("La provenance Git a changé pendant la construction")
    write_build_manifest(app, provenance, champ["id"], champ_count, [world["id"], pacific["id"], japan["id"], nationale["id"]])
    archive = target / "RugbyLegacy27-PrototypeGodot-Windows-x64.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as out:
        for path in sorted(app.rglob("*")):
            if path.is_file():
                out.write(path, path.relative_to(target))
    print(json.dumps({"exe": str(executable), "zip": str(archive), "sha256": digest(archive)}, ensure_ascii=False), flush=True)


def write_build_manifest(app, provenance, database, player_count, compatible_editions):
    files = {p.relative_to(app).as_posix(): {"sha256": digest(p), "bytes": p.stat().st_size}
             for p in sorted(app.rglob("*")) if p.is_file() and p != app / "manifest-build.json"}
    manifest = {**provenance, "prototype": True, "version": BUILD_VERSION, "name": "Rugby Legacy 27", "edition": 27, "mode": "world-champ", "database": database, "clubs": 116, "players": player_count, "compatibleEditions": compatible_editions, "files": files}
    (app / "manifest-build.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return manifest


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--node", type=Path, default=Path(os.environ.get("CD_NODE_EXECUTABLE", r"C:\Program Files\nodejs\node.exe")))
    p.add_argument("--node-notices", type=Path, help="Dossier LICENSE et SHASUMS256 de la version Node fournie (défaut : licences du SDK)")
    p.add_argument("--stage-only", action="store_true")
    p.add_argument("--sdk", type=Path)
    p.add_argument("--output", type=Path)
    p.add_argument("--source-commit", help="SHA complet du checkout propre à exporter (sans effet sur --stage-only)")
    options = p.parse_args()
    if not options.node.is_file():
        p.error("Runtime Node explicite introuvable")
    if options.stage_only:
        stage(options.node)
    else:
        if not options.sdk or not options.output or not options.source_commit:
            p.error("--sdk, --output et --source-commit sont requis pour exporter")
        build(options)
