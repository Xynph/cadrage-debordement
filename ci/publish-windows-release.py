"""Publish an exact Windows receipt to a draft GitHub Release, never a final release.

Release assets avoid Actions artifact/cache storage. Profiles, SDK downloads and
executables from the QA copy never enter the proof bundle. A failed build can
publish diagnostics only; its game ZIP is not attached as a received delivery.
"""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile


def require(ok, message):
    if not ok:
        raise ValueError(message)


def verifier():
    spec = importlib.util.spec_from_file_location("windows_package", Path(__file__).with_name("windows-package.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def evidence_files(root):
    """Explicit selection; never recurse into a disposable career or game tree."""
    root = Path(root).resolve()
    files = {}
    def add(path, name):
        if path.is_file():
            require(not path.is_symlink() and root in path.resolve().parents, "Evidence link/outside path refused")
            require(path.stat().st_size < 512 * 1024**2, "Oversized evidence file")
            files[name] = path
    for name in ("controller-unit.log", "prepare.log", "build.log"):
        add(root / name, name)
    for name in ("import.log", "export.log"):
        add(root / "official-build/build" / name, "build/" + name)
    for name in ("windows-report.json", "archive.json", "mesa-qa.json", "qa-extras.json", "manifest-before.json", "manifest-after.json"):
        add(root / "evidence" / name, name)
    add(root / "official-build/RugbyLegacy27-PrototypeGodot/manifest-build.json", "manifest-build.json")
    add(root / "tools/toolchain-receipt.json", "tools/toolchain-receipt.json")
    add(root / "tools/mesa/mesa-receipt.json", "tools/mesa-receipt.json")
    # Include actual inspected component notices (paths come from the verified receipt).
    mesa = root / "tools/mesa/mesa-receipt.json"
    if mesa.is_file():
        document = json.loads(mesa.read_text(encoding="utf-8-sig"))
        for row in document.get("licenses", []):
            name = row["path"]
            verifier().safe_name(name)
            add(root / "tools/mesa" / name, "tools/mesa-notices/" + name)
    for mode in ("fresh", "resume", "angle-clean", "mesa-native", "mesa-local"):
        directory = root / "evidence" / mode
        for name in ("report.json", "process.json", "loaded-modules.json", "graphics-progress.json", "driver-ack.json", "stdout.log", "stderr.log"):
            add(directory / name, mode + "/" + name)
        if directory.is_dir():
            for image in sorted(directory.glob("*.png")):
                add(image, mode + "/captures/" + image.name)
    return files


def require_received_evidence(files):
    """A received delivery must preserve the complete proof, not only its verdict."""
    required = {"controller-unit.log", "prepare.log", "build.log", "build/import.log", "build/export.log",
                "windows-report.json", "archive.json", "qa-extras.json",
                "manifest-before.json", "manifest-after.json", "manifest-build.json",
                "tools/toolchain-receipt.json", "tools/mesa-receipt.json"}
    for mode in ("fresh", "resume"):
        required.update(mode + "/" + name for name in
                        ("report.json", "process.json", "loaded-modules.json", "stdout.log", "stderr.log"))
    require(required <= files.keys(), "Missing received evidence: " + ", ".join(sorted(required - files.keys())))
    module = verifier()
    report = module.json_document(files["windows-report.json"].read_text(encoding="utf-8-sig"))
    require(report.get("passed") is True and report.get("scope") != "graphics-smoke-only",
            "A received proof bundle requires a passed full Windows receipt")
    mesa_dlls = any(name.lower().endswith(".dll") and str(row.get("source", "")).startswith("x64/")
                    for name, row in report.get("qaExtras", {}).items())
    # Prepared Mesa tools/notices are not evidence that DLLs were copied or loaded.
    # A clean ANGLE run has no install_mesa receipt to preserve or manufacture.
    if report.get("selectedGraphicsDriver") != "opengl3_angle" or report.get("mesa") or mesa_dlls:
        require("mesa-qa.json" in files, "Missing received evidence: mesa-qa.json")
    for mode in ("fresh", "resume"):
        for name, expected in (("report.json", report.get(mode)),
                               ("process.json", report.get("process", {}).get(mode))):
            actual = module.json_document(files[mode + "/" + name].read_text(encoding="utf-8-sig"))
            require(isinstance(expected, dict) and actual == expected,
                    mode + "/" + name + " differs from receipt")
        if "driver_ack" in report[mode]:
            name = mode + "/driver-ack.json"
            require(name in files, "Missing received evidence: " + name)
            actual = module.json_document(files[name].read_text(encoding="utf-8-sig"))
            require(actual == report[mode]["driver_ack"], name + " differs from receipt")
    captures = report["resume"].get("graphics", {}).get("captures", [])
    require(isinstance(captures, list) and captures, "Missing received capture evidence")
    directory = files["resume/report.json"].parent.resolve()
    for row in captures:
        path = Path(row.get("path", "")).resolve()
        selected = files.get("resume/captures/" + path.name)
        require(path.parent == directory and selected is not None and selected.resolve() == path,
                "Missing received capture in resume evidence: " + str(path))
    mesa = module.json_document(files["tools/mesa-receipt.json"].read_text(encoding="utf-8-sig"))
    for row in mesa.get("licenses", []):
        name = "tools/mesa-notices/" + row["path"]
        require(name in files, "Missing received evidence: " + name)


def create_bundle(root, destination, metadata):
    files = evidence_files(root)
    require(files, "No actual diagnostic or QA evidence to publish")
    if metadata.get("passed") is True:
        require_received_evidence(files)
    require(not Path(destination).exists(), "Refuse an existing proof bundle")
    with zipfile.ZipFile(destination, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        archive.writestr("delivery.json", json.dumps(metadata, indent=2, ensure_ascii=False))
        for name, path in sorted(files.items()):
            archive.write(path, name)
    return files


def received_report(root, source_commit):
    module = verifier()
    path = Path(root) / "evidence/windows-report.json"
    report = module.json_document(path.read_text(encoding="utf-8-sig"))
    require(report.get("passed") is True, "A failed receipt cannot publish a received game ZIP")
    expected_zip = Path(root) / "official-build/RugbyLegacy27-PrototypeGodot-Windows-x64.zip"
    require(Path(report["package"]["path"]).resolve() == expected_zip.resolve(), "Unexpected package outside official build")
    # Re-run all independent ZIP, process, PNG, source and native-host guards.
    actual_exe = Path(root) / "evidence/Relocated QA with spaces/RugbyLegacy27-PrototypeGodot/RugbyLegacy27.exe"
    module.validate_windows_report(report, source_commit, str(actual_exe))
    return report, expected_zip


def direct_receipt_assets(root, report):
    """Expose the original full report and only its verified resume captures."""
    root = Path(root).resolve()
    files = evidence_files(root)
    require_received_evidence(files)
    module = verifier()
    sources = [("windows-report.json", files["windows-report.json"], module.digest(files["windows-report.json"]))]
    for index, row in enumerate(report["resume"]["graphics"]["captures"], 1):
        path = Path(row["path"]).resolve()
        selected = files.get("resume/captures/" + path.name)
        require(selected is not None and selected.resolve() == path and module.digest(selected) == row["sha256"],
                "Unselected, outside or changed received capture: " + str(path))
        stem = re.sub(r"[^A-Za-z0-9._-]+", "-", path.stem).strip(".-_")[:80] or "capture"
        sources.append((f"windows-resume-{index:02d}-{stem}.png", selected, row["sha256"]))
    destination = root / "public-assets"
    require(not destination.exists(), "Refuse existing direct receipt assets")
    destination.mkdir()
    assets = []
    for name, source, expected_sha in sources:
        target = destination / name
        shutil.copyfile(source, target)
        require(module.digest(target) == expected_sha, "Direct receipt asset bytes changed: " + name)
        assets.append(target)
    return assets


def gh(*args):
    result = subprocess.run(["gh", *args], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, encoding="utf-8", timeout=600)
    return result.stdout.strip()


def publish(root, source_commit, repo, run_id, attempt, diagnostic=False):
    require(re.fullmatch(r"[0-9a-f]{40}", source_commit), "Exact source SHA required")
    require(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo), "Invalid GitHub repository")
    require(re.fullmatch(r"[0-9]+", run_id) and re.fullmatch(r"[0-9]+", attempt), "Run identity required")
    root = Path(root).resolve()
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], encoding="ascii").strip()
    require(head == source_commit, "Publisher checkout differs from the received source")
    package, report = None, None
    if not diagnostic:
        report, package = received_report(root, source_commit)
    prefix = "windows-diagnostic" if diagnostic else "windows-received"
    tag = f"{prefix}-{source_commit[:12]}-{run_id}-{attempt}"
    metadata = {"schema": "oval-windows-delivery-v1", "sourceCommit": source_commit,
                "sourceTree": report["sourceTree"] if report else None,
                "passed": not diagnostic, "draft": True,
                "run": f"https://github.com/{repo}/actions/runs/{run_id}",
                "scope": "diagnostics only" if diagnostic else "native Windows EXE, full season, saved-profile resume and real 1440p graphics",
                "limits": ["Draft only: publish after the official merge gate and exact main CI are verified", "Gabi voice disabled; Dummy audio requested and observed"] if report else ["Build or QA failed; no game ZIP is delivered"]}
    module = verifier()
    if package:
        metadata["package"] = {"name": package.name, "sha256": module.digest(package), "bytes": package.stat().st_size}
    direct_assets = direct_receipt_assets(root, report) if report else []
    if direct_assets:
        metadata["receiptAssets"] = [{"name": path.name, "sha256": module.digest(path), "bytes": path.stat().st_size}
                                    for path in direct_assets]
    bundle = root / f"{tag}-proofs.zip"
    files = create_bundle(root, bundle, metadata)
    metadata["proofBundle"] = {"name": bundle.name, "sha256": module.digest(bundle), "bytes": bundle.stat().st_size, "files": len(files)}
    metadata_path = root / "delivery.json"
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    assets = ([package] if package else []) + [bundle, metadata_path] + direct_assets
    sums = root / "SHA256SUMS.txt"
    sums.write_text("".join(f"{module.digest(path)}  {path.name}\n" for path in assets), encoding="ascii")
    assets.append(sums)
    require(all(path.stat().st_size < 2 * 1024**3 for path in assets), "GitHub Release asset limit exceeded")
    notes = root / "release-notes.md"
    notes.write_text(f"Source: `{source_commit}`\n\nCI and native receipt: {metadata['run']}\n\n"
                     + ("**Diagnostic draft: build/QA failed. No received game ZIP.**\n" if diagnostic else
                        f"**Received Windows package; draft awaiting final integration verification.**\n\nZIP SHA256: `{metadata['package']['sha256']}`\n\n"
                        "Extract the whole ZIP to a writable folder and launch `RugbyLegacy27.exe`. Saves remain outside the game folder. No Node/Python/Godot installation is required. Gabi remains silent.\n"), encoding="utf-8")
    title = f"Windows {'diagnostics' if diagnostic else 'received'} · {source_commit[:12]} · {run_id}/{attempt}"
    gh("release", "create", tag, "--repo", repo, "--target", source_commit, "--draft", "--prerelease", "--title", title, "--notes-file", str(notes))
    gh("release", "upload", tag, *(str(path) for path in assets), "--repo", repo)
    release = json.loads(gh("release", "view", tag, "--repo", repo, "--json", "url,isDraft,assets"))
    require(release["isDraft"] is True and {p.name for p in assets} <= {p["name"] for p in release["assets"]}, "Draft asset upload incomplete")
    result = {"tag": tag, "url": release["url"], "passed": not diagnostic, "sourceCommit": source_commit, "assets": [p.name for p in assets]}
    print(json.dumps(result, indent=2))
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as stream:
            stream.write(f"\n### Windows {'diagnostics' if diagnostic else 'native receipt'}\n\nDraft: {release['url']}\n\nSource: `{source_commit}`\n\n")
            if package:
                stream.write(f"ZIP SHA256: `{metadata['package']['sha256']}`\n\n")
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--attempt", required=True)
    parser.add_argument("--diagnostic", action="store_true")
    args = parser.parse_args()
    publish(args.root, args.source_commit, args.repo, args.run_id, args.attempt, args.diagnostic)
