#!/usr/bin/env python3
"""Compare sampled GLB poses in an isolated Godot project; no game writes.

python compare_poses.py SOURCE CANDIDATE --godot /path/to/godot --out report.json
Add --self-test for source/source and a deliberately modified GLB control.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def negative_glb(source, destination, clips=None):
    """Alter real translation keys by +5cm, keeping valid GLB layout/accessors."""
    raw = Path(source).read_bytes()
    magic, version, total = struct.unpack_from('<III', raw)
    if magic != 0x46546C67 or version != 2 or total != len(raw):
        raise ValueError('Expected valid GLB 2.0')
    chunks = []
    offset = 12
    while offset < len(raw):
        size, kind = struct.unpack_from('<II', raw, offset)
        chunks.append([kind, bytearray(raw[offset + 8:offset + 8 + size])])
        offset += 8 + size
    doc = json.loads(next(data for kind, data in chunks if kind == 0x4E4F534A))
    binary = next(data for kind, data in chunks if kind == 0x004E4942)
    changed = False
    for animation in doc.get('animations', []):
        if clips and animation.get('name') not in clips:
            continue
        for channel in animation['channels']:
            if channel['target']['path'] != 'translation':
                continue
            accessor = doc['accessors'][animation['samplers'][channel['sampler']]['output']]
            if accessor.get('sparse') or accessor['componentType'] != 5126 or accessor['type'] != 'VEC3':
                continue
            view = doc['bufferViews'][accessor['bufferView']]
            start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
            stride = view.get('byteStride', 12)
            for key in range(accessor['count']):
                index = start + key * stride
                value = struct.unpack_from('<f', binary, index)[0]
                struct.pack_into('<f', binary, index, value + 0.05)
            for bound in ('min', 'max'):
                if bound in accessor:
                    accessor[bound][0] += 0.05
            changed = True
            break
        if changed:
            break
    if not changed:
        raise ValueError('No float VEC3 translation keys for a negative control')
    j = json.dumps(doc, separators=(',', ':')).encode()
    j += b' ' * (-len(j) % 4)
    for chunk in chunks:
        if chunk[0] == 0x4E4F534A:
            chunk[1] = bytearray(j)
    data = b''.join(struct.pack('<II', len(content), kind) + content for kind, content in chunks)
    Path(destination).write_bytes(struct.pack('<III', magic, version, 12 + len(data)) + data)


def compare(godot, source, candidate, samples, thresholds, clips=None):
    with tempfile.TemporaryDirectory(prefix='oval-pose-') as td:
        p = Path(td)
        (p / 'project.godot').write_text('config_version=5\n[application]\nconfig/name="Isolated pose comparison"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        script = p / 'compare.gd'
        shutil.copyfile(Path(__file__).with_suffix('.gd'), script)
        output = p / 'result.json'
        env = dict(os.environ)
        for name in ('XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME'):
            env[name] = str(p / name.lower())
        command = [godot, '--headless', '--path', str(p), '--script', str(script), '--',
                   str(source), str(candidate), str(output), str(samples), *map(str, thresholds), json.dumps(clips or [])]
        process = subprocess.run(command, capture_output=True, text=True, timeout=120, env=env)
        logs = process.stdout + '\n' + process.stderr
        if any(marker in logs for marker in ('SCRIPT ERROR:', 'Parse Error:', 'ERROR:')):
            raise RuntimeError('Godot emitted an error:\n' + logs)
        if process.returncode not in (0, 1) or not output.is_file():
            raise RuntimeError(f'Godot did not produce a verdict ({process.returncode}):\n{process.stdout}\n{process.stderr}')
        report = json.loads(output.read_text())
        if (process.returncode == 0) != report['passed']:
            raise RuntimeError('Godot exit status disagrees with JSON verdict')
        report['source_sha256'] = sha(source)
        report['candidate_sha256'] = sha(candidate)
        return report


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('source', type=Path)
    ap.add_argument('candidate', type=Path)
    ap.add_argument('--godot', default=shutil.which('godot') or 'godot')
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--samples', type=int, default=9)
    ap.add_argument('--position-units', type=float, default=0.0001)
    ap.add_argument('--rotation-rad', type=float, default=0.001)
    ap.add_argument('--scale', type=float, default=0.0001)
    ap.add_argument('--self-test', action='store_true')
    ap.add_argument('--clip', action='append', default=[], help='Exact clip name; repeat for an explicitly partial comparison')
    args = ap.parse_args()
    if args.samples < 2 or not all(math.isfinite(x) and x > 0 for x in (args.position_units, args.rotation_rad, args.scale)):
        ap.error('samples >= 2 and positive thresholds required')
    if any(not name.strip() for name in args.clip) or len(set(args.clip)) != len(args.clip):
        ap.error('clip names must be nonempty and unique')
    source = args.source.resolve(strict=True)
    candidate = args.candidate.resolve(strict=True)
    output = args.out.resolve()
    if any(output == p or (output.exists() and output.samefile(p)) for p in (source, candidate)):
        ap.error('output must not alias source or candidate')
    if output.suffix.lower() != '.json':
        ap.error('output must use .json extension')
    before = {p: sha(p) for p in (source, candidate)}
    limits = (args.position_units, args.rotation_rad, args.scale)
    report = {'candidate': compare(args.godot, source, candidate, args.samples, limits, args.clip)}
    if args.self_test and not any('Requested clip missing' in e for e in report['candidate']['errors']):
        report['identity'] = compare(args.godot, source, source, args.samples, limits, args.clip)
        with tempfile.TemporaryDirectory(prefix='oval-negative-') as td:
            negative = Path(td) / 'negative.glb'
            negative_glb(source, negative, args.clip)
            report['negative_control'] = compare(args.godot, source, negative, args.samples, limits, args.clip)
        report['self_test_passed'] = report['identity']['passed'] and not report['negative_control']['passed']
    if args.self_test and 'self_test_passed' not in report:
        report['self_test_passed'] = False
        report['self_test_error'] = 'Requested clip missing; controls not run'
    if any(sha(p) != digest for p, digest in before.items()):
        raise RuntimeError('An input changed during comparison')
    report['inputs_unchanged'] = True
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode='w', dir=args.out.parent, prefix='.pose-', suffix='.json', delete=False) as handle:
        temp_output = Path(handle.name)
        handle.write(json.dumps(report, indent=2) + '\n')
    try:
        os.replace(temp_output, args.out)
    finally:
        temp_output.unlink(missing_ok=True)
    print(json.dumps(report, indent=2))
    return 0 if report['candidate']['passed'] and report.get('self_test_passed', True) else 1


if __name__ == '__main__':
    raise SystemExit(main())
