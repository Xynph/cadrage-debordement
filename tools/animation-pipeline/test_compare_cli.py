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
            cases.extend([
                (['--out', str(p/'out.gd')], 'output must use .json'),
                (['--out', str(p/'out.json'), '--clip', ''], 'nonempty and unique'),
                (['--out', str(p/'out.json'), '--clip', 'x', '--clip', 'x'], 'nonempty and unique'),
            ])
            for extra, message in cases:
                with self.subTest(arguments=extra):
                    run = subprocess.run([sys.executable, str(SCRIPT), str(source), str(candidate),
                                          '--godot', 'MUST-NOT-BE-INVOKED', *extra], capture_output=True, text=True)
                    self.assertEqual(run.returncode, 2, run.stdout + run.stderr)
                    self.assertIn(message, run.stderr)
                    self.assertEqual({f: hashlib.sha256(f.read_bytes()).hexdigest() for f in original}, original)
            self.assertFalse((p/'out.json').exists())


class ClipSelection(unittest.TestCase):
    @unittest.skipUnless(os.environ.get('CD_GODOT_EXE'), 'Explicit Godot required for real missing-clip test')
    def test_unknown_clip_is_rejected_without_accepting_partial_or_running_controls(self):
        import json
        source = SCRIPT.parents[2] / 'dist/match3d/assets/quaternius-rugby-athlete.glb'
        digest = hashlib.sha256(source.read_bytes()).hexdigest()
        with tempfile.TemporaryDirectory(prefix='pose-missing-clip-') as td:
            output = Path(td) / 'missing.json'
            run = subprocess.run([sys.executable, str(SCRIPT), str(source), str(source),
                                  '--godot', os.environ['CD_GODOT_EXE'], '--out', str(output),
                                  '--samples', '2', '--clip', 'DOES_NOT_EXIST', '--self-test'],
                                 capture_output=True, text=True, timeout=120)
            self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
            report = json.loads(output.read_text())
            self.assertFalse(report['candidate']['passed'])
            self.assertFalse(report['candidate']['complete_clip_coverage'])
            self.assertEqual(report['candidate']['sampled_poses'], 0)
            self.assertEqual(report['candidate']['per_clip'], {})
            self.assertTrue(any('Requested clip missing' in e for e in report['candidate']['errors']))
            self.assertFalse(report['self_test_passed'])
            self.assertEqual(hashlib.sha256(source.read_bytes()).hexdigest(), digest)


if __name__ == '__main__':
    unittest.main()
