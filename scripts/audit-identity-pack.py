#!/usr/bin/env python3
"""Read-only aggregate inventory of native identity ZIPs; no media extraction."""
import argparse
import hashlib
import json
import os
from pathlib import PurePosixPath
import re
import stat
import struct
import sys
import unicodedata
import zipfile
import zlib

MIB = 1024 * 1024
MAX_ARCHIVE = 1024 * MIB
MAX_TOTAL = 1536 * MIB
MAX_ENTRIES = 9000
MAX_MANIFEST = 4 * MIB
MAX_IMAGE = 16 * MIB
CHUNK = 1024 * 1024
DATABASES = {
    'rugby-common-2026-10-31-v1', 'rugby-world-2026-11-08-v1',
    'rugby-world-2026-11-09-pacific-v2', 'rugby-world-2026-11-09-japan-v3',
    'rugby-world-2026-11-09-nationale-v4', 'rugby-world-2026-11-09-champ-v5',
}
SCHEMAS = {'cd-identity-pack-v1', 'cd-identity-pack-v2', 'cd-identity-pack-v3'}


class AuditError(Exception):
    """Only constant error codes may cross the CLI boundary."""


def require(condition, code):
    if not condition:
        raise AuditError(code)


def safe_path(value):
    require(isinstance(value, str) and 0 < len(value) <= 600, 'invalid_zip_path')
    require(not any(ord(c) < 32 or ord(c) == 127 for c in value), 'invalid_zip_path')
    require('\\' not in value and ':' not in value and not value.startswith('/'), 'invalid_zip_path')
    value = unicodedata.normalize('NFC', value)
    parts = value.rstrip('/').split('/')
    require(all(p and p not in ('.', '..') and not p.endswith(('.', ' ')) for p in parts), 'invalid_zip_path')
    require(not any(re.match(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)', p, re.I) for p in parts), 'invalid_zip_path')
    require(not PurePosixPath(value).is_absolute(), 'invalid_zip_path')
    return value


def bounded_read(stream, limit):
    data = stream.read(limit + 1)
    require(len(data) <= limit, 'manifest_limit')
    return data


def preflight(stream):
    """Bound the central directory before zipfile allocates its entry objects."""
    size = os.fstat(stream.fileno()).st_size
    require(22 <= size <= MAX_ARCHIVE, 'archive_size_limit')
    stream.seek(max(0, size - 65557))
    tail = stream.read(65557)
    pos = tail.rfind(b'PK\x05\x06')
    require(pos >= 0 and len(tail) >= pos + 22, 'invalid_zip')
    _, disk, cd_disk, here, total, cd_size, cd_offset, comment = struct.unpack_from('<4s4H2LH', tail, pos)
    require(pos + 22 + comment == len(tail), 'invalid_zip')
    require(disk == cd_disk == 0 and here == total, 'unsupported_zip')
    require(total != 65535 and cd_size != 0xffffffff and cd_offset != 0xffffffff, 'unsupported_zip')
    require(total <= MAX_ENTRIES and cd_size <= 16 * MIB, 'entry_limit')
    require(cd_offset + cd_size == size - len(tail) + pos, 'invalid_zip')
    stream.seek(0)
    digest = hashlib.sha256()
    remaining = size
    while remaining:
        chunk = stream.read(min(CHUNK, remaining))
        require(bool(chunk), 'archive_changed_during_audit')
        remaining -= len(chunk)
        digest.update(chunk)
    require(stream.read(1) == b'', 'archive_changed_during_audit')
    stream.seek(0)
    return digest.hexdigest()


def pairs_without_duplicates(pairs):
    out = {}
    for key, value in pairs:
        require(key not in out, 'duplicate_json_key')
        out[key] = value
    return out


def audit_pack(path, verify_assets=False):
    with open(path, 'rb') as stream:
        before = os.fstat(stream.fileno())
        archive_hash = preflight(stream)
        with zipfile.ZipFile(stream) as archive:
            infos = archive.infolist()
            require(len(infos) <= MAX_ENTRIES, 'entry_limit')
            require(sum(i.file_size for i in infos) <= MAX_TOTAL, 'uncompressed_limit')
            entries, folded = {}, set()
            for info in infos:
                name = safe_path(info.filename)
                require(name.casefold() not in folded, 'duplicate_zip_entry')
                require(not stat.S_ISLNK(info.external_attr >> 16), 'unsupported_zip')
                require(not info.flag_bits & 1 and info.compress_type in (0, 8), 'unsupported_zip')
                folded.add(name.casefold())
                entries[name] = info
            info = entries.get('pack.json')
            require(info is not None and not info.is_dir(), 'native_manifest_missing')
            require(info.file_size <= MAX_MANIFEST, 'manifest_limit')
            with archive.open(info) as manifest_stream:
                raw = bounded_read(manifest_stream, MAX_MANIFEST)
            manifest = json.loads(raw.decode('utf-8'), object_pairs_hook=pairs_without_duplicates)
            require(isinstance(manifest, dict) and manifest.get('schema') in SCHEMAS, 'unsupported_manifest')
            database = manifest.get('databaseId')
            require(isinstance(database, str) and database in DATABASES, 'unsupported_database')
            require(manifest['schema'] != 'cd-identity-pack-v3' or database.endswith('-champ-v5'), 'unsupported_manifest')
            groups = {}
            for name in ('clubs', 'players', 'assets'):
                require(isinstance(manifest.get(name), list), 'invalid_manifest_lists')
                groups[name] = manifest[name]
            require(len(groups['assets']) <= MAX_ENTRIES, 'entry_limit')
            if manifest['schema'] == 'cd-identity-pack-v1':
                require('staff' not in manifest, 'invalid_manifest_lists')
                groups['staff'] = []
            else:
                require(isinstance(manifest.get('staff'), list), 'invalid_manifest_lists')
                groups['staff'] = manifest['staff']
            issues = dict.fromkeys(('invalidAssetMetadata', 'assetFilesAbsent', 'assetSizeMismatch',
                                    'assetHashMismatch', 'assetReadFailures', 'undeclaredAssetReferences',
                                    'absentFileReferences', 'indeterminatePortraitStatus',
                                    'statusWithoutPortrait', 'duplicateProfiles'), 0)
            assets, paths = {}, set()
            counts = {'declared': len(groups['assets']), 'uniqueFilesDeclared': 0, 'filesPresent': 0,
                      'verified': 0 if verify_assets else None,
                      'actualBytesRead': 0 if verify_assets else None,
                      'declaredDigestValues': 0}
            for asset in groups['assets']:
                require(isinstance(asset, dict), 'invalid_asset')
                aid = asset.get('id')
                require(isinstance(aid, str) and re.fullmatch(r'[a-zA-Z0-9_-]{1,80}', aid) and aid not in assets, 'invalid_asset')
                name = safe_path(asset.get('path'))
                require(name not in paths, 'duplicate_asset_file')
                paths.add(name)
                size, digest = asset.get('bytes'), asset.get('sha256')
                metadata = type(size) is int and 0 < size <= MAX_IMAGE and isinstance(digest, str) and re.fullmatch(r'[a-f0-9]{64}', digest) is not None
                issues['invalidAssetMetadata'] += int(not metadata)
                entry = entries.get(name)
                present = entry is not None and not entry.is_dir()
                verified = False
                issues['assetFilesAbsent'] += int(not present)
                if present:
                    require(entry.file_size <= MAX_IMAGE, 'image_size_limit')
                    counts['filesPresent'] += 1
                    mismatch = type(size) is not int or size != entry.file_size
                    issues['assetSizeMismatch'] += int(mismatch)
                    if verify_assets:
                        actual, sha = 0, hashlib.sha256()
                        try:
                            with archive.open(entry) as source:
                                while True:
                                    block = source.read(min(CHUNK, MAX_IMAGE + 1 - actual))
                                    if not block:
                                        break
                                    actual += len(block)
                                    require(actual <= MAX_IMAGE, 'image_size_limit')
                                    sha.update(block)
                            counts['actualBytesRead'] += actual
                            if actual != entry.file_size or actual != size:
                                if not mismatch:
                                    issues['assetSizeMismatch'] += 1
                            hash_ok = sha.hexdigest() == digest
                            issues['assetHashMismatch'] += int(not hash_ok)
                            verified = metadata and actual == size == entry.file_size and hash_ok
                        except (zipfile.BadZipFile, zlib.error, RuntimeError, OSError, EOFError):
                            issues['assetReadFailures'] += 1
                        counts['verified'] += int(verified)
                assets[aid] = {'present': present, 'verified': verified, 'digest': digest}
            counts['verifiedDigestValues'] = len({a['digest'] for a in assets.values() if a['verified']}) if verify_assets else None
            counts['uniqueFilesDeclared'] = len(paths)
            counts['declaredDigestValues'] = len({a['digest'] for a in assets.values() if isinstance(a['digest'], str) and re.fullmatch(r'[a-f0-9]{64}', a['digest'])})
            referenced, references = set(), 0

            def coverage(rows, key, portraits=False, photo=False):
                nonlocal references
                result = {'records': len(rows), 'declared': 0, 'missing': 0, 'filePresent': 0,
                          'verified': 0 if verify_assets else None, 'uniqueAssetReferences': 0}
                categories = {k: {'declared': 0, 'filePresent': 0, 'verified': 0 if verify_assets else None}
                              for k in ('official', 'synthetic', 'indeterminate')} if portraits else None
                unique = set()
                for row in rows:
                    require(isinstance(row, dict), 'invalid_profile')
                    value = row.get(key)
                    if key not in row:
                        result['missing'] += 1
                        if portraits and 'synthetic' in row:
                            issues['statusWithoutPortrait'] += 1
                        continue
                    result['declared'] += 1
                    if photo:
                        require(isinstance(value, dict), 'invalid_venue_reference')
                        value = value.get('asset')
                    require(isinstance(value, str), 'invalid_asset_reference')
                    references += 1
                    unique.add(value)
                    referenced.add(value)
                    asset = assets.get(value)
                    present = bool(asset and asset['present'])
                    verified = bool(asset and asset['verified'])
                    issues['undeclaredAssetReferences'] += int(asset is None)
                    issues['absentFileReferences'] += int(asset is not None and not present)
                    result['filePresent'] += int(present)
                    if verify_assets:
                        result['verified'] += int(verified)
                    if portraits:
                        category = 'synthetic' if row.get('synthetic') is True else 'official' if row.get('synthetic') is False else 'indeterminate'
                        issues['indeterminatePortraitStatus'] += int(category == 'indeterminate')
                        categories[category]['declared'] += 1
                        categories[category]['filePresent'] += int(present)
                        if verify_assets:
                            categories[category]['verified'] += int(verified)
                result['uniqueAssetReferences'] = len(unique)
                if not photo:
                    result['uniqueProfiles'] = len({(type(row['id']), row['id']) for row in rows})
                if portraits:
                    result['byDeclaredStatus'] = categories
                return result

            for name in ('clubs', 'players', 'staff'):
                seen = set()
                for row in groups[name]:
                    require(isinstance(row, dict) and type(row.get('id')) in (str, int), 'invalid_profile')
                    token = (type(row['id']), row['id'])
                    issues['duplicateProfiles'] += int(token in seen)
                    seen.add(token)
            club_count = len(groups['clubs'])
            logos = coverage(groups['clubs'], 'logo')
            people = {name: coverage(groups[name], 'portrait', portraits=True) for name in ('players', 'staff')}
            venue_rows = []
            for club in groups['clubs']:
                photos = club.get('photos', {})
                require(isinstance(photos, dict), 'invalid_venue_reference')
                require(not photos or manifest['schema'] == 'cd-identity-pack-v3', 'unsupported_venue_reference')
                venue_rows.append(photos)
            venues = {name: coverage(venue_rows, name, photo=True) for name in ('city', 'stadium')}
            counts.update(uniqueAssetsReferenced=len(referenced), totalReferences=references,
                          sharedReferenceSurplus=references - len(referenced),
                          unreferencedDeclared=len(set(assets) - referenced))
            after = os.fstat(stream.fileno())
            require((before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns), 'archive_changed_during_audit')
            return {'schema': 'identity-pack-inventory-v1', 'status': 'reported', 'databaseId': database,
                    'archiveSha256': archive_hash, 'manifestSha256': hashlib.sha256(raw).hexdigest(),
                    'assetVerificationRequested': bool(verify_assets), 'archiveBytes': before.st_size,
                    'archiveEntries': len(infos), 'clubs': {'records': club_count, 'logos': logos},
                    **people, 'venues': venues, 'assets': counts, 'issues': issues}


class PrivateParser(argparse.ArgumentParser):
    def error(self, message):
        raise AuditError('invalid_arguments')


def main(argv=None):
    parser = PrivateParser(add_help=False)
    parser.add_argument('archive')
    parser.add_argument('--verify-assets', action='store_true')
    try:
        args = parser.parse_args(argv)
        result = audit_pack(args.archive, args.verify_assets)
        code = 2 if any(result['issues'].values()) else 0
    except AuditError as error:
        result, code = {'schema': 'identity-pack-inventory-v1', 'status': 'unavailable', 'errorCode': str(error)}, 1
    except (OSError, zipfile.BadZipFile, zlib.error, UnicodeError, ValueError, TypeError, RecursionError, RuntimeError, EOFError):
        result, code = {'schema': 'identity-pack-inventory-v1', 'status': 'unavailable', 'errorCode': 'unreadable_or_invalid_archive'}, 1
    print(json.dumps(result, ensure_ascii=True, indent=2, sort_keys=True))
    return code


if __name__ == '__main__':
    sys.exit(main())
