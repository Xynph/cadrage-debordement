#!/usr/bin/env python3
"""Read-only Atlas inventories; output aggregate counts, never club/photo identities."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import runpy
import stat
import sys
import zipfile
import zlib

H = runpy.run_path(str(Path(__file__).with_name('audit-identity-pack.py')), run_name='identity_helpers')
AuditError, require, safe_path = H['AuditError'], H['require'], H['safe_path']
MAX_MANIFEST, MAX_IMAGE, MAX_TOTAL = H['MAX_MANIFEST'], H['MAX_IMAGE'], H['MAX_TOTAL']
CHUNK = H['CHUNK']
KINDS = ('city', 'stadium')


def digest_valid(value):
    return isinstance(value, str) and H['re'].fullmatch(r'[a-f0-9]{64}', value) is not None


def json_bytes(raw):
    return json.loads(raw.decode('utf-8'), object_pairs_hook=H['pairs_without_duplicates'])


def club_mapping():
    """Explicit stable ID/slug relation, not a row-number guess; no values printed."""
    file = Path(__file__).resolve().parents[1] / 'native/engine/world-registry.json'
    if not file.is_file():
        return {}
    with file.open('rb') as source:
        require(os.fstat(source.fileno()).st_size <= 32 * H['MIB'], 'club_map_limit')
        data = json.load(source)
    rows = data.get('clubs', [])
    result = {}
    for club in rows:
        slug, cid = club.get('slug'), club.get('id')
        require(isinstance(slug, str) and type(cid) is int and slug not in result, 'invalid_club_map')
        result[slug] = cid
    return result


def fresh_issues():
    return dict.fromkeys(('invalidMetadata', 'fileAbsent', 'sizeMismatch', 'hashMismatch', 'readFailures', 'undeclaredAssetReferences'), 0)


def byte_verification(source, size, sha, issues):
    actual, digest = 0, hashlib.sha256()
    try:
        with source() as stream:
            while True:
                data = stream.read(min(CHUNK, MAX_IMAGE + 1 - actual))
                if not data:
                    break
                actual += len(data)
                require(actual <= MAX_IMAGE, 'image_size_limit')
                digest.update(data)
        if type(size) is not int or actual != size:
            issues['sizeMismatch'] += 1
        good = digest.hexdigest() == sha
        issues['hashMismatch'] += int(not good)
        return good and type(size) is int and actual == size, actual
    except (OSError, EOFError, RuntimeError, zipfile.BadZipFile, zlib.error):
        issues['readFailures'] += 1
        return False, actual


def public_atlas(manifest, asset_root, verify):
    with open(manifest, 'rb') as stream:
        require(os.fstat(stream.fileno()).st_size <= MAX_MANIFEST, 'manifest_limit')
        raw = H['bounded_read'](stream, MAX_MANIFEST)
    data = json_bytes(raw)
    require(isinstance(data, dict) and type(data.get('version')) is int and data['version'] == 1 and isinstance(data.get('photos'), list), 'unsupported_public_atlas')
    require(len(data['photos']) <= H['MAX_ENTRIES'], 'entry_limit')
    root = Path(asset_root).resolve(strict=True)
    require(root.is_dir(), 'invalid_asset_root')
    mapping = club_mapping()
    mapped = all(isinstance(p, dict) and p.get('slug') in mapping for p in data['photos'])
    issues, rows, files, bytes_read = fresh_issues(), [], {}, 0
    for photo in data['photos']:
        require(isinstance(photo, dict) and photo.get('kind') in KINDS and isinstance(photo.get('slug'), str), 'invalid_public_photo')
        name = safe_path(photo.get('file'))
        path = root / name
        require(path.resolve().is_relative_to(root), 'asset_outside_root')
        size, sha = photo.get('file_bytes'), photo.get('sha256')
        metadata = digest_valid(sha) and type(size) is int and 0 < size <= MAX_IMAGE
        issues['invalidMetadata'] += int(not metadata)
        if name not in files:
            present = path.is_file() and not path.is_symlink()
            verified = False
            issues['fileAbsent'] += int(not present)
            if present:
                require(path.stat().st_size <= MAX_IMAGE, 'image_size_limit')
                if path.stat().st_size != size and not verify:
                    issues['sizeMismatch'] += 1
                if verify:
                    verified, amount = byte_verification(lambda: path.open('rb'), size, sha, issues)
                    bytes_read += amount
                    require(bytes_read <= MAX_TOTAL, 'uncompressed_limit')
            files[name] = (present, verified and metadata, size, sha)
        present, verified, old_size, old_sha = files[name]
        require(old_size == size and old_sha == sha, 'conflicting_file_metadata')
        club = ('native', mapping[photo['slug']]) if mapped else ('slug', photo['slug'])
        rows.append((club, photo['kind'], sha if digest_valid(sha) else None, present, verified and metadata))
    return {'kind': 'public-atlas', 'sourceSha256': hashlib.sha256(raw).hexdigest(), 'databaseId': None,
            'clubKeyMode': 'native-id' if mapped else 'public-slug', 'issues': issues,
            'uniqueFilesReferenced': len(files), 'uniqueFilesPresent': sum(f[0] for f in files.values()),
            'uniqueFilesVerified': sum(f[1] for f in files.values()) if verify else None, 'bytesRead': bytes_read if verify else None}, rows


def native_pack(path, verify):
    with open(path, 'rb') as stream:
        before = os.fstat(stream.fileno())
        source_hash = H['preflight'](stream)
        with zipfile.ZipFile(stream) as archive:
            infos = archive.infolist()
            require(len(infos) <= H['MAX_ENTRIES'], 'entry_limit')
            require(sum(i.file_size for i in infos) <= MAX_TOTAL, 'uncompressed_limit')
            entries, seen = {}, set()
            for entry in infos:
                name = safe_path(entry.filename)
                require(name.casefold() not in seen, 'duplicate_zip_entry')
                require(not stat.S_ISLNK(entry.external_attr >> 16) and not entry.flag_bits & 1 and entry.compress_type in (0, 8), 'unsupported_zip')
                seen.add(name.casefold()); entries[name] = entry
            entry = entries.get('pack.json')
            require(entry is not None and entry.file_size <= MAX_MANIFEST, 'native_manifest_missing_or_limit')
            with archive.open(entry) as source:
                raw = H['bounded_read'](source, MAX_MANIFEST)
            m = json_bytes(raw)
            require(isinstance(m, dict) and m.get('schema') in H['SCHEMAS'] and m.get('databaseId') in H['DATABASES'], 'unsupported_manifest')
            require(m['schema'] != 'cd-identity-pack-v3' or m['databaseId'].endswith('-champ-v5'), 'unsupported_manifest')
            require(isinstance(m.get('clubs'), list) and isinstance(m.get('assets'), list), 'invalid_manifest_lists')
            require(len(m['assets']) <= H['MAX_ENTRIES'], 'entry_limit')
            assets = {}
            for a in m['assets']:
                require(isinstance(a, dict) and isinstance(a.get('id'), str) and a['id'] not in assets, 'invalid_asset')
                assets[a['id']] = a
            issues, rows, files, bytes_read = fresh_issues(), [], {}, 0
            for club in m['clubs']:
                require(isinstance(club, dict) and type(club.get('id')) is int, 'invalid_club')
                photos = club.get('photos', {})
                require(isinstance(photos, dict) and all(k in KINDS for k in photos), 'invalid_venue_reference')
                require(not photos or m['schema'] == 'cd-identity-pack-v3', 'unsupported_venue_reference')
                for kind, photo in photos.items():
                    require(isinstance(photo, dict) and isinstance(photo.get('asset'), str), 'invalid_venue_reference')
                    asset = assets.get(photo['asset'])
                    if asset is None:
                        issues['undeclaredAssetReferences'] += 1
                        rows.append((('native', club['id']), kind, None, False, False)); continue
                    size, sha = asset.get('bytes'), asset.get('sha256')
                    metadata = digest_valid(sha) and type(size) is int and 0 < size <= MAX_IMAGE
                    issues['invalidMetadata'] += int(not metadata)
                    name = safe_path(asset.get('path'))
                    if name not in files:
                        entry = entries.get(name)
                        present = entry is not None and not entry.is_dir()
                        verified = False
                        issues['fileAbsent'] += int(not present)
                        if present:
                            require(entry.file_size <= MAX_IMAGE, 'image_size_limit')
                            if entry.file_size != size and not verify:
                                issues['sizeMismatch'] += 1
                            if verify:
                                verified, amount = byte_verification(lambda: archive.open(entry), size, sha, issues)
                                bytes_read += amount
                                require(bytes_read <= MAX_TOTAL, 'uncompressed_limit')
                        files[name] = (present, verified and metadata, size, sha)
                    present, verified, old_size, old_sha = files[name]
                    require(size == old_size and sha == old_sha, 'conflicting_file_metadata')
                    rows.append((('native', club['id']), kind, sha if digest_valid(sha) else None, present, verified and metadata))
        after = os.fstat(stream.fileno())
        require((before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns), 'archive_changed_during_audit')
        return {'kind': 'native-pack', 'sourceSha256': source_hash, 'manifestSha256': hashlib.sha256(raw).hexdigest(),
                'databaseId': m['databaseId'], 'clubKeyMode': 'native-id', 'issues': issues,
                'uniqueFilesReferenced': len(files), 'uniqueFilesPresent': sum(f[0] for f in files.values()),
            'uniqueFilesVerified': sum(f[1] for f in files.values()) if verify else None, 'bytesRead': bytes_read if verify else None}, rows


def summarize(rows, verify):
    by_kind = {}
    for kind in KINDS:
        selected = [r for r in rows if r[1] == kind]
        digests = {r[2] for r in selected if r[2]}
        by_kind[kind] = {'declaredReferences': len(selected), 'clubSlots': len({r[0] for r in selected}),
                         'filePresentReferences': sum(r[3] for r in selected),
                         'verifiedReferences': sum(r[4] for r in selected) if verify else None,
                         'uniqueDeclaredSha256': len(digests),
                         'uniqueVerifiedSha256': len({r[2] for r in selected if r[4]}) if verify else None,
                         'duplicateDeclaredDigestReferences': sum(bool(r[2]) for r in selected) - len(digests)}
    slots = {(r[0], r[1]) for r in rows}
    return {'byCategory': by_kind, 'declaredReferences': len(rows), 'uniqueClubSlots': len(slots),
            'clubsWithBothCategories': len({r[0] for r in rows if r[1] == 'city'} & {r[0] for r in rows if r[1] == 'stadium'}),
            'uniqueDeclaredSha256': len({r[2] for r in rows if r[2]}),
            'uniqueVerifiedSha256': len({r[2] for r in rows if r[4]}) if verify else None}


def audit_sources(public_inputs=(), packs=(), verify=False):
    require(0 < len(public_inputs) + len(packs) <= 16, 'input_count_limit')
    sources = [public_atlas(m, root, verify) for m, root in public_inputs]
    sources += [native_pack(path, verify) for path in packs]
    summaries = [{**meta, 'index': i, 'counts': summarize(rows, verify)} for i, (meta, rows) in enumerate(sources)]
    overlaps = []
    for i, (a, aa) in enumerate(sources):
        for j in range(i + 1, len(sources)):
            b, bb = sources[j]; comparable = a['clubKeyMode'] == b['clubKeyMode']
            slots_a = {(r[0], r[1]) for r in aa}; slots_b = {(r[0], r[1]) for r in bb}
            hashes_a = {r[2] for r in aa if r[2]}; hashes_b = {r[2] for r in bb if r[2]}
            triples_a = {(r[0], r[1], r[2]) for r in aa if r[2]}; triples_b = {(r[0], r[1], r[2]) for r in bb if r[2]}
            overlaps.append({'inputs': [i, j], 'clubSlotsComparable': comparable,
                             'sharedDeclaredDigests': len(hashes_a & hashes_b),
                             'sharedVerifiedDigests': len({r[2] for r in aa if r[4]} & {r[2] for r in bb if r[4]}) if verify else None,
                             'sharedClubSlots': len(slots_a & slots_b) if comparable else None,
                             'sharedClubCategoryDigestTriples': len(triples_a & triples_b) if comparable else None})
    comparable = len({meta['clubKeyMode'] for meta, _ in sources}) == 1
    combined = summarize([r for _, rows in sources for r in rows], verify)
    if not comparable:
        combined['uniqueClubSlots'] = combined['clubsWithBothCategories'] = None
        for counts in combined['byCategory'].values():
            counts['clubSlots'] = None
    return {'schema': 'atlas-photo-inventory-v1', 'status': 'reported', 'assetVerificationRequested': bool(verify),
            'inputs': summaries, 'overlaps': overlaps, 'combinedClubSlotsComparable': comparable, 'combined': combined}


def main(argv=None):
    parser = H['PrivateParser'](add_help=False)
    parser.add_argument('--public', nargs=2, action='append', default=[])
    parser.add_argument('--pack', action='append', default=[])
    parser.add_argument('--verify-assets', action='store_true')
    try:
        args = parser.parse_args(argv)
        result = audit_sources(args.public, args.pack, args.verify_assets)
        code = 2 if any(any(i['issues'].values()) for i in result['inputs']) else 0
    except AuditError as error:
        result, code = {'schema': 'atlas-photo-inventory-v1', 'status': 'unavailable', 'errorCode': str(error)}, 1
    except (OSError, zipfile.BadZipFile, zlib.error, UnicodeError, ValueError, TypeError, KeyError, RecursionError, RuntimeError, EOFError):
        result, code = {'schema': 'atlas-photo-inventory-v1', 'status': 'unavailable', 'errorCode': 'unreadable_or_invalid_source'}, 1
    print(json.dumps(result, ensure_ascii=True, indent=2, sort_keys=True))
    return code


if __name__ == '__main__':
    sys.exit(main())
