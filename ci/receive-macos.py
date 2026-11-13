"""Receive the ZIP built by build-macos.py, with two real application processes.

Default input is a wholly fictional press pack. --pack accepts an existing ZIP
unchanged, only outside public CI, and requires its independently supplied hash.
"""
import argparse
import hashlib
import json
import os
import platform
import subprocess
import zipfile
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fictional_pack(target):
    manifest = {"schema": "cd-identity-pack-v4", "id": "mac-presse-essai", "name": "Le monde des essais", "version": "1",
                "databaseId": "rugby-world-2026-11-09-champ-v5", "rightsStatus": "test-local",
                "clubs": [], "players": [], "staff": [], "competitions": [], "assets": [],
                "press": {"journalists": [{"id": f"presse-{i}", "name": "Camille Essai" if i == 0 else f"Reporter des Touches {i}"} for i in range(10)],
                          "outlets": [{"id": f"redaction-{i}", "name": "Le Courrier des Touches" if i == 0 else f"La Gazette des Essais {i}"} for i in range(4)]}}
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("pack.json", json.dumps(manifest, ensure_ascii=False))


def receive(args):
    if platform.system() != "Darwin":
        raise ValueError("Native macOS required")
    build = args.build.resolve()
    meta = json.loads((build / "build.json").read_text())
    package = build / meta["package"]
    assert digest(package) == meta["sha256"], "Package changed"
    evidence = build / "receipt"
    evidence.mkdir(exist_ok=False)
    if args.pack:
        if os.environ.get("GITHUB_ACTIONS") == "true":
            repo = os.environ["GITHUB_REPOSITORY"]
            private = subprocess.check_output(["gh", "api", f"repos/{repo}", "--jq", ".private"], text=True).strip()
            assert private == "true", "Real packs forbidden in public Actions"
        assert args.expected_pack_sha256 and digest(args.pack) == args.expected_pack_sha256, "Original ZIP hash required"
        pack = args.pack.resolve()
    else:
        pack = evidence / "Presse fictive — réception.zip"
        fictional_pack(pack)
    pack_sha = digest(pack)
    with zipfile.ZipFile(pack) as archive:
        expected_press = json.loads(archive.read("pack.json"))["press"]
    extracted = evidence / "extracted"
    subprocess.run(["ditto", "-x", "-k", str(package), str(extracted)], check=True)
    app = extracted / "Oval Legacy 27.app"
    assert {str(p.relative_to(app)): digest(p) for p in app.rglob("*") if p.is_file()} == meta["files"], "ZIP extraction preserves every shipped file"
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    executable = next((app / "Contents/MacOS").iterdir())
    subprocess.run(["lipo", "-verify_arch", "arm64" if meta["architecture"] == "arm64" else "x86_64", str(executable)], check=True)
    # Only the disposable copy gets a declared override; the downloadable ZIP
    # stays byte-identical. The same override is used for fresh and resumed runs.
    override = app / "Contents/Resources/override.cfg"
    assert not list(app.rglob("override.cfg"))
    override.write_text('[application]\nrun/main_loop_type="MacOSReceipt"\nrun/main_scene="res://macos_qa/entry.tscn"\n')
    subprocess.run(["codesign", "--force", "--deep", "--sign", "-", str(app)], check=True)
    env = dict(os.environ, CD_GODOT_DATA_DIR=str(evidence / "private-profile"),
               OVAL_MAC_RECEIPT=str(evidence), OVAL_MAC_PACK=str(pack), OVAL_MAC_FIXTURE="0" if args.pack else "1",
               OVAL_MAC_ARCH="arm64" if meta["architecture"] == "arm64" else "x86_64")
    env.pop("CD_MODES_HERITES", None)
    for phase in ("fresh", "resume"):
        env["OVAL_MAC_PHASE"] = phase
        with (evidence / (phase + ".log")).open("w") as log:
            subprocess.run(["/usr/bin/arch", "-" + env["OVAL_MAC_ARCH"], str(executable), "--max-fps", "10", "--windowed", "--resolution", "1440x900", "--audio-driver", "Dummy"],
                           env=env, cwd=app / "Contents/Resources", check=True, stdout=log, stderr=subprocess.STDOUT, timeout=900)
        report = json.loads((evidence / (phase + "-report.json")).read_text())
        assert report["passed"] and report["platform"] == "macOS" and report["display"] != "headless", "Native receipt required"
        print(json.dumps(report))
    assert digest(pack) == pack_sha, "Source pack must remain unchanged"
    assert digest(package) == meta["sha256"], "Delivery ZIP must remain unchanged"
    reports = [json.loads((evidence / (p + "-report.json")).read_text()) for p in ("fresh", "resume")]
    assert reports[0]["pid"] != reports[1]["pid"], "Independent application processes"
    people = {p["id"]: p for p in json.loads((evidence / "saved-press.json").read_text())}
    for journalist in expected_press["journalists"]:
        assert people[journalist["id"]]["name"] == journalist["name"], "Imported journalist projection differs"
    projected_outlets = {p["outlet"] for p in people.values()}
    assert all(o["name"] in projected_outlets for o in expected_press["outlets"]), "Imported outlet projection differs"
    (evidence / "receipt.json").write_text(json.dumps({"passed": True, "sourceCommit": meta["sourceCommit"], "architecture": meta["architecture"],
        "packageSha256": meta["sha256"], "packSha256": pack_sha, "packUnmodified": True, "fictional": not bool(args.pack),
        "qaOverrideSha256": digest(override), "reports": reports}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", type=Path, required=True)
    parser.add_argument("--pack", type=Path)
    parser.add_argument("--expected-pack-sha256")
    receive(parser.parse_args())
