"""Atlas tests use temporary miniature archives/files, never private assets."""
import hashlib
import json
from pathlib import Path
import subprocess
import struct
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'scripts/audit-atlas-photos.py'
PRIVATE = 'SENTINEL-https://private.invalid/photo-person-name'
A, B, C = b'first-photograph-fixture', b'second-photograph-fixture', b'changed-photograph-fixture'
sha = lambda data: hashlib.sha256(data).hexdigest()


class AtlasTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name); self.files = self.root / 'assets'; self.files.mkdir()
        self.public = self.root / 'private-public-manifest.json'
        self.pack = self.root / 'private-pack.zip'

    def public_manifest(self, rows=None, slug='toulouse', present=True):
        rows = rows if rows is not None else [('city', 'one.webp', A), ('stadium', 'two.webp', B)]
        data = {'version': 1, 'photos': []}
        for kind, name, content in rows:
            data['photos'].append({'slug': slug, 'kind': kind, 'file': name, 'sha256': sha(content),
                                   'file_bytes': len(content), 'club_name': PRIVATE, 'source_page_url': PRIVATE})
            if present:
                (self.files / name).write_bytes(content)
        self.public.write_text(json.dumps(data)); return data

    def native_pack(self, city=A, stadium=C, missing=False, undeclared=False):
        m = {'schema': 'cd-identity-pack-v3', 'databaseId': 'rugby-world-2026-11-09-champ-v5',
             'name': PRIVATE, 'clubs': [{'id': 0, 'name': PRIVATE, 'photos': {
                 'city': {'asset': 'one', 'source': PRIVATE}, 'stadium': {'asset': 'two', 'credit': PRIVATE}}}],
             'players': [], 'staff': [], 'assets': []}
        for name, content in [('one', city), ('two', stadium)]:
            m['assets'].append({'id': name, 'path': 'photos/' + name + '.webp', 'bytes': len(content), 'sha256': sha(content)})
        if undeclared:
            m['assets'].pop()
        with zipfile.ZipFile(self.pack, 'w', compression=zipfile.ZIP_DEFLATED) as z:
            z.writestr('pack.json', json.dumps(m))
            z.writestr('photos/one.webp', city)
            if not missing:
                z.writestr('photos/two.webp', stadium)
        return m

    def cli(self, *args):
        p = subprocess.run([sys.executable, str(SCRIPT), *map(str, args)], capture_output=True, text=True)
        self.assertEqual(p.stderr, '')
        for value in [PRIVATE, str(self.root), 'one.webp', 'two.webp', 'toulouse', 'source_page_url', 'club_name']:
            self.assertNotIn(value, p.stdout)
        return p.returncode, json.loads(p.stdout)

    def test_public_and_pack_overlap_explicit_club_mapping_and_changed_photo(self):
        self.public_manifest(); self.native_pack()
        before = self.pack.read_bytes()
        code, r = self.cli('--public', self.public, self.files, '--pack', self.pack, '--verify-assets')
        self.assertEqual(code, 0)
        overlap = r['overlaps'][0]
        self.assertTrue(overlap['clubSlotsComparable'])
        self.assertEqual(overlap['sharedClubSlots'], 2)
        self.assertEqual(overlap['sharedClubCategoryDigestTriples'], 1)
        self.assertEqual(overlap['sharedVerifiedDigests'], 1)
        self.assertEqual(r['combined']['uniqueDeclaredSha256'], 3)
        self.assertEqual(r['combined']['uniqueVerifiedSha256'], 3)
        self.assertEqual(r['combined']['declaredReferences'], 4)
        self.assertEqual(r['combined']['uniqueClubSlots'], 2)
        self.assertEqual(self.pack.read_bytes(), before)
        self.assertEqual(len(list(self.root.iterdir())), 3)  # No extraction or output file.

    def test_same_image_different_clubs_and_categories_not_four_unique_photos(self):
        self.public_manifest([('city', 'one.webp', A), ('stadium', 'one.webp', A)])
        self.native_pack(city=A, stadium=A)
        code, r = self.cli('--public', self.public, self.files, '--pack', self.pack, '--verify-assets')
        self.assertEqual(code, 0)
        self.assertEqual(r['combined']['declaredReferences'], 4)
        self.assertEqual(r['combined']['uniqueVerifiedSha256'], 1)
        self.assertEqual(r['inputs'][0]['counts']['clubsWithBothCategories'], 1)
        self.assertEqual(r['inputs'][0]['uniqueFilesReferenced'], 1)
        self.assertEqual(r['inputs'][1]['uniqueFilesReferenced'], 2)

    def test_invalid_empty_files_are_not_verified_at_either_counting_level(self):
        self.public_manifest([('city', 'one.webp', b''), ('stadium', 'two.webp', b'')])
        self.native_pack(city=b'', stadium=b'')
        code, r = self.cli('--public', self.public, self.files, '--pack', self.pack, '--verify-assets')
        self.assertEqual(code, 2)
        for source in r['inputs']:
            with self.subTest(kind=source['kind']):
                self.assertEqual(source['issues']['invalidMetadata'], 2)
                self.assertEqual(source['uniqueFilesPresent'], 2)
                self.assertEqual(source['uniqueFilesVerified'], 0)
                self.assertEqual(source['counts']['uniqueVerifiedSha256'], 0)
                for category in ('city', 'stadium'):
                    self.assertEqual(source['counts']['byCategory'][category]['verifiedReferences'], 0)

    def test_missing_file_and_missing_asset_do_not_become_verified(self):
        self.public_manifest(present=False); self.native_pack(missing=True)
        code, r = self.cli('--public', self.public, self.files, '--pack', self.pack, '--verify-assets')
        self.assertEqual(code, 2)
        self.assertEqual(r['inputs'][0]['issues']['fileAbsent'], 2)
        self.assertEqual(r['inputs'][1]['issues']['fileAbsent'], 1)
        self.assertEqual(r['inputs'][1]['uniqueFilesPresent'], 1)
        self.assertEqual(r['inputs'][0]['uniqueFilesPresent'], 0)
        self.assertEqual(r['inputs'][1]['counts']['byCategory']['stadium']['verifiedReferences'], 0)
        self.native_pack(undeclared=True)
        code, r = self.cli('--pack', self.pack)
        self.assertEqual(code, 2)
        self.assertEqual(r['inputs'][0]['issues']['undeclaredAssetReferences'], 1)
        self.assertEqual(r['inputs'][0]['counts']['byCategory']['stadium']['uniqueDeclaredSha256'], 0)
        self.assertIsNone(r['combined']['uniqueVerifiedSha256'])

    def test_identical_sources_are_not_added_as_new_photos(self):
        self.public_manifest()
        code, r = self.cli('--public', self.public, self.files, '--public', self.public, self.files, '--verify-assets')
        self.assertEqual(code, 0)
        self.assertEqual(r['combined']['declaredReferences'], 4)
        self.assertEqual(r['combined']['uniqueVerifiedSha256'], 2)
        self.assertEqual(r['overlaps'][0]['sharedClubCategoryDigestTriples'], 2)

    def test_unmapped_club_identity_remains_unknown_but_digest_overlap_is_known(self):
        self.public_manifest(slug=PRIVATE); self.native_pack()
        code, r = self.cli('--public', self.public, self.files, '--pack', self.pack)
        self.assertEqual(code, 0)
        self.assertFalse(r['overlaps'][0]['clubSlotsComparable'])
        self.assertIsNone(r['overlaps'][0]['sharedClubSlots'])
        self.assertIsNone(r['combined']['uniqueClubSlots'])
        self.assertEqual(r['overlaps'][0]['sharedDeclaredDigests'], 1)

    def test_corrupt_file_and_traversal_keep_private_json(self):
        data = self.public_manifest()
        (self.files / 'one.webp').write_bytes(b'X' * len(A))
        code, r = self.cli('--public', self.public, self.files, '--verify-assets')
        self.assertEqual(code, 2)
        self.assertEqual(r['inputs'][0]['issues']['hashMismatch'], 1)
        data['photos'][0]['file'] = '../private.webp'; self.public.write_text(json.dumps(data))
        code, r = self.cli('--public', self.public, self.files)
        self.assertEqual((code, r['errorCode']), (1, 'invalid_zip_path'))

    def test_public_symlink_cannot_read_outside_approved_root(self):
        self.public_manifest()
        outside = self.root / 'outside.webp'; outside.write_bytes(A)
        (self.files / 'one.webp').unlink()
        try:
            (self.files / 'one.webp').symlink_to(outside)
        except OSError:
            self.skipTest('symlinks unavailable for this account')
        code, r = self.cli('--public', self.public, self.files, '--verify-assets')
        self.assertEqual((code, r['errorCode']), (1, 'asset_outside_root'))

    def test_deflate_corruption_is_redacted_for_photo_and_manifest(self):
        for target in ('photos/one.webp', 'pack.json'):
            with self.subTest(target=target):
                self.native_pack()
                with zipfile.ZipFile(self.pack) as z:
                    offset = z.getinfo(target).header_offset
                data = bytearray(self.pack.read_bytes())
                name_len, extra_len = struct.unpack_from('<HH', data, offset + 26)
                data[offset + 30 + name_len + extra_len] = 7
                self.pack.write_bytes(data)
                code, r = self.cli('--pack', self.pack, '--verify-assets')
                if target == 'pack.json':
                    self.assertEqual((code, r['errorCode']), (1, 'unreadable_or_invalid_source'))
                else:
                    self.assertEqual(code, 2)
                    self.assertEqual(r['inputs'][0]['issues']['readFailures'], 1)
                    self.assertEqual(r['inputs'][0]['counts']['byCategory']['city']['verifiedReferences'], 0)

    def test_bounded_json_and_missing_input_are_redacted(self):
        self.public.write_bytes(b' ' * (4 * 1024 * 1024 + 1))
        code, r = self.cli('--public', self.public, self.files)
        self.assertEqual((code, r['errorCode']), (1, 'manifest_limit'))
        self.assertEqual(self.cli('--pack', self.pack)[0], 1)
        self.assertEqual(self.cli()[1]['errorCode'], 'input_count_limit')


if __name__ == '__main__':
    unittest.main()
