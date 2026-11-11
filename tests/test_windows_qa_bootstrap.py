"""Real staging/dispatch checks; Linux execution is never Windows proof."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('windows_builder', ROOT / 'scripts/build-godot-prototype.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class WindowsQaBootstrap(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='windows-qa-bootstrap-')
        self.addCleanup(temporary.cleanup)
        self.project = Path(temporary.name)
        self.config = 'config_version=5\n[application]\nrun/main_scene="res://main.tscn"\n'
        (self.project / 'project.godot').write_text(self.config)

    def test_staging_preserves_normal_entry_and_copies_both_inherited_scripts(self):
        builder.stage_windows_qa(self.project)
        self.assertEqual((self.project / 'project.godot').read_text(), self.config)
        self.assertFalse((self.project / 'override.cfg').exists())
        for name in ('windows-resume.gd', 'windows-graphics-smoke.gd'):
            self.assertEqual((self.project / 'windows_qa' / name).read_bytes(), (ROOT / 'ci' / name).read_bytes())
        self.assertEqual((self.project / 'windows_qa/entry.tscn').read_text(), '[gd_scene format=3]\n[node name="WindowsReceiptEntry" type="Node"]\n')

    def test_staging_refuses_a_source_override_instead_of_shipping_it(self):
        (self.project / 'override.cfg').write_text('[application]\nrun/main_scene="res://other.tscn"\n')
        with self.assertRaisesRegex(ValueError, 'override'):
            builder.stage_windows_qa(self.project)

    @unittest.skipUnless(os.environ.get('CD_GODOT_EXE'), 'Explicit Godot SDK required for the real dispatch characterization')
    def test_global_class_dispatch_acknowledges_before_loading_product_scene(self):
        builder.stage_windows_qa(self.project)
        (self.project / 'main.tscn').write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://trap.gd" id="1"]\n[node name="ProductTrap" type="Control"]\nscript=ExtResource("1")\n')
        (self.project / 'trap.gd').write_text('extends Control\nfunc _ready() -> void:\n\tprinterr("PRODUCT_SCENE_LOADED_BEFORE_QA")\n\tget_tree().quit(4)\n')
        godot = os.environ['CD_GODOT_EXE']
        imported = subprocess.run([godot, '--headless', '--editor', '--import', '--path', str(self.project)], capture_output=True, text=True, timeout=60)
        self.assertEqual(imported.returncode, 0, imported.stdout + imported.stderr)
        cache = (self.project / '.godot/global_script_class_cache.cfg').read_text()
        self.assertIn('WindowsReceiptResume', cache)
        self.assertIn('WindowsGraphicsSmoke', cache)
        for mode, class_name, chain in (
            ('graphics-smoke', 'WindowsGraphicsSmoke', ['res://windows_qa/windows-graphics-smoke.gd', 'res://windows_qa/windows-resume.gd']),
            ('resume', 'WindowsReceiptResume', ['res://windows_qa/windows-resume.gd']),
        ):
            output = self.project / mode
            (self.project / 'override.cfg').write_text('[application]\nrun/main_loop_type="' + class_name + '"\nrun/main_scene="res://windows_qa/entry.tscn"\n')
            run = subprocess.run([godot, '--headless', '--path', str(self.project)], env={**os.environ, 'CD_GODOT_RESUME_OUTPUT':str(output), 'CD_GODOT_DATA_DIR':str(self.project / 'outside-profile'), 'CD_GODOT_SELF_TEST':'0'}, capture_output=True, text=True, timeout=15)
            self.assertNotIn('PRODUCT_SCENE_LOADED_BEFORE_QA', run.stdout + run.stderr)
            self.assertNotIn('SCRIPT ERROR', run.stdout + run.stderr)
            ack = json.loads((output / 'driver-ack.json').read_text())
            self.assertEqual(ack['mode'], mode)
            self.assertEqual(ack['script_chain'], chain)
            self.assertEqual(ack['entry_scene'], 'res://windows_qa/entry.tscn')
            self.assertEqual(ack['pid'], json.loads((output / 'report.json').read_text())['pid'])
            # This SDK is an editor on Linux: the real Windows guard must refuse it.
            self.assertEqual(run.returncode, 1)
            self.assertFalse(json.loads((output / 'report.json').read_text())['passed'])
        # Stable resume override must delegate SELF_TEST=1 to the sole integrated
        # runner in main.tscn, without emitting a misleading resume ACK.
        (self.project / 'trap.gd').write_text('extends Control\nfunc _ready() -> void:\n\tassert(OS.get_environment("CD_GODOT_SELF_TEST") == "1")\n\tprint("INTEGRATED_FRESH_DELEGATE")\n\tget_tree().quit(0)\n')
        original_override = (self.project / 'override.cfg').read_bytes()
        output = self.project / 'fresh'
        run = subprocess.run([godot, '--headless', '--path', str(self.project)], env={**os.environ, 'CD_GODOT_RESUME_OUTPUT':str(output), 'CD_GODOT_DATA_DIR':str(self.project / 'outside-profile'), 'CD_GODOT_SELF_TEST':'1'}, capture_output=True, text=True, timeout=15)
        self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
        self.assertIn('INTEGRATED_FRESH_DELEGATE', run.stdout)
        self.assertFalse((output / 'driver-ack.json').exists())
        self.assertEqual((self.project / 'override.cfg').read_bytes(), original_override)


if __name__ == '__main__':
    unittest.main()
