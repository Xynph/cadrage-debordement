"""Blender batch: import source, call pinned EL4CTEO godot preset, publish new GLB.

blender -b --factory-startup --python-exit-code 2 -P export_roundtrip.py -- UPSTREAM SOURCE CANDIDATE
Run only in a disposable Blender process. Never use the source as output.
Preserves the declared glTF rest pose rather than guessing it from inverse bind matrices.
A successful export still requires compare_poses.py; it is not a reception verdict.
"""
import hashlib
import json
import math
import inspect
import struct
import os
from pathlib import Path
import subprocess
import sys
import tempfile

PIN = '389f28addc79b87b28764898e38e7bf408d14b77'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_paths(upstream, source, candidate):
    upstream = Path(upstream).resolve(strict=True)
    source = Path(source).resolve(strict=True)
    raw_candidate = Path(candidate).absolute()
    if os.path.lexists(raw_candidate):
        raise ValueError('Candidate must be a new path distinct from source (including links)')
    candidate = raw_candidate.resolve()
    if candidate == source:
        raise ValueError('Candidate must be distinct from source')
    if not source.is_file() or source.suffix.lower() != '.glb' or candidate.suffix.lower() != '.glb':
        raise ValueError('Source and candidate must be GLB file paths')
    return upstream, source, candidate


def validate_upstream(upstream):
    actual = subprocess.check_output(['git', '-C', str(upstream), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != PIN:
        raise ValueError('Unreviewed upstream revision: ' + actual)
    if subprocess.check_output(['git', '-C', str(upstream), 'status', '--porcelain'], text=True).strip():
        raise ValueError('Upstream checkout must be clean')


def read_glb(path):
    raw = path.read_bytes()
    if len(raw) < 20 or struct.unpack_from('<III', raw) != (0x46546C67, 2, len(raw)):
        raise ValueError('Expected standalone GLB 2.0')
    chunks = []
    offset = 12
    while offset < len(raw):
        size, kind = struct.unpack_from('<II', raw, offset)
        chunks.append((kind, raw[offset + 8:offset + 8 + size]))
        offset += 8 + size
    doc = json.loads(next(data for kind, data in chunks if kind == 0x4E4F534A))
    if len(doc.get('buffers', [])) != 1 or 'uri' in doc['buffers'][0]:
        raise ValueError('Only standalone single-buffer GLB supported')
    return doc, chunks


def preserve_static_scales(source, candidate):
    """Preserve static source scale contract; never copy motion or skin binary.

    This deliberately rejects animated source scales and intentional candidate
    scale edits. It supports round trips of static-scale skeletons, not new rigs.
    """
    a, _ = read_glb(source)
    b, chunks = read_glb(candidate)
    binary = next(data for kind, data in chunks if kind == 0x004E4942)
    if len(a.get('skins', [])) != 1 or len(b.get('skins', [])) != 1:
        raise ValueError('Exactly one source and candidate skin required')
    def named(doc):
        names = [n.get('name') for n in doc['nodes']]
        if None in names or len(set(names)) != len(names):
            raise ValueError('Unique named nodes required')
        return {n['name']: i for i, n in enumerate(doc['nodes'])}
    an, bn = named(a), named(b)
    def parents(doc):
        result = {}
        for i, node in enumerate(doc['nodes']):
            for child in node.get('children', []):
                if child in result:
                    raise ValueError('Multiple parents unsupported')
                result[child] = i
        return result
    ap, bp = parents(a), parents(b)
    aj = [a['nodes'][j]['name'] for j in a['skins'][0]['joints']]
    bj = [b['nodes'][j]['name'] for j in b['skins'][0]['joints']]
    if aj != bj:
        raise ValueError('Skin joint names/order differ')
    contract = set(a['skins'][0]['joints'])
    for joint in tuple(contract):
        while joint in ap:
            joint = ap[joint]
            contract.add(joint)
    changes = []
    for index in sorted(contract):
        original = a['nodes'][index]
        name = original['name']
        if name not in bn:
            raise ValueError('Missing skeleton node: ' + name)
        target_index = bn[name]
        expected_parent = a['nodes'][ap[index]]['name'] if index in ap else None
        actual_parent = b['nodes'][bp[target_index]]['name'] if target_index in bp else None
        if expected_parent != actual_parent:
            raise ValueError('Skeleton hierarchy differs: ' + name)
        target = b['nodes'][target_index]
        if 'matrix' in original or 'matrix' in target:
            raise ValueError('Matrix nodes unsupported for static scale preservation')
        old, new = target.get('scale', [1, 1, 1]), original.get('scale', [1, 1, 1])
        if len(old) != 3 or len(new) != 3 or not all(math.isfinite(v) for v in [*old, *new]):
            raise ValueError('Invalid scale: ' + name)
        if max(abs(x-y) for x, y in zip(old, new)) > 0.0001:
            raise ValueError('Intentional or excessive rest scale change: ' + name)
        if old != new:
            changes.append({'node': name, 'before': old, 'after': new})
        target['scale'] = new
    source_animations = {v['name']: v for v in a.get('animations', [])}
    if len(source_animations) != len(a.get('animations', [])):
        raise ValueError('Unique source animation names required')
    if set(source_animations) != {v['name'] for v in b.get('animations', [])}:
        raise ValueError('Animation names differ')
    # Animated scales require a separate authored workflow; never erase them.
    if any(c['target']['path'] == 'scale' for v in source_animations.values() for c in v['channels']):
        raise ValueError('Animated source scales unsupported; refusing scale restoration')
    removed = []
    for animation in b.get('animations', []):
        keep = []
        for channel in animation['channels']:
            if channel['target']['path'] != 'scale':
                keep.append(channel)
                continue
            node = b['nodes'][channel['target']['node']]
            if node['name'] not in {a['nodes'][i]['name'] for i in contract}:
                raise ValueError('Scale track outside skeleton contract')
            expected = a['nodes'][an[node['name']]].get('scale', [1, 1, 1])
            accessor = b['accessors'][animation['samplers'][channel['sampler']]['output']]
            if accessor.get('sparse') or accessor['componentType'] != 5126 or accessor['type'] != 'VEC3':
                raise ValueError('Unexpected scale accessor')
            view = b['bufferViews'][accessor['bufferView']]
            start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
            stride = view.get('byteStride', 12)
            for key in range(accessor['count']):
                values = struct.unpack_from('<fff', binary, start + key * stride)
                if not all(math.isfinite(v) for v in values) or max(abs(x-y) for x, y in zip(values, expected)) > 0.0001:
                    raise ValueError('Candidate scale animation is not static round-trip noise')
            removed.append({'clip': animation['name'], 'node': node['name'], 'keys': accessor['count']})
        animation['channels'] = keep
    encoded = json.dumps(b, separators=(',', ':')).encode()
    encoded += b' ' * (-len(encoded) % 4)
    payload = b''.join(struct.pack('<II', len(encoded if kind == 0x4E4F534A else data), kind)
                       + (encoded if kind == 0x4E4F534A else data) for kind, data in chunks)
    candidate.write_bytes(struct.pack('<III', 0x46546C67, 2, 12+len(payload)) + payload)
    _, after_chunks = read_glb(candidate)
    after_binary = next(data for kind, data in after_chunks if kind == 0x004E4942)
    if binary != after_binary:
        raise RuntimeError('Scale preservation altered binary geometry/skin/motion')
    return {'rest_scale_changes': changes, 'removed_artificial_scale_tracks': removed,
            'binary_sha256': hashlib.sha256(binary).hexdigest(), 'binary_unchanged': True,
            'copied_rotation_translation_keys': False,
            'skin_reception': 'not established by this metadata-preservation step'}


WEIGHT_METHOD_SHA = '43efd7072bb3fb9aad223032f011ec751cbc7fc0f0707ab4f07bee066cfb7fc0'


def preserve_positive_influences(creator, version):
    """Narrow, reviewed in-memory workaround for Blender 4.3.2's 1e-4 cutoff.

    No installed file is edited. Unknown versions/implementations fail closed.
    Caller restores the code object immediately after the disposable export.
    """
    if tuple(version) != (4, 3, 2):
        raise ValueError('Influence preservation has only been reviewed on Blender 4.3.2')
    function = creator._PrimitiveCreator__get_bone_data
    source_sha = hashlib.sha256(inspect.getsource(function).encode()).hexdigest()
    constants = function.__code__.co_consts
    if source_sha != WEIGHT_METHOD_SHA or constants.count(0.0001) != 1 or 'min_influence' not in function.__code__.co_varnames:
        raise ValueError('Unreviewed Blender influence-threshold implementation')
    original = function.__code__
    function.__code__ = original.replace(co_consts=tuple(0.0 if isinstance(v, float) and v == 0.0001 else v for v in constants))
    return function, original, {'implementation_source_sha256': source_sha,
                                'blender_version': list(version), 'original_min_influence': 0.0001,
                                'new_min_influence': 0.0, 'in_memory_only': True}


def main(args):
    if len(args) != 3:
        raise ValueError('Expected UPSTREAM SOURCE CANDIDATE')
    upstream, source, candidate = validate_paths(*args)
    validate_upstream(upstream)
    before = digest(source)
    import bpy  # Import only after guards; ordinary Python can test input integrity.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(source), guess_original_bind_pose=False)
    sys.path.insert(0, str(upstream / 'skills/blender-export-pipelines/scripts'))
    import export_asset
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from rebind_skin import preserve_bind
    from restore_normals import restore_source_normals
    from io_scene_gltf2.blender.exp.primitive_extract import PrimitiveCreator
    settings = ['export_optimize_animation_size=false']
    candidate.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.roundtrip-', dir=candidate.parent) as td:
        temporary = Path(td) / 'candidate.glb'
        function, original_code, influence_preservation = preserve_positive_influences(PrimitiveCreator, bpy.app.version)
        try:
            result = export_asset.run(preset='godot', objects=[o.name for o in bpy.context.scene.objects],
                                      out=str(temporary), set=settings)
        finally:
            function.__code__ = original_code
        if not result.get('ok') or not temporary.is_file() or not temporary.stat().st_size:
            raise RuntimeError('Export failed: ' + repr(result))
        if digest(source) != before:
            raise RuntimeError('Source changed')
        validate_upstream(upstream)
        raw_candidate_sha = digest(temporary)
        preservation = preserve_static_scales(source, temporary)
        skin_recovery = preserve_bind(source, temporary)
        normal_preservation = restore_source_normals(source, temporary)
        candidate_sha = digest(temporary)
        if digest(source) != before:
            raise RuntimeError('Source changed during scale preservation')
        # Same-directory hard link publishes atomically and refuses an existing target.
        # Unlike replace(), this cannot overwrite a path created during the export.
        os.link(temporary, candidate)
    for record in result.get('files', []):
        record['file'] = str(candidate)
        record['raw_export_summary'] = record.get('summary')
        record['summary'] = export_asset.glb_summary(candidate)
        record['kb'] = round(candidate.stat().st_size/1024, 1)
    print('ROUNDTRIP_EXPORT', json.dumps({
        'blender': bpy.app.version_string, 'upstream_sha': PIN,
        'source_sha256': before, 'candidate_sha256': candidate_sha,
        'import': {'guess_original_bind_pose': False}, 'export_overrides': settings,
        'raw_candidate_sha256': raw_candidate_sha, 'static_scale_preservation': preservation,
        'positive_influence_preservation': influence_preservation,
        'skin_coordinate_recovery': skin_recovery,
        'source_normal_attribute_preservation': normal_preservation,
        'candidate': str(candidate), 'result': result,
        'requires_pose_comparison': True, 'requires_skin_comparison': True,
    }))


if __name__ == '__main__':
    main(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else sys.argv[1:])
