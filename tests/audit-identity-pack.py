"""Real miniature ZIPs only; no private identity/media fixture."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/audit-identity-pack.py'
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location('identity_inventory', SCRIPT)
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)
SECRET = 'PrivatePersonNeverPrint-https://private.invalid/portrait.png'
PHOTO = b'fictitious-image-fixture-bytes'


def manifest(schema='cd-identity-pack-v3'):
    return {'schema': schema, 'databaseId': 'rugby-world-2026-11-09-champ-v5',
            'id': 'local-test', 'name': SECRET, 'version': '1', 'rightsStatus': 'test',
            'clubs': [], 'players': [], 'assets': [], **({} if schema.endswith('-v1') else {'staff': []})}


def asset(aid, data=PHOTO):
    return {'id': aid, 'path': 'private/' + aid + '.webp',
            'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}


class InventoryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'secret-private-pack.zip'

    def archive(self, m, data=None):
        data = {} if data is None else data
        with zipfile.ZipFile(self.path, 'w', compression=zipfile.ZIP_DEFLATED) as z:
            z.writestr('pack.json', json.dumps(m))
            for name, content in data.items():
                z.writestr(name, content)
        return self.path

    def cli(self, *args):
        p = subprocess.run([sys.executable, str(SCRIPT), *map(str, args)], capture_output=True, text=True)
        self.assertEqual(p.stderr, '')
        self.assertNotIn(str(self.path), p.stdout)
        self.assertNotIn(SECRET, p.stdout)
        return p.returncode, json.loads(p.stdout)

    def test_profiles_shared_assets_and_territory_are_different_units(self):
        m = manifest(); a = asset('shared'); b = asset('second')
        m['assets'] = [a, b]
        m['clubs'] = [{'id': 0, 'name': SECRET, 'logo': 'shared', 'photos': {
            'city': {'asset': 'second', 'credit': SECRET, 'source': SECRET, 'license': SECRET},
            'stadium': {'asset': 'second'}}}, {'id': 1}]
        m['players'] = [{'id': 'secret-player-1', 'name': SECRET, 'portrait': 'shared', 'synthetic': False},
                        {'id': 'secret-player-2', 'portrait': 'shared', 'synthetic': False},
                        {'id': 'secret-player-3', 'portrait': 'second', 'synthetic': True}, {'id': 'secret-player-4'}]
        m['staff'] = [{'id': 'secret-staff-1', 'portrait': 'second', 'synthetic': True}, {'id': 'secret-staff-2'}]
        self.archive(m, {a['path']: PHOTO, b['path']: PHOTO})
        before = self.path.read_bytes()
        code, r = self.cli(self.path)
        self.assertEqual(code, 0)
        self.assertEqual(r['assets']['uniqueAssetsReferenced'], 2)
        self.assertEqual(r['assets']['totalReferences'], 7)
        self.assertEqual(r['assets']['sharedReferenceSurplus'], 5)
        self.assertEqual(r['assets']['declaredDigestValues'], 1)
        self.assertEqual(r['players']['byDeclaredStatus']['official']['declared'], 2)
        self.assertEqual(r['players']['missing'], 1)
        self.assertEqual(r['staff']['missing'], 1)
        self.assertEqual(r['venues']['city']['filePresent'], 1)
        self.assertEqual(r['venues']['stadium']['filePresent'], 1)
        self.assertIsNone(r['assets']['verified'])
        self.assertEqual(self.path.read_bytes(), before)
        code, r = self.cli(self.path, '--verify-assets')
        self.assertEqual(code, 0)
        self.assertEqual(r['assets']['verified'], 2)
        self.assertEqual(r['players']['verified'], 3)
        self.assertEqual(r['assets']['verifiedDigestValues'], 1)
        text = json.dumps(r)
        for private in [SECRET, 'secret-player', 'secret-staff', 'private/', 'local-test']:
            self.assertNotIn(private, text)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(list(Path(self.tmp.name).iterdir()), [self.path])

    def test_absent_references_and_unknown_status_are_not_official_photos(self):
        m = manifest(); a = asset('absent'); m['assets'] = [a]
        m['players'] = [{'id': 'a', 'portrait': 'not-declared', 'synthetic': False},
                        {'id': 'b', 'portrait': 'absent'}, {'id': 'c', 'synthetic': True}]
        self.archive(m)
        code, r = self.cli(self.path, '--verify-assets')
        self.assertEqual(code, 2)
        self.assertEqual(r['players']['filePresent'], 0)
        self.assertEqual(r['players']['verified'], 0)
        self.assertEqual(r['players']['byDeclaredStatus']['official']['declared'], 1)
        self.assertEqual(r['players']['byDeclaredStatus']['indeterminate']['declared'], 1)
        self.assertEqual(r['issues']['undeclaredAssetReferences'], 1)
        self.assertEqual(r['issues']['absentFileReferences'], 1)
        self.assertEqual(r['issues']['assetFilesAbsent'], 1)
        self.assertEqual(r['issues']['statusWithoutPortrait'], 1)

    def test_declared_presence_and_verified_are_not_conflated_on_corruption(self):
        m = manifest(); a = asset('bad'); m['assets'] = [a]
        m['players'] = [{'id': 'a', 'portrait': 'bad', 'synthetic': False}]
        self.archive(m, {a['path']: b'changed-content'})
        code, r = self.cli(self.path)
        self.assertEqual(code, 2)
        self.assertEqual(r['players']['filePresent'], 1)
        self.assertIsNone(r['players']['verified'])
        self.assertEqual(r['issues']['assetHashMismatch'], 0)
        code, r = self.cli(self.path, '--verify-assets')
        self.assertEqual(code, 2)
        self.assertEqual(r['players']['verified'], 0)
        self.assertEqual(r['issues']['assetHashMismatch'], 1)
        self.assertEqual(r['issues']['assetSizeMismatch'], 1)

    def test_same_size_hash_corruption_requires_streaming_verification(self):
        m = manifest(); a = asset('bad'); m['assets'] = [a]
        m['staff'] = [{'id': 'a', 'portrait': 'bad', 'synthetic': True}]
        self.archive(m, {a['path']: b'X' * len(PHOTO)})
        self.assertEqual(self.cli(self.path)[0], 0)
        code, r = self.cli('--verify-assets', self.path)
        self.assertEqual(code, 2)
        self.assertEqual(r['issues']['assetHashMismatch'], 1)
        self.assertEqual(r['staff']['byDeclaredStatus']['synthetic']['filePresent'], 1)
        self.assertEqual(r['staff']['byDeclaredStatus']['synthetic']['verified'], 0)

    def test_status_is_explicit_and_v1_v2_are_supported(self):
        for schema in ['cd-identity-pack-v1', 'cd-identity-pack-v2']:
            with self.subTest(schema=schema):
                m = manifest(schema); a = asset('one'); m['assets'] = [a]
                m['players'] = [{'id': 'a', 'portrait': 'one', 'synthetic': 0}]
                self.archive(m, {a['path']: PHOTO})
                code, r = self.cli(self.path, '--verify-assets')
                self.assertEqual(code, 2)
                self.assertEqual(r['players']['byDeclaredStatus']['official']['declared'], 0)
                self.assertEqual(r['players']['byDeclaredStatus']['indeterminate']['declared'], 1)
                self.assertEqual(r['staff']['records'], 0)

    def test_duplicate_profiles_counted_without_pretending_unique_coverage(self):
        m = manifest(); m['players'] = [{'id': 'secret'}, {'id': 'secret'}]
        self.archive(m)
        code, r = self.cli(self.path)
        self.assertEqual(code, 2)
        self.assertEqual(r['issues']['duplicateProfiles'], 1)
        self.assertEqual(r['players']['uniqueProfiles'], 1)

    def test_manifest_bomb_rejected_before_json_loading(self):
        with zipfile.ZipFile(self.path, 'w', compression=zipfile.ZIP_DEFLATED) as z:
            z.writestr('pack.json', b' ' * (audit.MAX_MANIFEST + 1))
        self.assertLess(self.path.stat().st_size, 10000)
        code, r = self.cli(self.path)
        self.assertEqual((code, r['errorCode']), (1, 'manifest_limit'))

    def test_entry_count_preflight_and_duplicate_json_are_redacted(self):
        self.archive(manifest())
        data = bytearray(self.path.read_bytes()); pos = data.rfind(b'PK\x05\x06')
        struct.pack_into('<HH', data, pos + 8, audit.MAX_ENTRIES + 1, audit.MAX_ENTRIES + 1)
        self.path.write_bytes(data)
        self.assertEqual(self.cli(self.path)[1]['errorCode'], 'entry_limit')
        with zipfile.ZipFile(self.path, 'w') as z:
            z.writestr('pack.json', '{"secret":"' + SECRET + '","secret":2}')
        self.assertEqual(self.cli(self.path)[1]['errorCode'], 'duplicate_json_key')

    def test_deflate_errors_keep_the_json_protocol_for_asset_and_manifest(self):
        for target in ('private/one.webp', 'pack.json'):
            with self.subTest(target=target):
                m = manifest(); a = asset('one'); m['assets'] = [a]
                m['players'] = [{'id': SECRET, 'portrait': 'one', 'synthetic': True}]
                self.archive(m, {a['path']: PHOTO})
                with zipfile.ZipFile(self.path) as z:
                    offset = z.getinfo(target).header_offset
                raw = bytearray(self.path.read_bytes())
                name_len, extra_len = struct.unpack_from('<HH', raw, offset + 26)
                raw[offset + 30 + name_len + extra_len] = 7  # Invalid deflate BTYPE.
                self.path.write_bytes(raw)
                before = self.path.read_bytes()
                code, r = self.cli(self.path, '--verify-assets')
                self.assertEqual(self.path.read_bytes(), before)
                if target == 'pack.json':
                    self.assertEqual((code, r['errorCode']), (1, 'unreadable_or_invalid_archive'))
                else:
                    self.assertEqual(code, 2)
                    self.assertEqual(r['issues']['assetReadFailures'], 1)
                    self.assertEqual(r['players']['verified'], 0)

    def test_crc_failure_is_quantified_and_manifest_crc_failure_is_redacted(self):
        m = manifest(); a = asset('one'); m['assets'] = [a]
        m['players'] = [{'id': 'a', 'portrait': 'one', 'synthetic': False}]
        # Stored entries let the fixture corrupt bytes while retaining the ZIP CRC.
        with zipfile.ZipFile(self.path, 'w', compression=zipfile.ZIP_STORED) as z:
            z.writestr('pack.json', json.dumps(m)); z.writestr(a['path'], PHOTO)
        with zipfile.ZipFile(self.path) as z:
            entry = z.getinfo(a['path']); offset = entry.header_offset
        data = bytearray(self.path.read_bytes())
        name_len, extra_len = struct.unpack_from('<HH', data, offset + 26)
        data[offset + 30 + name_len + extra_len] ^= 1
        self.path.write_bytes(data)
        self.assertEqual(self.cli(self.path)[0], 0)
        code, r = self.cli(self.path, '--verify-assets')
        self.assertEqual(code, 2)
        self.assertEqual(r['issues']['assetReadFailures'], 1)
        self.assertEqual(r['players']['verified'], 0)
        with zipfile.ZipFile(self.path) as z:
            offset = z.getinfo('pack.json').header_offset
        name_len, extra_len = struct.unpack_from('<HH', data, offset + 26)
        data[offset + 30 + name_len + extra_len] ^= 1
        self.path.write_bytes(data)
        code, r = self.cli(self.path)
        self.assertEqual((code, r['errorCode']), (1, 'unreadable_or_invalid_archive'))

    def test_invalid_inputs_do_not_echo_paths_or_json_values(self):
        self.assertEqual(self.cli(self.path)[0], 1)
        m = manifest(); m['databaseId'] = SECRET; self.archive(m)
        code, r = self.cli(self.path)
        self.assertEqual((code, r['errorCode']), (1, 'unsupported_database'))
        self.assertEqual(self.cli('--unknown-private-value=' + SECRET)[1]['errorCode'], 'invalid_arguments')
        m = manifest(); a = asset('one'); a['path'] = '../private.jpg'; m['assets'] = [a]
        self.archive(m)
        self.assertEqual(self.cli(self.path)[1]['errorCode'], 'invalid_zip_path')


if __name__ == '__main__':
    unittest.main()
