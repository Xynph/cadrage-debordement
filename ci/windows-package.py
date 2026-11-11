"""Strict verification for the official Windows archive and native QA evidence.

No downloads, game emulation or fallback runtime. Unit fixtures validate this
module's rejection paths; only the Windows receipt driver supplies native proof.
"""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import ntpath
import os
import platform
import re
import shutil
import stat
import struct
import unicodedata
import zipfile
import zlib

APP = "OvalLegacy27-PrototypeGodot"
SHA = re.compile(r"[0-9a-f]{64}\Z")
COMMIT = re.compile(r"[0-9a-f]{40}\Z")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def json_document(text):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, "Duplicate JSON key: " + key)
            result[key] = value
        return result
    return json.loads(text, object_pairs_hook=unique)


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def safe_name(name):
    require(isinstance(name, str) and name and "\\" not in name, "Unsafe Windows archive path")
    parts = name.split("/")
    require(not name.startswith("/") and all(parts), "Unsafe absolute or empty path")
    for part in parts:
        require(part not in (".", "..") and part == part.rstrip(". "), "Unsafe traversal or Windows suffix")
        require(not re.search(r'[<>:"|?*\x00-\x1f]', part), "Unsafe Windows path character")
        require(not re.fullmatch(r"(?i:CON|PRN|AUX|NUL|COM[1-9¹²³]|LPT[1-9¹²³])(?:\..*)?", part), "Reserved Windows path")
    return unicodedata.normalize("NFC", name).casefold()


def manifest_files(manifest):
    require(isinstance(manifest, dict) and COMMIT.fullmatch(str(manifest.get("sourceCommit", ""))) and
            COMMIT.fullmatch(str(manifest.get("sourceTree", ""))), "Missing or invalid source provenance")
    files = manifest.get("files")
    require(isinstance(files, dict) and files, "Exhaustive manifest files required")
    keys = set()
    for name, row in files.items():
        key = safe_name(name)
        require(key not in keys and key != "manifest-build.json", "Duplicate or self-referential manifest")
        keys.add(key)
        require(isinstance(row, dict) and SHA.fullmatch(str(row.get("sha256", ""))) and
                type(row.get("bytes")) is int and row["bytes"] >= 0, "Invalid manifest SHA or size")
    for mandatory in ("OvalLegacy27.exe", "runtime/node.exe", "engine/worker.cjs"):
        require(mandatory in files, "Required packaged executable/runtime absent")
    return files


def verify_archive(zip_path, expected_commit):
    require(COMMIT.fullmatch(str(expected_commit)), "Full lowercase source commit required")
    with zipfile.ZipFile(zip_path) as archive:
        names, contents, directories = set(), {}, set()
        total = 0
        for member in archive.infolist():
            name = member.filename[:-1] if member.is_dir() else member.filename
            key = safe_name(name)
            require(key not in names, "Duplicate Windows archive member")
            names.add(key)
            mode = member.external_attr >> 16
            require(stat.S_IFMT(mode) in (0, stat.S_IFREG, stat.S_IFDIR) and
                    not member.external_attr & 0x400, "Archive link or special file refused")
            require(not member.flag_bits & 1, "Encrypted archive refused")
            require(name == APP or name.startswith(APP + "/"), "Unexpected archive root")
            total += member.file_size
            require(total <= 2 * 1024**3 and member.file_size <= 512 * 1024**2, "Archive size limit exceeded")
            if member.is_dir():
                directories.add(name)
            else:
                contents[name] = archive.read(member)
        manifest_name = APP + "/manifest-build.json"
        require(manifest_name in contents, "Build manifest missing")
        manifest = json_document(contents[manifest_name].decode("utf-8-sig"))
        files = manifest_files(manifest)
        require(manifest["sourceCommit"] == expected_commit, "Wrong source commit")
        expected = {APP + "/" + name for name in files} | {manifest_name}
        require(set(contents) == expected, "Manifest omission or unexpected archive file")
        require(all(any(p.startswith(d + "/") for p in expected) for d in directories), "Unexpected empty archive directory")
        for name, row in files.items():
            data = contents[APP + "/" + name]
            require(len(data) == row["bytes"] and hashlib.sha256(data).hexdigest() == row["sha256"], "Manifest SHA/size mismatch: " + name)
        return {"manifest": manifest, "files": len(files), "root": APP,
                "zipSha256": digest(zip_path), "manifestSha256": hashlib.sha256(contents[manifest_name]).hexdigest()}


def extract_archive(zip_path, destination, expected_commit):
    verify_archive(zip_path, expected_commit)
    destination = Path(destination)
    require(not destination.exists(), "Refuse an existing extraction destination")
    destination.mkdir(parents=True)
    with zipfile.ZipFile(zip_path) as archive:
        for member in archive.infolist():
            target = destination.joinpath(*PurePosixPath(member.filename).parts)
            if member.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with target.open("xb") as stream:
                    stream.write(archive.read(member))
    return destination / APP


def verify_tree(root, manifest, allowed_extras):
    require(not Path(root).is_symlink(), "Tree root link refused")
    root = Path(root).resolve()
    files = manifest_files(manifest)
    require(isinstance(allowed_extras, dict), "Explicit QA extras mapping required")
    expected = dict(files)
    canonical = {safe_name(p) for p in files} | {"manifest-build.json"}
    for name, row in allowed_extras.items():
        key = safe_name(name)
        require(key not in canonical, "QA extra cannot overwrite manifest file")
        canonical.add(key)
        require(isinstance(row, dict) and SHA.fullmatch(str(row.get("sha256", ""))) and type(row.get("bytes")) is int, "QA extra hash/size required")
        expected[name] = row
    found, folded = set(), set()
    for path in root.rglob("*"):
        require(not path.is_symlink() and not getattr(path.lstat(), "st_file_attributes", 0) & 0x400, "Tree link refused")
        if path.is_dir():
            continue
        name = path.relative_to(root).as_posix()
        key = safe_name(name)
        require(key not in folded, "Duplicate Windows tree file")
        folded.add(key); found.add(name)
    require(found == set(expected) | {"manifest-build.json"}, "Unexpected or missing game tree file")
    require(json_document((root / "manifest-build.json").read_text(encoding="utf-8-sig")) == manifest, "Build manifest changed")
    for name, row in expected.items():
        path = root / name
        require(digest(path) == row["sha256"] and path.stat().st_size == row["bytes"], "Tree SHA/size mismatch: " + name)
    return {"files": len(files), "manifestSha256": digest(root / "manifest-build.json"), "extras": allowed_extras, "unchanged": True}


def install_mesa(mesa_root, game_root, manifest):
    mesa_root, game_root = Path(mesa_root), Path(game_root)
    receipt = json_document((mesa_root / "mesa-receipt.json").read_text(encoding="utf-8-sig"))
    require(receipt.get("qaOnly") is True and receipt.get("version") == "26.2.6", "Pinned QA-only Mesa receipt required")
    require(SHA.fullmatch(str(receipt.get("source", {}).get("sha256", ""))), "Mesa source SHA missing")
    require(receipt.get("licenses") and receipt.get("requiredDlls"), "Inspectable Mesa/LLVM notices required")
    for row in receipt["licenses"]:
        safe_name(row["path"])
        path = mesa_root / row["path"]
        require(path.is_file() and not path.is_symlink() and path.stat().st_size == row["bytes"] > 0 and digest(path) == row["sha256"], "Mesa license SHA/size mismatch")
    files = receipt.get("files", {})
    require(all(name in files for name in receipt["requiredDlls"]), "Required Mesa DLL missing")
    occupied = {safe_name(name) for name in manifest_files(manifest)} | {"manifest-build.json"}
    extras, staged = {}, []
    for name, row in files.items():
        safe_name(name)
        require(name.startswith("x64/") and name.lower().endswith(".dll"), "Only declared Mesa x64 DLLs may enter QA copy")
        relative = name[len("x64/"):]; key = safe_name(relative)
        require(key not in occupied and not (game_root / relative).exists(), "Mesa cannot overwrite a game file")
        occupied.add(key)
        path = mesa_root / name
        require(path.is_file() and not path.is_symlink() and path.stat().st_size == row["bytes"] and digest(path) == row["sha256"], "Mesa DLL SHA/size mismatch")
        extras[relative] = {"sha256": row["sha256"], "bytes": row["bytes"], "source": name}
        staged.append((path, game_root / relative))
    for source, destination in staged:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
    return {"extras": extras, "receipt": receipt, "receiptSha256": digest(mesa_root / "mesa-receipt.json")}


def same_windows_path(left, right):
    return bool(left and right) and ntpath.normcase(ntpath.normpath(str(left))) == ntpath.normcase(ntpath.normpath(str(right)))


def validate_qa_report(report, expected_executable, expected_mode):
    require(expected_mode in ("fresh", "resume") and report.get("mode") == expected_mode, "Wrong QA mode")
    require(report.get("passed") is True and report.get("failures") == [] and type(report.get("checks")) is int and report["checks"] > 0, "QA failed or omitted checks")
    require(same_windows_path(report.get("executable"), expected_executable), "Wrong QA executable")
    require(ntpath.isabs(str(report.get("data_dir", ""))) and report.get("season", 0) >= 2, "QA profile or season two missing")
    require(type(report.get("pid")) is int and report["pid"] > 0 and type(report.get("engine_pid")) is int and report["engine_pid"] > 0, "QA process identity missing")
    coach = report.get("coach", {})
    require(coach.get("starts") == 0 and coach.get("ends") == 0 and coach.get("voice_available") is False and coach.get("player_present") is False, "Guide audio must remain unallocated and silent")
    if expected_mode == "fresh":
        require(report.get("native_display") == "headless", "Fresh headless receipt required")
        journey = report.get("journey", {})
        for key, minimum in (("day_advances", 182), ("matches_started", 26), ("matches_finished", 26), ("weeks_closed", 26), ("meeting_commands", 1)):
            require(type(journey.get(key)) is int and journey[key] >= minimum, "Full-season journey evidence missing: " + key)
        require(journey.get("interseason_reached") is True and journey.get("season_two_reached") is True, "Actual season transition evidence required")
        require(report.get("systems", {}).get("passed") is True and report.get("native06", {}).get("passed") is True, "Integrated systems and UI receipt required")
        literals = report.get("press_literals", [])
        require(isinstance(literals, list) and len(literals) >= 2, "Nonempty selected literal press statements required")
        for row in literals:
            expected, archived = row.get("expected", {}), row.get("archived", {})
            require(expected == archived and set(expected) == {"id", "season", "week", "club", "answerId", "questionText", "answerText", "journalist"}, "Selected press statement differs from its literal archive")
            require(all(isinstance(expected.get(k), str) and expected[k].strip() for k in ("id", "answerId", "questionText", "answerText")), "Empty selected press text refused")
            journalist = expected.get("journalist", {})
            require(set(journalist) == {"id", "name", "outlet"} and all(isinstance(v, str) and v.strip() for v in journalist.values()), "Selected journalist identity required")
    else:
        graphics = report.get("graphics", {})
        require(report.get("native_display") == "Windows" and graphics.get("passed") is True and graphics.get("window") == [2560, 1440], "Real Windows graphics receipt required")
        require(report.get("platform") == "Windows" and report.get("audio_driver") == "Dummy", "Windows/Dummy runtime required")
        before = report.get("before", {})
        require(all(before.get(k) is True for k in ("state_matches", "citations_match", "rng_file_unchanged", "profile_bytes_match", "press_literals_match")), "Pure initial resume proof missing")
        probe = report.get("save_probe", {})
        mutations = report.get("first_mutations", [])
        require(probe.get("state_matches") is True and probe.get("rng_matches_loaded") is True and
                probe.get("seed_saved") == before.get("seed_loaded") and mutations and mutations[0].get("command") == "save", "Declared runtime RNG save probe missing or changed")
        require(report.get("runtime_info") and len(graphics.get("captures", [])) >= 4, "Runtime information and real captures required")
    return report


def validate_process(record, expected_executable, expected_node, expected_node_sha):
    require(same_windows_path(record.get("executable"), expected_executable), "Wrong launched executable")
    require(same_windows_path(record.get("nodeExecutable"), expected_node), "Packaged Node process required")
    require(record.get("nodeSha256") == expected_node_sha and SHA.fullmatch(str(expected_node_sha)), "Wrong Node SHA")
    require(type(record.get("pid")) is int and record["pid"] > 0 and record.get("nodeParentPid") == record["pid"] and record.get("nodePid", 0) > 0, "Wrong Node parent/process")
    require(record.get("exitCode") == 0 and record.get("shutdown") is True, "Process failure or child still running")
    return record


def png_proof(path):
    # Decode non-interlaced 8-bit RGB/RGBA PNGs emitted by Godot. No Pillow needed.
    data = Path(path).read_bytes(); require(data[:8] == b"\x89PNG\r\n\x1a\n", "PNG required")
    offset, compressed, header = 8, bytearray(), None
    while offset < len(data):
        require(offset + 12 <= len(data), "Truncated PNG")
        length = struct.unpack(">I", data[offset:offset+4])[0]; kind = data[offset+4:offset+8]
        block = data[offset+8:offset+8+length]
        require(len(block) == length and offset + length + 12 <= len(data), "Truncated PNG chunk")
        require(zlib.crc32(kind + block) & 0xffffffff == struct.unpack(">I", data[offset+8+length:offset+12+length])[0], "PNG CRC mismatch")
        if kind == b"IHDR": header = struct.unpack(">IIBBBBB", block)
        if kind == b"IDAT": compressed.extend(block)
        offset += length + 12
        if kind == b"IEND": break
    require(header is not None, "PNG dimensions missing")
    width, height, depth, color, compression, filtering, interlace = header
    require((width, height) == (2560, 1440) and depth == 8 and color in (2, 6) and compression == filtering == interlace == 0, "Native 2560x1440 RGB PNG required")
    bpp = 3 if color == 2 else 4; stride = width * bpp
    decoder = zlib.decompressobj()
    raw = decoder.decompress(compressed, (stride + 1) * height + 1)
    require(decoder.eof and not decoder.unused_data, "PNG compressed pixels exceed expected image")
    require(len(raw) == (stride + 1) * height, "PNG pixel count mismatch")
    prior = bytearray(stride); samples = []
    for y in range(height):
        row = bytearray(raw[y*(stride+1)+1:(y+1)*(stride+1)]); mode = raw[y*(stride+1)]
        require(mode <= 4, "Unsupported PNG filter")
        for x in range(stride):
            a = row[x-bpp] if x >= bpp else 0; b = prior[x]; c = prior[x-bpp] if x >= bpp else 0
            if mode == 1: predictor = a
            elif mode == 2: predictor = b
            elif mode == 3: predictor = (a+b)//2
            elif mode == 4:
                p = a+b-c; distances = (abs(p-a), abs(p-b), abs(p-c)); predictor = (a,b,c)[distances.index(min(distances))]
            else: predictor = 0
            row[x] = (row[x]+predictor) & 255
        if y % 17 == 0:
            for x in range(0, width, 19): samples.append(sum(row[x*bpp:x*bpp+3])/3)
        prior = row
    mean = sum(samples)/len(samples); variance = sum((v-mean)**2 for v in samples)/len(samples)
    require(variance > 2, "Blank or near-uniform capture refused")
    return {"path": str(Path(path).resolve()), "sha256": digest(path), "width": width, "height": height, "variance": variance}


def validate_windows_report(report, expected_commit, expected_executable, require_native=True):
    if require_native:
        require(platform.system() == "Windows" and report.get("platform") == "Windows" and report.get("proof") == "native-windows", "A diagnostic or non-Windows host is not native Windows proof")
    require(report.get("sourceCommit") == expected_commit and COMMIT.fullmatch(str(report.get("sourceTree", ""))), "Wrong report source provenance")
    package = report["package"]
    receipt = verify_archive(package["path"], expected_commit)
    require(receipt["manifest"]["sourceTree"] == report["sourceTree"] and receipt["zipSha256"] == package["shaBefore"] == package["shaAfter"], "Package source/SHA changed")
    require(receipt["manifestSha256"] == package["manifestSha256"], "Wrong manifest SHA")
    root = Path(expected_executable).parent
    verify_tree(root, receipt["manifest"], report.get("qaExtras", {}))
    require(digest(root / "manifest-build.json") == receipt["manifestSha256"], "Game manifest bytes changed")
    require(report.get("manifestBefore") == report.get("manifestAfter") and report.get("manifestAfter", {}).get("unchanged") is True, "Before/after game file proof missing")
    node = root / "runtime/node.exe"; node_sha = receipt["manifest"]["files"]["runtime/node.exe"]["sha256"]
    pins = report.get("tools", {}).get("receipt", {}).get("pins", {})
    require(pins.get("node-runtime", {}).get("sha256") == node_sha, "Node differs from prepared runtime pin")
    require(report.get("mesa", {}).get("receipt", {}).get("source", {}).get("sha256") == pins.get("mesa-archive", {}).get("sha256"), "Mesa differs from prepared archive pin")
    for mode in ("fresh", "resume"):
        qa = report[mode]
        validate_qa_report(qa, expected_executable, mode)
        process = report["process"][mode]
        validate_process(process, expected_executable, node, node_sha)
        require(process.get("exeSha256") == receipt["manifest"]["files"]["OvalLegacy27.exe"]["sha256"], "Wrong EXE SHA in process receipt")
        require(qa["pid"] == process["pid"] and qa["engine_pid"] == process["nodePid"], "QA/process PID mismatch")
    require(same_windows_path(report["fresh"]["data_dir"], report["resume"]["data_dir"]), "Resume must use the same persisted profile")
    version = report["resume"]["runtime_info"].get("engine", {})
    require([version.get(key) for key in ("major", "minor", "patch")] == [4, 7, 2], "Wrong observed Godot runtime version")
    captures = report["resume"]["graphics"]["captures"]
    checked = []
    for row in captures:
        actual = png_proof(row["path"])
        require(actual["sha256"] == row["sha256"], "Capture SHA changed")
        checked.append(actual)
    require(any("runtime-info" in Path(row["path"]).name for row in checked), "Runtime info capture missing")
    report["graphics"] = {"passed": True, "captures": checked, "window": [2560, 1440]}
    report["audio"] = {"driver": "Dummy", "starts": 0, "ends": 0, "player_present": False}
    if not require_native:
        report["proof"] = "diagnostic"
        report["passed"] = False
    return report


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    unpack = sub.add_parser("extract"); unpack.add_argument("--zip", required=True); unpack.add_argument("--source-commit", required=True); unpack.add_argument("--source-tree", required=True); unpack.add_argument("--destination", required=True); unpack.add_argument("--receipt", required=True)
    tree = sub.add_parser("tree"); tree.add_argument("--root", required=True); tree.add_argument("--manifest", required=True); tree.add_argument("--extras", required=True); tree.add_argument("--output", required=True)
    mesa = sub.add_parser("mesa"); mesa.add_argument("--mesa-root", required=True); mesa.add_argument("--game-root", required=True); mesa.add_argument("--manifest", required=True); mesa.add_argument("--output", required=True)
    finish = sub.add_parser("finalize"); finish.add_argument("--report", required=True); finish.add_argument("--source-commit", required=True); finish.add_argument("--executable", required=True)
    args = parser.parse_args()
    if args.command == "extract":
        result = verify_archive(args.zip, args.source_commit)
        require(result["manifest"]["sourceTree"] == args.source_tree, "Wrong Git source tree")
        result["gameRoot"] = str(extract_archive(args.zip, args.destination, args.source_commit).resolve())
        Path(args.receipt).write_text(json.dumps(result, indent=2), encoding="utf-8")
    elif args.command == "tree":
        result = verify_tree(args.root, json_document(Path(args.manifest).read_text(encoding="utf-8-sig")), json_document(Path(args.extras).read_text(encoding="utf-8-sig")))
        Path(args.output).write_text(json.dumps(result, indent=2), encoding="utf-8")
    elif args.command == "mesa":
        result = install_mesa(args.mesa_root, args.game_root, json_document(Path(args.manifest).read_text(encoding="utf-8-sig")))
        Path(args.output).write_text(json.dumps(result, indent=2), encoding="utf-8")
    else:
        report = json_document(Path(args.report).read_text(encoding="utf-8-sig"))
        validate_windows_report(report, args.source_commit, args.executable)
        report["passed"] = True
        Path(args.report).write_text(json.dumps(report, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
