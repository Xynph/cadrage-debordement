#!/usr/bin/env python3
"""Build the public anonymous staff catalogue and the private world identity ZIP.

The build is offline. Every foreign image is verified against its archived
source before resizing. The French media and identity records are copied as is.
"""

import argparse
import base64
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unicodedata
import xml.etree.ElementTree as ET
import zipfile


ROOT = Path(__file__).resolve().parents[1]
WORLD = 'rugby-world-2026-11-08-v1'
LEGACY = 'rugby-common-2026-10-31-v1'
SNAPSHOT = '2026-11-08'
MIB = 1024 * 1024
IMAGE_LIMIT = 16 * MIB
MANIFEST_LIMIT = 4 * MIB
MAX_PIXELS = 40_000_000
MAX_FOREIGN_EDGE = 512
SAFE_ASSET = re.compile(r'medias/[0-9a-f]{64}\.(?:png|jpg|webp)\Z')
# Display names of the public staff catalogue, by identifier. None is derived from a private identity.
BASE_STAFF_NAMES = ROOT / 'data/names/noms-monde-staffs-v1.json'


def need(ok, message):
    if not ok:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def file_sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))


def json_bytes(value, pretty=False):
    return (json.dumps(value, ensure_ascii=False, allow_nan=False,
                       indent=2 if pretty else None,
                       separators=None if pretty else (',', ':')) + '\n').encode('utf-8')


def write_atomic(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix='.' + path.name + '-', delete=False) as stream:
        staged = Path(stream.name)
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    try:
        os.replace(staged, path)
    finally:
        staged.unlink(missing_ok=True)


def name(value, maximum=120):
    need(isinstance(value, str), 'Nom ou rôle absent.')
    value = ' '.join(unicodedata.normalize('NFC', value).split())
    need(0 < len(value) <= maximum and not re.search(r'[<>\x00-\x1f\x7f]', value),
         'Nom ou rôle invalide.')
    return value


def fold(value):
    return unicodedata.normalize('NFKC', value).casefold()


def base_staff_names():
    document = load(BASE_STAFF_NAMES)
    need(document.get('format') == 'rugby-legacy-noms-inventes' and document.get('version') == 1
         and isinstance(document.get('noms'), dict), 'Fichier des noms de base du staff invalide.')
    return document['noms']


def base_name(names, ident, reserved, used):
    need(ident in names, 'Nom de base absent pour un membre du staff : ' + ident)
    value = name(names[ident])
    need(fold(value) not in reserved and fold(value) not in used, 'Nom de base refusé : ' + ident)
    used.add(fold(value))
    return value


def compile_staff(french, overlay, private_french_names=()):
    need(french.get('schema') == 'oval-anonymous-staff-v1' and french.get('version') == 1
         and [c['id'] for c in french['clubs']] == list(range(30)), 'Catalogue de staff français invalide.')
    clubs = french['clubs'] + [{'id': i, 'members': []} for i in range(30, 58)]
    prior = [m for c in french['clubs'] for m in c['members']]
    need(len(prior) == 428, 'Nombre de membres français différent du pack de référence.')
    used = {fold(x['name']) for x in prior}
    reserved = {fold(name(x['name'])) for x in overlay['staff']} | {fold(x) for x in private_french_names}
    private, ids, by_club_name = [], {p['id'] for p in prior}, set()
    names = base_staff_names()
    for person in sorted(overlay['staff'], key=lambda p: (p['clubId'], p['id'])):
        club = person['clubId']
        need(type(club) is int and 30 <= club < 58, 'Club étranger du staff invalide.')
        need(re.fullmatch(r'world-staff:[0-9a-f]{24}', person['id']), 'Référence du staff privé invalide.')
        ident = f"staff:{club}:{sha(('world-staff-v1|' + person['id']).encode())[:16]}"
        real, role = name(person['name']), name(person['role'], 160)
        need(ident not in ids and (club, fold(real)) not in by_club_name, 'Staff étranger dupliqué.')
        need(str(person.get('sourceUrl') or person.get('profileUrl') or '').startswith('https://'),
             'Source officielle du staff absente.')
        ids.add(ident)
        by_club_name.add((club, fold(real)))
        alias = base_name(names, ident, reserved, used)
        clubs[club]['members'].append({'id': ident, 'clubId': club, 'name': alias, 'role': role,
                                       'sourceSeason': person.get('sourceSeason'),
                                       'sourceDate': person.get('sourceDate'),
                                       'historical': person.get('historical') is True,
                                       'observedAt': SNAPSHOT, 'portraitStatus': 'anonymous'})
        private.append({**person, 'id': ident, 'sourceId': person['id'], 'name': real, 'role': role})
    for club in clubs[30:]:
        need(club['members'], f"Aucun staff sourcé pour le club {club['id']}.")
        club['members'].sort(key=lambda p: p['id'])
    return {'schema': french['schema'], 'version': french['version'], 'observedAt': SNAPSHOT,
            'clubs': clubs}, private


def asset_source(record, approved):
    path = Path(record['local_path']).resolve(strict=True)
    need(any(path.is_relative_to(root) for root in approved) and path.is_file(), 'Archive média hors répertoire approuvé.')
    size = record['bytes']
    need(type(size) is int and 0 < size <= 50 * MIB and path.stat().st_size == size,
         'Taille différente de l’archive source.')
    blob = path.read_bytes()
    need(sha(blob) == record['sha256'], 'SHA256 différent de l’archive source.')
    return blob


def clean_svg(blob):
    need(len(blob) <= 2 * MIB and not re.search(rb'<!\s*(?:doctype|entity)', blob, re.I), 'SVG non pris en charge.')
    root = ET.fromstring(blob)
    need(root.tag.rsplit('}', 1)[-1].lower() == 'svg', 'Racine SVG absente.')
    for node in root.iter():
        tag = node.tag.rsplit('}', 1)[-1].lower()
        need(tag not in {'script', 'foreignobject', 'iframe', 'embed', 'object', 'a', 'animate', 'set'},
             'SVG contenant un élément actif.')
        for key, value in node.attrib.items():
            key = key.rsplit('}', 1)[-1].lower()
            need(not key.startswith('on'), 'SVG contenant un gestionnaire d’événement.')
            if key in {'href', 'src'}:
                need(value.startswith('#') or re.match(r'data:image/(?:png|jpeg|webp);base64,', value, re.I),
                     'Référence externe dans le SVG.')
    return blob


def render_svg_worker(request, response, browser_executable):
    """Use the already installed browser as an offline rasterizer for crests."""
    from playwright.sync_api import sync_playwright

    jobs = load(request)
    out = {}
    with sync_playwright() as playwright:
        options = {'headless': True, 'args': ['--disable-background-networking']}
        if browser_executable:
            options['executable_path'] = str(browser_executable)
        browser = playwright.chromium.launch(**options)
        try:
            context = browser.new_context(offline=True, service_workers='block')
            context.route('**/*', lambda route: route.abort())
            page = context.new_page()
            for key, payload in jobs.items():
                out[key] = page.evaluate('''async ({payload,limit}) => {
                    const img=new Image(); img.src='data:image/svg+xml;base64,'+payload;
                    await img.decode();
                    if(!img.naturalWidth||!img.naturalHeight) throw Error('dimensions SVG absentes');
                    const scale=limit/Math.max(img.naturalWidth,img.naturalHeight);
                    const c=document.createElement('canvas');
                    c.width=Math.max(1,Math.round(img.naturalWidth*scale));
                    c.height=Math.max(1,Math.round(img.naturalHeight*scale));
                    c.getContext('2d').drawImage(img,0,0,c.width,c.height);
                    return c.toDataURL('image/png').split(',')[1];
                }''', {'payload': payload, 'limit': MAX_FOREIGN_EDGE})
        finally:
            browser.close()
    response.write_bytes(json_bytes(out))


def rasterize_svgs(jobs, stage, args):
    if not jobs:
        return {}
    need(args.svg_python, 'Un Python déjà équipé de Playwright est requis pour les logos SVG.')
    request, response = stage / 'svg-input.json', stage / 'svg-output.json'
    request.write_bytes(json_bytes({k: base64.b64encode(clean_svg(b)).decode('ascii') for k, b in jobs.items()}))
    command = [str(args.svg_python), str(Path(__file__).resolve()), '--svg-worker', str(request), str(response)]
    if args.browser_executable:
        command += ['--browser-executable', str(args.browser_executable)]
    subprocess.run(command, check=True, timeout=120, env={**os.environ, 'TEMP': str(stage), 'TMP': str(stage)})
    out = load(response)
    need(set(out) == set(jobs), 'Rasterisation SVG incomplète.')
    return {k: base64.b64decode(v, validate=True) for k, v in out.items()}


def normalized_image(blob, logo=False):
    from PIL import Image, ImageOps

    with Image.open(io.BytesIO(blob), formats=['PNG', 'JPEG', 'WEBP', 'AVIF']) as image:
        need(image.width * image.height <= MAX_PIXELS and getattr(image, 'n_frames', 1) == 1,
             'Image animée ou dimensions excessives.')
        image.load()
        image = ImageOps.exif_transpose(image)
        alpha = 'A' in image.getbands() or 'transparency' in image.info
        image = image.convert('RGBA' if alpha else 'RGB')
        image.thumbnail((MAX_FOREIGN_EDGE, MAX_FOREIGN_EDGE), Image.Resampling.LANCZOS)
        if alpha:
            need(image.getchannel('A').getbbox() is not None, 'Image entièrement transparente.')
        output = io.BytesIO()
        if logo:
            image.save(output, format='PNG', optimize=True)
        else:
            image.save(output, format='WEBP', quality=85, method=4, exact=False)
        return output.getvalue(), 'png' if logo else 'webp', image.size


def zinfo(path, method):
    # Fixed timestamp and flags; no source filesystem metadata is exported.
    info = zipfile.ZipInfo(path, (2026, 11, 9, 0, 0, 0))
    info.create_system = 3
    info.external_attr = 0o100644 << 16
    info.compress_type = method
    return info


def emit(out, path, blob, method=zipfile.ZIP_STORED):
    out.writestr(zinfo(path, method), blob, compresslevel=6 if method == zipfile.ZIP_DEFLATED else None)


def read_entry(archive, path, limit):
    info = archive.getinfo(path)
    need(not info.is_dir() and 0 < info.file_size <= limit, 'Taille d’entrée ZIP invalide : ' + path)
    return archive.read(info)


def load_legacy(archive):
    entries = archive.namelist()
    need(len(entries) == len(set(entries)), 'Entrée du ZIP français dupliquée.')
    p = json.loads(read_entry(archive, 'pack.json', MANIFEST_LIMIT))
    need(p['schema'] == 'cd-identity-pack-v2' and p['databaseId'] == LEGACY and
         [len(p[k]) for k in ('clubs', 'players', 'staff', 'assets')] == [30, 1592, 428, 2050],
         'Le ZIP français doit être le pack validé avec les 104 portraits IA.')
    need(sum(x.get('synthetic') is True for x in p['staff']) == 104, '104 portraits IA français attendus.')
    return p


def verify_id_coverage(pack, world, staff):
    expected = {'clubs': {c['id'] for c in world['clubs']},
                'players': {p['id'] for c in world['clubs'] for p in c['players']},
                'staff': {p['id'] for c in staff['clubs'] for p in c['members']}}
    for key, ids in expected.items():
        rows = pack[key]
        need(len(rows) == len(ids) and {r['id'] for r in rows} == ids, 'Couverture d’identifiants incomplète : ' + key)
    need(all(c.get('logo') for c in pack['clubs']), 'Logo absent pour un club.')
    assets = {a['id']: a for a in pack['assets']}
    used = {x['logo'] for x in pack['clubs']}
    for key in ('players', 'staff'):
        for row in pack[key]:
            if 'portrait' in row:
                need(type(row.get('synthetic')) is bool, 'Portrait sans provenance synthétique/officielle.')
                used.add(row['portrait'])
            else:
                need('synthetic' not in row, 'Mention IA sans portrait.')
    need(used == set(assets) and len(assets) == len(pack['assets']), 'Média non rattaché ou dupliqué.')


def check_archive(path, expected):
    need(path.stat().st_size <= 1024 * MIB, 'ZIP mondial au-delà de la limite d’archive.')
    with zipfile.ZipFile(path) as z:
        entries = z.infolist()
        need(len(entries) <= 5000 and sum(x.file_size for x in entries) <= 1536 * MIB,
             'Limite mondiale des entrées décompressées dépassée.')
        need(len({x.filename for x in entries}) == len(entries), 'Entrée ZIP dupliquée.')
        p = json.loads(read_entry(z, 'pack.json', MANIFEST_LIMIT))
        need(p == expected, 'Manifeste du ZIP différent du manifeste compilé.')
        for a in p['assets']:
            need(SAFE_ASSET.fullmatch(a['path']), 'Chemin média non canonique.')
            raw = read_entry(z, a['path'], IMAGE_LIMIT)
            need(len(raw) == a['bytes'] and sha(raw) == a['sha256'], 'SHA256 média ZIP invalide.')
    return file_sha(path)


def build_pack(args, world, french, overlay):
    need(args.french_pack and args.output and args.report and args.approved_asset_root,
         'Le ZIP français, les racines média, le ZIP de sortie et le rapport sont requis.')
    need(args.output.suffix.lower() == '.zip' and args.output.resolve() != args.french_pack.resolve(),
         'Le ZIP mondial doit être distinct du pack français.')
    need(args.replace or not args.output.exists(), 'Le ZIP de sortie existe ; nom distinct ou --replace explicite requis.')
    approved = [p.resolve(strict=True) for p in args.approved_asset_root]
    foreign_clubs = {c['id']: c for c in overlay['clubs'] if c['id'] >= 30}
    foreign_players = {p['id']: p for p in overlay['players'] if p.get('clubId', -1) >= 30}
    need(set(foreign_clubs) == set(range(30, 58)) and len(foreign_players) == world['playerCount'] - 1592,
         'Inventaire mondial privé incomplet.')
    for c in world['clubs'][30:]:
        need(all(foreign_players.get(p['id'], {}).get('clubId') == c['id'] for p in c['players']),
             'Joueur privé absent ou club différent du registre.')

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(args.french_pack) as fr, tempfile.TemporaryDirectory(prefix='.rugby-reel-', dir=args.output.parent) as folder:
        stage = Path(folder).resolve(strict=True)
        need(stage.is_relative_to(args.output.parent.resolve()), 'Staging hors répertoire de sortie.')
        original = load_legacy(fr)
        public_staff, staff = compile_staff(french, overlay, (p['name'] for p in original['staff']))
        need({p['id'] for p in original['staff']} == {m['id'] for c in french['clubs'] for m in c['members']},
             'Identifiants des 428 staffs français incohérents.')
        pack = {**original, 'id': 'rugby-reel-monde', 'name': 'Rugby Réel — Monde', 'version': '2026.11.09',
                'databaseId': WORLD, 'rightsStatus': 'private-user-authorized'}
        known_assets = {a['sha256']: a for a in pack['assets']}
        logo_sources = {}
        svg_jobs = {}
        for cid, club in sorted(foreign_clubs.items()):
            need(club.get('logoAssets'), f'Logo officiel manquant : {cid}.')
            record = club['logoAssets'][0]
            blob = asset_source(record, approved)
            logo_sources[cid] = (record, blob)
            if str(record.get('mime') or record.get('mime_type') or '').lower() == 'image/svg+xml':
                svg_jobs[str(cid)] = blob
        rendered = rasterize_svgs(svg_jobs, stage, args)
        private_sources = []
        missing = {'players': [], 'staff': []}
        rejected_media = []
        archive_path = stage / 'validated.zip'
        with zipfile.ZipFile(archive_path, 'w', allowZip64=False) as out:
            def write_media(blob, ext):
                digest = sha(blob)
                if digest not in known_assets:
                    entry = {'id': 'photo-' + digest, 'path': 'medias/' + digest + '.' + ext,
                             'sha256': digest, 'bytes': len(blob)}
                    known_assets[digest] = entry
                    pack['assets'].append(entry)
                    emit(out, entry['path'], blob)
                return known_assets[digest]['id']

            for a in original['assets'][:]:
                need(SAFE_ASSET.fullmatch(a['path']), 'Chemin média français non canonique.')
                raw = read_entry(fr, a['path'], IMAGE_LIMIT)
                need(len(raw) == a['bytes'] and sha(raw) == a['sha256'], 'Empreinte média français incorrecte.')
                emit(out, a['path'], raw)
            for n in ('Sources-staff.json', 'Sources-staff-avatars-ia.json'):
                emit(out, n, read_entry(fr, n, MANIFEST_LIMIT), zipfile.ZIP_DEFLATED)

            def provenance(kind, ident, record, media_id, size, profile):
                private_sources.append({'kind': kind, 'id': ident, 'profileUrl': profile,
                                        'imageUrl': record.get('url') or record.get('final_url'),
                                        'sourceSha256': record['sha256'], 'sourceBytes': record['bytes'],
                                        'assetId': media_id, 'width': size[0], 'height': size[1], 'synthetic': False})

            for cid, club in sorted(foreign_clubs.items()):
                record, raw = logo_sources[cid]
                cooked, ext, size = normalized_image(rendered.get(str(cid), raw), logo=True)
                asset = write_media(cooked, ext)
                abbr = world['clubs'][cid]['abbr']
                need(isinstance(abbr, str) and 1 <= len(abbr) <= 8 and abbr.isalnum(), 'Abréviation club invalide.')
                pack['clubs'].append({'id': cid, 'name': name(club['name']), 'abbr': abbr, 'logo': asset})
                provenance('logo', cid, record, asset, size, next(iter(club.get('sourceUrls', [])), None))

            def persons(group, people):
                for i, person in enumerate(people, 1):
                    row = {'id': person['id'], 'name': name(person['name'])}
                    profile = person.get('profileUrl') or person.get('sourceUrl')
                    candidates = [person.get('photoAsset'), *person.get('urcPhotoAssets', [])]
                    tested = set()
                    for record in candidates:
                        if not record or record['sha256'] in tested:
                            continue
                        tested.add(record['sha256'])
                        # Integrity failures abort; an intact but undecodable original does not.
                        raw = asset_source(record, approved)
                        try:
                            cooked, ext, size = normalized_image(raw)
                        except (OSError, ValueError) as error:
                            rejected_media.append({'id': person['id'], 'imageUrl': record.get('url'),
                                                   'sourceSha256': record['sha256'], 'reason': str(error)})
                            continue
                        asset = write_media(cooked, ext)
                        row.update(portrait=asset, synthetic=False)
                        provenance(group, person['id'], record, asset, size, profile)
                        break
                    else:
                        missing[group].append({'id': person['id'], 'clubId': person['clubId'], 'name': row['name'],
                                               'profileUrl': profile, 'reason': 'official-image-undecodable' if tested else 'no-attributable-official-image'})
                    pack[group].append(row)
                    if i % 250 == 0:
                        print(f'Images privées vérifiées : {group} {i}/{len(people)}', flush=True)

            persons('players', sorted(foreign_players.values(), key=lambda p: p['id']))
            persons('staff', staff)
            verify_id_coverage(pack, world, public_staff)
            emit(out, 'pack.json', json_bytes(pack), zipfile.ZIP_DEFLATED)
            source_report = {'schema': 'world-private-media-provenance-v1', 'snapshot': SNAPSHOT,
                             'databaseId': WORLD, 'records': private_sources, 'missing': missing,
                             'rejectedMedia': rejected_media,
                             'staffIdentityDecisions': overlay.get('staffIdentityDecisions', [])}
            emit(out, 'Sources-internationales.json', json_bytes(source_report), zipfile.ZIP_DEFLATED)
            emit(out, 'LISEZ-MOI.txt', ('Rugby Réel — Monde, usage privé.\n'
                                      'Le registre 2026/27 et ses notes de jeu restent identiques.\n'
                                      'Les portraits français déjà marqués IA gardent cette indication.\n'
                                      'Les portraits étrangers sont issus des sources officielles archivées.\n'
                                      'Les identités sans image conservent leur nom et leur portrait de repli.\n').encode('utf-8'),
                 zipfile.ZIP_DEFLATED)
        digest = check_archive(archive_path, pack)
        if args.output.exists():
            need(args.replace, 'Le ZIP de sortie a été créé pendant la compilation.')
        size = archive_path.stat().st_size
        os.replace(archive_path, args.output)
        write_atomic(args.staff_output, json_bytes(public_staff, pretty=True))
        report = {**source_report, 'archive': str(args.output.resolve()), 'archiveSha256': digest,
                  'archiveBytes': size, 'frenchArchiveSha256': file_sha(args.french_pack),
                  'frenchAssetsCopiedByteForByte': 2050,
                  'counts': {k: len(pack[k]) for k in ('clubs', 'players', 'staff', 'assets')},
                  'foreignPortraits': {k: len([r for r in private_sources if r['kind'] == k]) for k in missing},
                  'missingCounts': {k: len(rows) for k, rows in missing.items()}}
        write_atomic(args.report, json_bytes(report, pretty=True))
        print(json.dumps({k: report[k] for k in ('archiveBytes', 'archiveSha256', 'counts', 'foreignPortraits', 'missingCounts')}, ensure_ascii=False))


def attach_illustrations(args, world, public_staff):
    """Create a sibling ZIP; the original pack's declared media are copied exactly."""
    need(args.synthetic_manifest and args.output and args.report and args.approved_asset_root,
         'Le manifeste IA, les racines média, le ZIP frère et le rapport sont requis.')
    base_path = args.base_world_pack.resolve(strict=True)
    need(args.output.suffix.lower() == '.zip' and args.output.resolve() != base_path,
         'Le ZIP illustré doit être distinct du ZIP officiel.')
    need(args.replace or not args.output.exists(), 'Le ZIP illustré de sortie existe déjà.')
    need(base_path.stat().st_size <= 1024 * MIB, 'ZIP de base trop volumineux.')
    source = load(args.synthetic_manifest)
    base_digest = file_sha(base_path)
    need(source.get('schema') == 'world-fictional-portrait-atlas-v1' and source.get('databaseId') == WORLD
         and source.get('generator') == 'built-in image_gen' and source.get('likenessVerified') is False
         and source.get('basePackSha256') == base_digest, 'Manifeste d’illustrations ou ZIP de base invalide.')
    approved = [p.resolve(strict=True) for p in args.approved_asset_root]
    atlases = {a['key']: a for a in source['atlases']}
    need(len(atlases) == len(source['atlases']) and len(atlases) == 6, 'Les six planches distinctes sont requises.')
    for atlas in atlases.values():
        atlas_path = Path(atlas['file']).resolve(strict=True)
        need(any(atlas_path.is_relative_to(root) for root in approved) and file_sha(atlas_path) == atlas['sha256'],
             'Planche source absente ou modifiée.')
    club_ids = {p['id']: c['id'] for c in world['clubs'] for p in c['players']}
    club_ids.update({p['id']: c['id'] for c in public_staff['clubs'] for p in c['members']})

    args.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(base_path) as base, tempfile.TemporaryDirectory(prefix='.rugby-reel-ia-', dir=args.output.parent) as folder:
        stage = Path(folder).resolve(strict=True)
        need(stage.is_relative_to(args.output.parent.resolve()), 'Staging hors répertoire de sortie.')
        pack = json.loads(read_entry(base, 'pack.json', MANIFEST_LIMIT))
        need(pack.get('schema') == 'cd-identity-pack-v2' and pack.get('databaseId') == WORLD,
             'ZIP monde de base incompatible.')
        verify_id_coverage(pack, world, public_staff)
        originals = pack['assets'][:]
        existing = {a['sha256'] for a in originals}
        expected = {(group, p['id']): p for group in ('players', 'staff') for p in pack[group] if not p.get('portrait')}
        need(all(club_ids[p['id']] >= 30 for p in expected.values()), 'Le ZIP français a perdu un portrait.')
        records = source['records']
        assignments = {(r['group'], r['id']): r for r in records}
        need(len(assignments) == len(records) and set(assignments) == set(expected),
             'Les illustrations doivent couvrir exactement les identifiants sans portrait.')
        archived_illustrations, chosen_cells = [], set()
        archive_path = stage / 'validated.zip'
        with zipfile.ZipFile(archive_path, 'w', allowZip64=False) as out:
            for a in originals:
                need(SAFE_ASSET.fullmatch(a['path']), 'Chemin média de base non canonique.')
                raw = read_entry(base, a['path'], IMAGE_LIMIT)
                need(len(raw) == a['bytes'] and sha(raw) == a['sha256'], 'Empreinte média de base incorrecte.')
                emit(out, a['path'], raw)
            for n in ('Sources-staff.json', 'Sources-staff-avatars-ia.json', 'Sources-internationales.json'):
                emit(out, n, read_entry(base, n, MANIFEST_LIMIT), zipfile.ZIP_DEFLATED)
            from PIL import Image
            for key, r in sorted(assignments.items()):
                atlas = atlases.get(r['atlasKey'])
                cell = (r['atlasKey'], r['cell'])
                need(r.get('synthetic') is True and atlas and r['atlasSha256'] == atlas['sha256']
                     and r['clubId'] == club_ids[r['id']] and type(r['cell']) is int and 0 <= r['cell'] < 16
                     and r['atlasKey'].startswith(key[0] + '-') and cell not in chosen_cells,
                     'Attribution d’illustration invalide ou dupliquée.')
                chosen_cells.add(cell)
                raw = asset_source(r, approved)
                with Image.open(io.BytesIO(raw), formats=['WEBP']) as tile:
                    need(tile.width == tile.height and 128 <= tile.width <= MAX_FOREIGN_EDGE
                         and tile.size == (r['width'], r['height']) and getattr(tile, 'n_frames', 1) == 1,
                         'Dimensions ou format d’illustration invalide.')
                    tile.load()
                digest = sha(raw)
                need(digest not in existing, 'Image d’illustration dupliquée.')
                existing.add(digest)
                a = {'id': 'photo-' + digest, 'path': 'medias/' + digest + '.webp', 'sha256': digest, 'bytes': len(raw)}
                pack['assets'].append(a)
                expected[key].update(portrait=a['id'], synthetic=True)
                emit(out, a['path'], raw)
                archived_illustrations.append({k: v for k, v in r.items() if k != 'local_path'})
            need(pack['assets'][:len(originals)] == originals, 'Les médias de base ont changé.')
            verify_id_coverage(pack, world, public_staff)
            pack.update(id='rugby-reel-monde-illustrations', name='Rugby Réel — Monde avec illustrations',
                        version='2026.11.09-illustrations')
            manifest = {**source, 'atlases': [{k: v for k, v in a.items() if k != 'file'} for a in atlases.values()],
                        'records': archived_illustrations}
            emit(out, 'pack.json', json_bytes(pack), zipfile.ZIP_DEFLATED)
            emit(out, 'Sources-illustrations.json', json_bytes(manifest), zipfile.ZIP_DEFLATED)
            emit(out, 'LISEZ-MOI.txt', ('Rugby Réel — Monde avec illustrations, usage privé.\n'
                                      'Les médias du pack initial sont conservés à l’identique.\n'
                                      'Les illustrations IA représentent des adultes fictifs sans ressemblance recherchée.\n'
                                      'Elles remplacent uniquement des images absentes et portent la mention synthétique.\n'
                                      'Aucun attribut, contrat ni identifiant de joueur n’est modifié.\n').encode('utf-8'),
                 zipfile.ZIP_DEFLATED)
        digest = check_archive(archive_path, pack)
        if args.output.exists():
            need(args.replace, 'Le ZIP illustré de sortie a été créé pendant la compilation.')
        size = archive_path.stat().st_size
        os.replace(archive_path, args.output)
        counts = {k: len([r for r in records if r['group'] == k]) for k in ('players', 'staff')}
        report = {'archive': str(args.output.resolve()), 'archiveBytes': size, 'archiveSha256': digest,
                  'basePackSha256': base_digest, 'preservedAssets': len(originals), 'assets': len(pack['assets']),
                  'illustrations': counts, 'portraitsMissing': 0, 'manifest': manifest}
        write_atomic(args.report, json_bytes(report, pretty=True))
        print(json.dumps({k: v for k, v in report.items() if k != 'manifest'}, ensure_ascii=False))


def main():
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--overlay', type=Path)
    cli.add_argument('--world', type=Path, default=ROOT / 'native/engine/world-registry.json')
    cli.add_argument('--french-staff', type=Path, default=ROOT / 'native/engine/staff-registry.json')
    cli.add_argument('--staff-output', type=Path, default=ROOT / 'native/engine/world-staff-registry.json')
    cli.add_argument('--french-pack', type=Path)
    cli.add_argument('--base-world-pack', type=Path)
    cli.add_argument('--synthetic-manifest', type=Path)
    cli.add_argument('--output', type=Path)
    cli.add_argument('--report', type=Path)
    cli.add_argument('--approved-asset-root', type=Path, action='append')
    cli.add_argument('--svg-python', type=Path)
    cli.add_argument('--browser-executable', type=Path)
    cli.add_argument('--staff-only', action='store_true')
    cli.add_argument('--check-staff', action='store_true')
    cli.add_argument('--replace', action='store_true')
    cli.add_argument('--svg-worker', type=Path, nargs=2, help=argparse.SUPPRESS)
    args = cli.parse_args()
    if args.svg_worker:
        render_svg_worker(*args.svg_worker, args.browser_executable)
        return
    if args.base_world_pack:
        world = load(args.world)
        need(world['id'] == WORLD and world['clubCount'] == 58, 'Édition de monde incompatible.')
        attach_illustrations(args, world, load(args.staff_output))
        return
    need(args.overlay, 'Le manifeste privé est requis.')
    world, french, overlay = load(args.world), load(args.french_staff), load(args.overlay)
    need(world['id'] == WORLD and overlay['databaseId'] == WORLD and world['clubCount'] == 58 and
         overlay['schema'] == 'world-identity-overlay-v1', 'Édition de monde incompatible.')
    if args.staff_only or args.check_staff:
        names = []
        if args.french_pack:
            with zipfile.ZipFile(args.french_pack) as z:
                names = [p['name'] for p in load_legacy(z)['staff']]
        public, _ = compile_staff(french, overlay, names)
        if args.check_staff:
            need(load(args.staff_output) == public, 'Registre mondial des staffs périmé.')
        else:
            write_atomic(args.staff_output, json_bytes(public, pretty=True))
        print(f"Staff monde : {sum(len(c['members']) for c in public['clubs'])} membres, 58 clubs.")
    else:
        build_pack(args, world, french, overlay)


if __name__ == '__main__':
    main()
