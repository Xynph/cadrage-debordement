import hashlib
import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch


TEST_DIR = Path(__file__).resolve().parent
SCRIPT = TEST_DIR / 'build-godot-prototype.py'
if not SCRIPT.is_file():
    SCRIPT = TEST_DIR.parent / 'scripts' / 'build-godot-prototype.py'
spec = importlib.util.spec_from_file_location('build_godot_prototype', SCRIPT)
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class NodeNoticeTests(unittest.TestCase):
    def setUp(self):
        temp = TemporaryDirectory(dir=TEST_DIR)
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.sdk = self.root / 'sdk'
        self.sdk_licenses = self.sdk / 'licenses'
        self.sdk_licenses.mkdir(parents=True)
        self.node = self.root / 'node.exe'
        self.node.write_bytes(b'test runtime bytes')
        self.node_sha = hashlib.sha256(self.node.read_bytes()).hexdigest()
        self.version_probe = patch.object(builder.subprocess, 'check_output', return_value='v22.23.4\r\n')
        self.version_probe.start()
        self.addCleanup(self.version_probe.stop)

    def make_notice_pair(self, directory, version, runtime_sha):
        directory.mkdir(parents=True, exist_ok=True)
        license_file = directory / f'Node-{version}-LICENSE.txt'
        shasums_file = directory / f'Node-{version}-SHASUMS256.txt'
        license_file.write_text('Example license text', encoding='ascii')
        shasums_file.write_text(f'{runtime_sha}  win-x64/node.exe\n', encoding='ascii')
        return license_file, shasums_file

    def test_mismatched_sdk_stops_before_stage_or_output(self):
        self.make_notice_pair(self.sdk_licenses, 'v26.13.0', '0' * 64)
        editor = self.sdk / 'editor/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe'
        template = self.sdk / 'templates/4.7.2-stable/windows_release_x86_64.exe'
        for file in (editor, template):
            file.parent.mkdir(parents=True)
            file.touch()
        output = self.root / 'export'
        args = SimpleNamespace(node=self.node, sdk=self.sdk, node_notices=None, output=output)
        with patch.object(builder, 'stage', side_effect=AssertionError('stage should not run')):
            with self.assertRaisesRegex(ValueError, r'notices Node v22\.23\.4'):
                builder.build(args)
        self.assertFalse(output.exists())

    def test_exact_notices_override_sdk_node_files(self):
        self.make_notice_pair(self.sdk_licenses, 'v26.13.0', '0' * 64)
        (self.sdk_licenses / 'Godot-LICENSE.txt').write_text('Godot')
        matching = self.make_notice_pair(self.root / 'official', 'v22.23.4', self.node_sha)
        notices, checksum = builder.verified_node_notices(self.node, self.root / 'official')
        self.assertEqual(notices, matching)
        self.assertEqual(checksum, self.node_sha)
        destination = self.root / 'delivered'
        builder.copy_build_licenses(self.sdk_licenses, destination, notices)
        self.assertEqual(
            {path.name for path in destination.iterdir()},
            {'Godot-LICENSE.txt', *(path.name for path in matching)},
        )
        for source in matching:
            self.assertEqual(source.read_bytes(), (destination / source.name).read_bytes())

    def test_mislabeled_checksums_reject_wrong_runtime_bytes(self):
        self.make_notice_pair(self.sdk_licenses, 'v22.23.4', '0' * 64)
        with self.assertRaisesRegex(ValueError, 'Empreinte Node v22.23.4'):
            builder.verified_node_notices(self.node, self.sdk_licenses)

    def test_checksums_need_a_unique_win_x64_executable_entry(self):
        _, sums = self.make_notice_pair(self.sdk_licenses, 'v22.23.4', self.node_sha)
        sums.write_bytes(sums.read_bytes() * 2)
        with self.assertRaisesRegex(ValueError, 'Empreinte Node v22.23.4'):
            builder.verified_node_notices(self.node, self.sdk_licenses)


if __name__ == '__main__':
    unittest.main()
