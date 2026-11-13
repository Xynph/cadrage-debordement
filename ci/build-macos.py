"""Build on a native Mac; verified upstream tools, no private data or credentials."""
import argparse
import hashlib
import importlib.util
import json
import platform
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# This repository contains tracked bytecode from earlier builds. Importing the
# shared builder must not rewrite it before the clean-source provenance check.
sys.dont_write_bytecode = True


def run(*args, **kwargs):
    return subprocess.run(list(map(str, args)), check=True, **kwargs)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def download(url, target, sha):
    urllib.request.urlretrieve(url, target)
    if digest(target) != sha:
        raise ValueError("Upstream checksum mismatch: " + target.name)


def build(args):
    if platform.system() != "Darwin":
        raise ValueError("Native macOS required")
    arch = {"arm64": "arm64", "x86_64": "x64"}[platform.machine()]
    spec = importlib.util.spec_from_file_location("native_builder", ROOT / "scripts/build-godot-prototype.py")
    base = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(base)
    provenance = base.source_provenance(args.source_commit)
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    sdk = out / "sdk"
    sdk.mkdir()
    pins = json.loads((ROOT / "ci/macos-toolchain.json").read_text())
    for name in ("editor", "templates"):
        download(pins[name]["url"], sdk / (name + ".zip"), pins[name]["sha256"])
    run("ditto", "-x", "-k", sdk / "editor.zip", sdk / "editor")
    with zipfile.ZipFile(sdk / "templates.zip") as archive:
        (sdk / "macos.zip").write_bytes(archive.read("templates/macos.zip"))
    node_name = f"node-v{pins['nodeVersion']}-darwin-{arch}"
    download(f"https://nodejs.org/dist/v{pins['nodeVersion']}/{node_name}.tar.gz", sdk / "node.tar.gz", pins["node"][arch])
    with tarfile.open(sdk / "node.tar.gz") as archive:
        archive.extractall(sdk / "node", filter="data")
    node_root = sdk / "node" / node_name
    node = node_root / "bin/node"
    base.stage(node)
    source = out / "project"
    shutil.copytree(base.PROJECT, source, ignore=shutil.ignore_patterns(".godot", "*.uid", "*.import", "export_presets.cfg"))
    qa = source / "macos_qa"
    qa.mkdir()
    shutil.copy2(ROOT / "ci/macos-receipt.gd", qa / "receipt.gd")
    (qa / "entry.tscn").write_text('[gd_scene format=3]\n[node name="MacReceipt" type="Node"]\n')
    preset = (source / "macos-release.cfg").read_text().replace("{{RELEASE_TEMPLATE}}", (sdk / "macos.zip").as_posix())
    (source / "export_presets.cfg").write_text(preset.replace("{{ARCH}}", "arm64" if arch == "arm64" else "x86_64"))
    editor = sdk / "editor/Godot.app/Contents/MacOS/Godot"
    app = out / "Oval Legacy 27.app"
    for name, tail in (("import", ["--import"]), ("export", ["--export-release", "macOS", str(app)])):
        with (out / (name + ".log")).open("w") as log:
            run(editor, "--headless", "--path", source, *tail, stdout=log, stderr=subprocess.STDOUT, timeout=600)
        text = (out / (name + ".log")).read_text()
        if "SCRIPT ERROR" in text or "ERROR:" in text:
            raise RuntimeError("Godot " + name + " failed; see log")
    helpers = app / "Contents/Helpers"
    helpers.mkdir(exist_ok=True)
    shutil.copy2(node, helpers / "node")
    engine = app / "Contents/Resources/engine"
    shutil.copytree(ROOT / "native/engine", engine, ignore=shutil.ignore_patterns("__pycache__"))
    core = engine / "core"
    core.mkdir()
    modules = json.loads(subprocess.check_output([str(node), "-e", "process.stdout.write(JSON.stringify(require('./native/engine/worker.cjs').CORE_FILES))"], cwd=ROOT))
    for relative in modules:
        path = (ROOT / "dist" / relative).resolve()
        if not path.is_relative_to(ROOT / "dist") or ("lnr-" in path.name and relative != "lnr-v11-aging.js"):
            raise ValueError("Module outside distribution scope")
        dest = core / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
    licenses = app / "Contents/Resources/Licences"
    licenses.mkdir()
    shutil.copy2(node_root / "LICENSE", licenses / "Node-LICENSE.txt")
    windows_pins = json.loads((ROOT / "ci/windows-toolchain.json").read_text())
    for notice in windows_pins["godot"]["notices"]:
        download(notice["url"], licenses / Path(notice["destination"]).name, notice["sha256"])
    for folder, name in (("fonts", "fontes"), ("guide/assets/voice", "voix-coach")):
        shutil.copytree(base.PROJECT / folder, licenses / name, ignore=shutil.ignore_patterns("*.import", "*.wav"))
    for src in ("docs/club-atlas-credits.md", "docs/scenario-visual-credits.md", "native/godot/art/flags/LICENSE.txt", "native/godot/guide/assets/NOTICE.md", "native/godot/guide/assets/NOTICE-coach-poses.md"):
        shutil.copy2(ROOT / src, licenses / Path(src).name)
    shutil.copytree(ROOT / "dist/match3d/assets", licenses / "modele3d", ignore=shutil.ignore_patterns("*.glb", "*.gltf", "*.bin", "*.png", "*.jpg"))
    (app / "Contents/Resources/LISEZ-MOI.txt").write_text(
        "Oval Legacy 27 — préalpha macOS\nOuvrir Oval Legacy 27.app. Node et Godot sont embarqués.\n"
        "Carrières : ~/Library/Application Support/CadrageDebordement/PrototypeGodot\n"
        "Les packs ZIP s’importent à la création ou dans les paramètres de carrière.\n"
        "Signature ad hoc pour essais ; aucune notarisation Apple ni signature Developer ID.\n"
        "Un téléchargement peut être bloqué par Gatekeeper. Ne pas désactiver Gatekeeper.\n"
        "Crédits et licences : Contents/Resources/Licences.\n", encoding="utf-8")
    for binary in (helpers / "node", *list((app / "Contents/MacOS").iterdir())):
        binary.chmod(0o755)
        run("lipo", "-verify_arch", "arm64" if arch == "arm64" else "x86_64", binary)
    run("codesign", "--force", "--sign", "-", helpers / "node")
    run("codesign", "--force", "--deep", "--sign", "-", app)
    run("codesign", "--verify", "--deep", "--strict", app)
    package = out / f"OvalLegacy27-macOS-{arch}.zip"
    run("ditto", "-c", "-k", "--keepParent", app, package)
    manifest = {**provenance, "architecture": arch, "package": package.name, "sha256": digest(package), "signing": "ad-hoc", "notarized": False,
                "files": {str(p.relative_to(app)): digest(p) for p in app.rglob("*") if p.is_file()}}
    (out / "build.json").write_text(json.dumps(manifest, indent=2))
    print(json.dumps({k: v for k, v in manifest.items() if k != "files"}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--output", type=Path, required=True)
    build(parser.parse_args())
