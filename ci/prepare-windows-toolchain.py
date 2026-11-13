"""Prepare pinned free Windows tools. No installer, cache or system-wide changes.

Only a successful preparation publishes toolchain-receipt.json. This script
validates downloads and archive paths; execution of the exported game is a
separate Windows reception, never inferred from unit fixtures.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unicodedata
from urllib.request import Request, urlopen
from urllib.parse import urlsplit
import zipfile


def file_record(path, root):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return {"path": path.relative_to(root).as_posix(), "sha256": digest.hexdigest(), "bytes": path.stat().st_size}


def validate_pin(spec):
    url = urlsplit(spec.get("url", ""))
    if url.scheme != "https" or not url.hostname or url.username or url.password:
        raise ValueError("Pinned public HTTPS URL required")
    if not re.fullmatch(r"[0-9a-f]{64}", spec.get("sha256", "")):
        raise ValueError("Pinned SHA256 required")
    if type(spec.get("bytes")) is not int or not 0 < spec["bytes"] < 2 * 1024**3:
        raise ValueError("Pinned download size must be positive and below 2 GiB")
    if "sha512" in spec and not re.fullmatch(r"[0-9a-f]{128}", spec["sha512"]):
        raise ValueError("Invalid pinned SHA512")


def download_verified(spec, destination, opener=urlopen):
    validate_pin(spec)
    destination = Path(destination)
    if destination.exists():
        raise ValueError("Download destination already exists")
    destination.parent.mkdir(parents=True, exist_ok=True)
    sha256, sha512, size = hashlib.sha256(), hashlib.sha512(), 0
    descriptor, filename = tempfile.mkstemp(prefix=destination.name + "-", suffix=".part", dir=destination.parent)
    temporary = Path(filename)
    try:
        with os.fdopen(descriptor, "wb") as output:
            with opener(Request(spec["url"], headers={"User-Agent": "OvalLegacy-Windows-toolchain/1"}), timeout=60) as response:
                if getattr(response, "status", 200) != 200:
                    raise ValueError("Download did not return HTTP 200")
                while block := response.read(1024 * 1024):
                    size += len(block)
                    if size > spec["bytes"]:
                        raise ValueError("Download exceeds pinned size")
                    sha256.update(block)
                    sha512.update(block)
                    output.write(block)
        if size != spec["bytes"] or sha256.hexdigest() != spec["sha256"] or (
                "sha512" in spec and sha512.hexdigest() != spec["sha512"]):
            raise ValueError("Download size or checksum differs from pin")
        temporary.rename(destination)
    finally:
        temporary.unlink(missing_ok=True)
    return destination


def relative_name(name):
    if not isinstance(name, str) or not name or "\x00" in name:
        raise ValueError("Empty or invalid archive path")
    name = name.replace("\\", "/")
    if name.startswith("/"):
        raise ValueError("Absolute archive path")
    parts = name.rstrip("/").split("/")
    reserved = {"CON", "PRN", "AUX", "NUL", *("COM" + str(i) for i in range(1, 10)), *("LPT" + str(i) for i in range(1, 10))}
    for part in parts:
        if part in ("", ".", "..") or part[-1:] in (".", " ") or any(ord(c) < 32 or c in '<>:"|?*' for c in part):
            raise ValueError("Unsafe Windows archive path: " + name)
        if part.split(".")[0].upper() in reserved:
            raise ValueError("Reserved Windows archive path: " + name)
    return "/".join(parts)


def validate_entries(entries):
    names, files = {}, set()
    for row in entries:
        name = relative_name(row["path"])
        key = unicodedata.normalize("NFC", name).casefold()
        if key in names:
            raise ValueError("Duplicate Windows archive path: " + name)
        names[key] = name
        if row.get("link") or row.get("encrypted"):
            raise ValueError("Archive links and encrypted entries are forbidden")
        if not row.get("directory"):
            if type(row.get("size")) is not int or not 0 <= row["size"] < 2 * 1024**3:
                raise ValueError("Invalid archive member size")
            files.add(key)
        row["path"] = name
    for key in names:
        if any(parent.as_posix() in files for parent in PurePosixPath(key).parents if parent.as_posix() != "."):
            raise ValueError("Archive file is also a parent directory")
    return entries


def extract_zip_members(archive, destination, members):
    destination = Path(destination)
    if destination.exists():
        raise ValueError("Extraction destination already exists")
    mapping = {relative_name(source): relative_name(target) for source, target in members.items()}
    validate_entries([{"path": target, "size": 0} for target in mapping.values()])
    with zipfile.ZipFile(archive) as source:
        rows = []
        for info in source.infolist():
            mode = (info.external_attr >> 16) & 0xFFFF
            kind = stat.S_IFMT(mode)
            rows.append({"path": info.filename, "size": info.file_size, "directory": info.is_dir(),
                         "link": kind not in (0, stat.S_IFREG, stat.S_IFDIR), "encrypted": bool(info.flag_bits & 1), "info": info})
        validate_entries(rows)
        available = {row["path"]: row for row in rows if not row.get("directory")}
        if not mapping.keys() <= available.keys():
            raise ValueError("Required archive member missing: " + str(mapping.keys() - available.keys()))
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = Path(tempfile.mkdtemp(prefix="extract-", dir=destination.parent))
        try:
            for name, target in mapping.items():
                output = temporary / target
                output.parent.mkdir(parents=True, exist_ok=True)
                with source.open(available[name]["info"]) as incoming, output.open("xb") as outgoing:
                    shutil.copyfileobj(incoming, outgoing)
                if output.stat().st_size != available[name]["size"]:
                    raise ValueError("Extracted member size mismatch")
            temporary.rename(destination)
        finally:
            if temporary.exists():
                shutil.rmtree(temporary)


def parse_sevenzip_listing(text):
    rows = []
    for block in re.split(r"\r?\n\s*\r?\n", text.strip()):
        fields = dict(line.split(" = ", 1) for line in block.splitlines() if " = " in line)
        if not fields:
            continue
        if "Path" not in fields or "Size" not in fields:
            raise ValueError("Incomplete 7-Zip listing")
        attributes = fields.get("Attributes", "")
        links = any(fields.get(key) for key in ("Symbolic Link", "Hard Link", "Reparse Point"))
        links = links or bool(re.search(r"(^|[ _])l[rwx-]{9}", attributes)) or "L" in attributes.split(" ")[0]
        links = links or fields.get("Mode", "").startswith("l") or fields.get("Anti") == "+"
        rows.append({"path": fields["Path"], "size": int(fields["Size"]),
                     "directory": fields.get("Folder") == "+" or attributes.startswith("D"),
                     "link": links, "encrypted": fields.get("Encrypted") == "+"})
    if not rows:
        raise ValueError("Empty 7-Zip listing")
    return validate_entries(rows)


def extract_sevenzip(archive, destination, executable):
    destination = Path(destination)
    if destination.exists():
        raise ValueError("Extraction destination already exists")
    listing = subprocess.check_output([str(executable), "l", "-slt", "-ba", "-sccUTF-8", str(archive)], encoding="utf-8", timeout=120)
    rows = parse_sevenzip_listing(listing)
    if sum(row["size"] for row in rows) > 4 * 1024**3:
        raise ValueError("Mesa extraction exceeds 4 GiB")
    destination.mkdir(parents=True)
    subprocess.run([str(executable), "x", "-y", "-sccUTF-8", "-o" + str(destination), str(archive)], check=True, timeout=180, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    actual = {}
    for path in destination.rglob("*"):
        if path.is_symlink() or getattr(path.lstat(), "st_file_attributes", 0) & 0x400:
            raise ValueError("Extracted link/reparse point refused")
        if path.is_file():
            actual[path.relative_to(destination).as_posix()] = path.stat().st_size
    expected = {row["path"]: row["size"] for row in rows if not row["directory"]}
    if actual != expected:
        raise ValueError("Extracted Mesa tree differs from inspected archive")
    return rows


def verify_node_notice_set(notices, version, runtime_sha):
    notices = Path(notices)
    license_path = notices / ("Node-v" + version + "-LICENSE.txt")
    sums_path = notices / ("Node-v" + version + "-SHASUMS256.txt")
    if not license_path.is_file() or not license_path.stat().st_size or not sums_path.is_file():
        raise ValueError("Exact Node version notices required")
    hashes = re.findall(r"^([a-fA-F0-9]{64})[ \t]+\*?win-x64/node\.exe[ \t]*$", sums_path.read_text(encoding="ascii"), re.MULTILINE)
    if [value.lower() for value in hashes] != [runtime_sha]:
        raise ValueError("Node runtime is incompatible with its official checksum notice")


def inspect_mesa_notices(root):
    root = Path(root)
    records, texts = [], []
    for path in sorted(root.rglob("*")):
        if path.is_file() and path.stat().st_size <= 2 * 1024**2 and any(word in path.name.lower() for word in ("license", "licence", "copying", "copyright")):
            text = path.read_text(encoding="utf-8", errors="replace")
            if text.strip():
                records.append(file_record(path, root))
                texts.append(text.lower())
    # The pinned binary archive has only a readme. Genuine component texts are
    # fetched separately from the corresponding immutable upstream snapshots.
    # The packager MIT alone remains insufficient. Mesa's current licensing page
    # points at its SPDX license directory instead of inlining the MIT text.
    mesa = any("mesa" in text and "permission" in text and len(text) > 150 for text in texts) or (
        any("core mesa library is licensed" in text and "mit" in text for text in texts) and
        any("valid-license-identifier: mit" in text and "permission is hereby granted" in text for text in texts))
    llvm = any("llvm" in text and any(term in text for term in ("apache", "ncsa", "permission")) and len(text) > 150 for text in texts)
    if not mesa or not llvm:
        raise ValueError("Mesa QA tools require inspectable Mesa and LLVM component notices, not only the packager MIT")
    return records


def write_mesa_receipt(root, version, archive_pin, notice_sources=None):
    root = Path(root)
    required = ["x64/opengl32.dll", "x64/libgallium_wgl.dll"]
    for relative in required:
        if not (root / relative).is_file():
            raise ValueError("Required Mesa x64 DLL missing: " + relative)
    licenses = inspect_mesa_notices(root)
    files = {}
    for path in sorted((root / "x64").rglob("*")):
        if path.is_file() and path.suffix.lower() == ".dll":
            record = file_record(path, root)
            files[record.pop("path")] = record
    receipt = {"schemaVersion": 1, "version": version, "source": archive_pin,
               "qaOnly": True, "environment": {"GALLIUM_DRIVER": "llvmpipe"},
               "requiredDlls": required, "files": files, "licenses": licenses}
    receipt["componentNoticeSources"] = notice_sources or []
    (root / "mesa-receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    return receipt


def find_sevenzip():
    found = shutil.which("7z") or shutil.which("7z.exe")
    candidates = [Path(found)] if found else []
    candidates += [Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "7-Zip/7z.exe"]
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    raise ValueError("Standard Windows runner 7-Zip is required to inspect the pinned Mesa .7z; no installer was run")


def prepare_mesa(root, mesa, acquire, pins):
    sevenzip = find_sevenzip()
    mesa_root = root / "mesa"
    extract_sevenzip(acquire("mesa-archive", mesa["archive"]), mesa_root, sevenzip)
    for index, spec in enumerate(mesa["notices"] + [mesa["documentation"]]):
        destination = relative_name(spec["destination"])
        if not destination.startswith("qa-notices/"):
            raise ValueError("Mesa notice must be placed in qa-notices/")
        target = mesa_root / destination
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            raise ValueError("Mesa notice destination already exists")
        shutil.copyfile(acquire("mesa-notice-" + str(index), spec), target)
    mesa_receipt = write_mesa_receipt(mesa_root, mesa["version"], pins["mesa-archive"],
                                     [spec for spec in mesa["notices"] if spec.get("component")])
    return {"mesaRoot": str(mesa_root), "mesaQaOnly": True, "mesaComponentNotices": mesa_receipt["licenses"],
            "sevenZip": {"executable": str(sevenzip), **file_record(sevenzip, sevenzip.parent)}}


def prepare(root, config_path, opener=urlopen, *, hardware=False):
    config_path = Path(config_path).resolve()
    config_bytes = config_path.read_bytes()
    config = json.loads(config_bytes)
    if config.get("schemaVersion") != 1:
        raise ValueError("Unknown Windows toolchain schema")
    root = Path(root).resolve()
    if root.exists():
        raise ValueError("Choose a new toolchain root; existing tools are never overwritten")
    root.mkdir(parents=True)
    downloads, sdk = root / "downloads", root / "sdk"
    downloads.mkdir()
    pins = {}
    def acquire(label, spec):
        print("Verifying pinned toolchain input: " + label, file=sys.stderr, flush=True)
        path = download_verified(spec, downloads / (label + Path(urlsplit(spec["url"]).path).suffix), opener=opener)
        pins[label] = {key: spec[key] for key in ("url", "sha256", "bytes", "sha512") if key in spec}
        return path
    godot, node = config["godot"], config["node"]
    editor = acquire("godot-editor", godot["editor"])
    templates = acquire("godot-templates", godot["templates"])
    sums = acquire("godot-sums", godot["checksumManifest"])
    official = {}
    for line in sums.read_text(encoding="ascii").splitlines():
        parts = line.split()
        if len(parts) == 2:
            official[parts[1]] = parts[0]
    for spec in (godot["editor"], godot["templates"]):
        if official.get(Path(urlsplit(spec["url"]).path).name) != spec["sha512"]:
            raise ValueError("Godot archive does not match its pinned official SHA512 manifest")
    node_path = root / "runtime/node.exe"
    node_path.parent.mkdir()
    shutil.copyfile(acquire("node-runtime", node["runtime"]), node_path)
    notices = godot["notices"] + [godot["checksumManifest"]] + node["notices"]
    for index, spec in enumerate(notices):
        # Notice destinations from config are constrained to the SDK licences.
        destination = relative_name(spec["destination"])
        if not destination.startswith("licenses/"):
            raise ValueError("SDK notice must be placed in licenses/")
        target = sdk / destination
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(acquire("notice-" + str(index), spec), target)
    verify_node_notice_set(sdk / "licenses", node["version"], node["runtime"]["sha256"])
    version = godot["version"]
    name = "Godot_v" + version + "_win64"
    extract_zip_members(editor, sdk / "editor" / version, {name + ".exe": name + ".exe", name + "_console.exe": name + "_console.exe"})
    extract_zip_members(templates, sdk / "templates" / version, {"templates/windows_release_x86_64.exe": "windows_release_x86_64.exe"})
    notice_dirs = [sdk / "licenses"]
    mesa_data = {"mesaQaOnly": False}
    if not hardware:
        mesa_data = prepare_mesa(root, config["mesaQaOnly"], acquire, pins)
        notice_dirs.append(Path(mesa_data["mesaRoot"]) / "qa-notices")
    receipt = {"schemaVersion": 1, "sdkRoot": str(sdk), "nodeExe": str(node_path), "nodeNotices": str(sdk / "licenses"),
               "configSha256": hashlib.sha256(config_bytes).hexdigest(), "pins": pins,
               "notices": [file_record(path, root) for directory in notice_dirs for path in sorted(directory.rglob("*")) if path.is_file()],
               "limits": ["Tools prepared and hashes verified; not a Windows game reception"], **mesa_data}
    if not hardware:
        receipt["limits"].append("Mesa is QA-only, never part of the delivered game ZIP")
    (root / "toolchain-receipt.json").write_text(json.dumps(receipt, indent=2), encoding="utf-8")
    return receipt


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--hardware", action="store_true", help="prepare the pinned Godot and Node tools without Mesa")
    arguments = parser.parse_args()
    try:
        result = prepare(arguments.root, arguments.config, hardware=arguments.hardware)
    except (ValueError, OSError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        parser.exit(1, str(error) + "\n")
    print(json.dumps(result, indent=2))
