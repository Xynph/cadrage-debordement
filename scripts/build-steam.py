"""Produit le dossier Steam de Rugby Legacy 27, prêt à téléverser (sans jamais téléverser).

Reprend l'export Windows vérifié de build-godot-prototype.py avec le réglage dédié
native/godot/steam-release.cfg, puis prépare :
  <sortie>/steam/content/   contenu du dépôt Steam (exécutable, runtime, moteur, licences)
  <sortie>/steam/scripts/   app_build.vdf et depot_build_windows.vdf remplis depuis tools/steam/
  <sortie>/steam/TELEVERSER.txt   commande steamcmd à lancer soi-même

Aucun identifiant n'est lu, écrit ni demandé : App ID et Depot ID viennent de
CD_STEAM_APP_ID / CD_STEAM_DEPOT_ID (sinon « A_RENSEIGNER »). La signature de
l'exécutable est facultative (CD_SIGN_CERT_SHA1 = empreinte d'un certificat de
signature de code déjà installé dans le magasin Windows de l'utilisateur).
Aucun accès réseau, sauf l'horodatage de signature quand un certificat est fourni.
"""
from pathlib import Path
import argparse
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "native/godot"
TEMPLATES = ROOT / "tools/steam"
PLACEHOLDER = "A_RENSEIGNER"
FORBIDDEN = ("steam_appid.txt", "override.cfg")


def prototype_module():
    spec = importlib.util.spec_from_file_location("build_godot_prototype", ROOT / "scripts/build-godot-prototype.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def steam_settings():
    settings = json.loads((PROJECT / "steam/steam.json").read_text(encoding="utf-8-sig"))
    assert settings.get("schema") == "rl27-steam-v1", "steam.json : schéma inattendu"
    if settings.get("enabled"):
        if int(settings.get("app_id", 0)) <= 0:
            raise ValueError("steam.json : enabled=true exige un app_id")
        if not (PROJECT / "addons/godotsteam/godotsteam.gdextension").is_file():
            raise ValueError("steam.json : enabled=true exige GodotSteam dans native/godot/addons/godotsteam")
    return settings


def publisher_values(warnings):
    credits = json.loads((PROJECT / "legal/credits.json").read_text(encoding="utf-8-sig"))
    editeur = credits.get("editeur", {})
    company = str(editeur.get("nom", "")).strip()
    if not company:
        warnings.append("Éditeur non renseigné dans native/godot/legal/credits.json (nom, adresse, contact).")
        company = "Rugby Legacy 27"
    return {"COMPANY": company, "COPYRIGHT": f"© 2026 {company}"}


def steam_id(name, warnings):
    value = os.environ.get(name, "").strip()
    if not value:
        warnings.append(f"{name} absent : les scripts steamcmd gardent {PLACEHOLDER}.")
        return PLACEHOLDER
    if not re.fullmatch(r"[1-9][0-9]{0,9}", value):
        raise ValueError(f"{name} doit être un identifiant numérique Steam")
    return value


def find_signtool():
    explicit = os.environ.get("CD_SIGNTOOL")
    if explicit:
        return Path(explicit)
    kits = Path(r"C:\Program Files (x86)\Windows Kits\10\bin")
    candidates = sorted(kits.glob("10.*/x64/signtool.exe")) if kits.is_dir() else []
    return candidates[-1] if candidates else None


def sign(executable, thumbprint):
    signtool = find_signtool()
    if signtool is None or not signtool.is_file():
        raise ValueError("signtool.exe introuvable (installer le SDK Windows ou définir CD_SIGNTOOL)")
    if not re.fullmatch(r"[0-9A-Fa-f]{40}", thumbprint):
        raise ValueError("CD_SIGN_CERT_SHA1 doit être l'empreinte SHA-1 (40 caractères) du certificat")
    timestamp = os.environ.get("CD_SIGN_TIMESTAMP_URL", "http://timestamp.digicert.com")
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    subprocess.run([str(signtool), "sign", "/sha1", thumbprint, "/fd", "SHA256", "/tr", timestamp, "/td", "SHA256",
                    "/d", "Rugby Legacy 27", str(executable)], check=True, creationflags=flags)
    subprocess.run([str(signtool), "verify", "/pa", str(executable)], check=True, creationflags=flags)


def refresh_manifest_entry(content, relative, module):
    manifest_path = content / "manifest-build.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    path = content / relative
    manifest["files"][relative] = {"sha256": module.digest(path), "bytes": path.stat().st_size}
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")


def fill_template(name, values):
    text = (TEMPLATES / name).read_text(encoding="utf-8")
    for key, value in values.items():
        text = text.replace("{{" + key + "}}", value)
    assert "{{" not in text, f"Valeur manquante dans {name}"
    return text


def check_content(content):
    problems = [p.relative_to(content).as_posix() for p in content.rglob("*") if p.name.casefold() in FORBIDDEN]
    if problems:
        raise ValueError("Fichiers interdits dans le contenu Steam : " + ", ".join(problems))
    for required in ("RugbyLegacy27.exe", "runtime/node.exe", "engine", "Licences", "manifest-build.json"):
        if not (content / required).exists():
            raise ValueError("Contenu Steam incomplet : " + required)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--node", type=Path, default=Path(os.environ.get("CD_NODE_EXECUTABLE", r"C:\Program Files\nodejs\node.exe")))
    p.add_argument("--node-notices", type=Path, help="Dossier LICENSE et SHASUMS256 de Node (défaut : licences du SDK)")
    p.add_argument("--sdk", type=Path, required=True, help="SDK Godot 4.7.2 (editor/, templates/, licenses/)")
    p.add_argument("--output", type=Path, required=True, help="Nouveau dossier de sortie (jamais écrasé)")
    p.add_argument("--source-commit", required=True, help="SHA complet du checkout propre à exporter")
    p.add_argument("--description", default="", help="Description du build côté Steam")
    options = p.parse_args()
    if not options.node.is_file():
        p.error("Runtime Node explicite introuvable")
    output = options.output.resolve()
    if output.exists():
        p.error("Choisir un nouveau dossier de sortie : aucun écrasement autorisé")

    warnings = []
    settings = steam_settings()
    module = prototype_module()
    build_args = argparse.Namespace(
        node=options.node, node_notices=options.node_notices, sdk=options.sdk,
        output=output / "export-windows", source_commit=options.source_commit,
        preset="steam-release.cfg", preset_values=publisher_values(warnings))
    app_id = steam_id("CD_STEAM_APP_ID", warnings)
    depot_id = steam_id("CD_STEAM_DEPOT_ID", warnings)
    module.build(build_args)

    steam = output / "steam"
    content = steam / "content"
    shutil.copytree(build_args.output / "RugbyLegacy27-PrototypeGodot", content)
    executable = content / "RugbyLegacy27.exe"
    thumbprint = os.environ.get("CD_SIGN_CERT_SHA1", "").strip()
    if thumbprint:
        sign(executable, thumbprint)
        refresh_manifest_entry(content, "RugbyLegacy27.exe", module)
    else:
        warnings.append("Exécutable non signé (CD_SIGN_CERT_SHA1 absent) : accepté par Steam, mais SmartScreen peut avertir.")
    check_content(content)

    scripts = steam / "scripts"
    scripts.mkdir(parents=True)
    description = options.description or f"Rugby Legacy 27 {module.BUILD_VERSION} ({options.source_commit[:10]})"
    values = {"APP_ID": app_id, "DEPOT_ID": depot_id, "CONTENT_ROOT": "../content/", "BUILD_OUTPUT": "../journal/",
              "DESCRIPTION": description.replace('"', "'")}
    (scripts / "app_build.vdf").write_text(fill_template("app_build.vdf.template", values), encoding="utf-8")
    (scripts / "depot_build_windows.vdf").write_text(fill_template("depot_build_windows.vdf.template", values), encoding="utf-8")
    (steam / "journal").mkdir()
    (steam / "TELEVERSER.txt").write_text(
        f"RUGBY LEGACY 27 — BUILD STEAM {module.BUILD_VERSION}\n\n"
        "Ce dossier est prêt ; rien n'a été envoyé.\n"
        "1. Vérifier App ID et Depot ID dans scripts/app_build.vdf et scripts/depot_build_windows.vdf.\n"
        "2. Depuis ce dossier, avec steamcmd du SDK Steamworks (tools/ContentBuilder/builder) :\n"
        "   steamcmd.exe +login <votre_compte_steamworks> +run_app_build \"%CD%\\scripts\\app_build.vdf\" +quit\n"
        "   (mot de passe et Steam Guard saisis par vous dans steamcmd, jamais enregistrés ici)\n"
        "3. Le build arrive non publié (SetLive vide) : le passer sur une branche depuis le site Steamworks.\n"
        "Options de lancement Steam : exécutable RugbyLegacy27.exe, système Windows 64 bits.\n"
        + ("\nÀ compléter avant publication :\n- " + "\n- ".join(warnings) + "\n" if warnings else ""),
        encoding="utf-8")
    summary = {"steam": str(steam), "content": str(content), "exe": str(executable), "signed": bool(thumbprint),
               "steamworks": {"enabled": bool(settings.get("enabled")), "achievements": bool(settings.get("achievements")),
                              "cloud_saves": bool(settings.get("cloud_saves"))},
               "app_id": app_id, "depot_id": depot_id, "warnings": warnings}
    print(json.dumps(summary, ensure_ascii=False, indent=2), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, AssertionError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"Build Steam refusé : {error}", file=sys.stderr)
        sys.exit(1)
