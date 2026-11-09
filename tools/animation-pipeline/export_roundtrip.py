"""Blender batch: import source then call a pinned EL4CTEO godot preset.
blender -b --factory-startup --python-exit-code 2 -P export_roundtrip.py -- UPSTREAM SOURCE CANDIDATE
Run only in a disposable Blender process. Never use the source as output.
"""
import hashlib
from pathlib import Path
import subprocess
import sys
import bpy

PIN = '389f28addc79b87b28764898e38e7bf408d14b77'
args = sys.argv[sys.argv.index('--') + 1:]
if len(args) != 3:
    raise ValueError('Expected UPSTREAM SOURCE CANDIDATE')
upstream, source = [Path(p).resolve(strict=True) for p in args[:2]]
candidate = Path(args[2]).resolve()
if candidate.exists() or candidate == source:
    raise ValueError('Candidate must be a new path distinct from source')
actual = subprocess.check_output(['git', '-C', str(upstream), 'rev-parse', 'HEAD'], text=True).strip()
if actual != PIN:
    raise ValueError('Unreviewed upstream revision: ' + actual)
if subprocess.check_output(['git', '-C', str(upstream), 'status', '--porcelain'], text=True).strip():
    raise ValueError('Upstream checkout must be clean')
before = hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
sys.path.insert(0, str(upstream / 'skills/blender-export-pipelines/scripts'))
import export_asset
result = export_asset.run(preset='godot', objects=[o.name for o in bpy.context.scene.objects], out=str(candidate))
if not result.get('ok') or not candidate.is_file():
    raise RuntimeError('Export failed: ' + repr(result))
if hashlib.sha256(source.read_bytes()).hexdigest() != before:
    raise RuntimeError('Source changed')
print('ROUNDTRIP_EXPORT', bpy.app.version_string, before, result)
