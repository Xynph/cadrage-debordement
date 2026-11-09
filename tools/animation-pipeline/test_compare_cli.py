"""Input integrity guards: these must fail before Godot is invoked."""
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('compare_poses.py')


class Guards(unittest.TestCase):
    def test_reject_aliases_and_nonfinite_thresholds_without_touching_inputs(self):
        with tempfile.TemporaryDirectory(prefix='pose-guards-') as td:
            p = Path(td)
            source, candidate = p / 'source.glb', p / 'candidate.glb'
            source.write_bytes(b'source input remains unchanged')
            candidate.write_bytes(b'candidate input remains unchanged')
            original = {f: hashlib.sha256(f.read_bytes()).hexdigest() for f in (source, candidate)}
            aliases = [source, candidate]
            for name, create in [('hardlink', os.link), ('symlink', os.symlink)]:
                alias = p / name
                try:
                    create(source, alias)
                except OSError:
                    continue  # Windows symlinks may require privileges.
                aliases.append(alias)
            cases = [(['--out', str(alias)], 'output must not alias') for alias in aliases]
            for option in ('--position-units', '--rotation-rad', '--scale'):
                for value in ('nan', 'inf', '-inf', '0', '-1'):
                    cases.append((['--out', str(p/'out.json'), option+'='+value], 'positive thresholds'))
            for extra, message in cases:
                with self.subTest(arguments=extra):
                    run = subprocess.run([sys.executable, str(SCRIPT), str(source), str(candidate),
                                          '--godot', 'MUST-NOT-BE-INVOKED', *extra], capture_output=True, text=True)
                    self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
                    self.assertIn(message, run.stderr)
                    self.assertEqual({f: hashlib.sha256(f.read_bytes()).hexdigest() for f in original}, original)
            self.assertFalse((p/'out.json').exists())


if __name__ == '__main__':
    unittest.main()
