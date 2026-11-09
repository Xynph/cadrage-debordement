"""Undo Blender's weighted rest rebake and preserve original glTF bind basis.

Geometry is recovered by algebra from candidate vertices, never copied from source.
Call only after semantic skeleton, rest scales and source influence preservation.
Requires NumPy/SciPy via skin_math. Singular or ill-conditioned blends are rejected.
"""
import hashlib
import json
import os
from pathlib import Path
import struct
import tempfile
import numpy as np
from skin_math import Glb


def preserve_bind(source, candidate):
    source, candidate = Path(source).resolve(), Path(candidate).resolve()
    if source == candidate or source.samefile(candidate):
        raise ValueError('Candidate aliases source')
    source_before = hashlib.sha256(source.read_bytes()).hexdigest()
    s, c = Glb(source), Glb(candidate)
    source_world, candidate_world = s.world_transforms(), c.world_transforms()
    source_skins = s.d.get('skins', [])
    if len(source_skins) != 1 or len(c.d.get('skins', [])) != 1:
        raise ValueError('Reviewed path requires exactly one skin in each input')
    ss, cs = source_skins[0], c.d['skins'][0]
    source_names = [s.nodes[i]['name'] for i in ss['joints']]
    candidate_names = [c.nodes[i]['name'] for i in cs['joints']]
    if len(set(source_names)) != len(source_names) or set(source_names) != set(candidate_names):
        raise ValueError('Semantic skin joints are not one-to-one')
    si, ci = s.acc(ss['inverseBindMatrices']), c.acc(cs['inverseBindMatrices'])
    source_palettes = {name: source_world[i] @ matrix.reshape(4, 4).T
                       for name, i, matrix in zip(source_names, ss['joints'], si)}
    candidate_palettes = {name: candidate_world[i] @ matrix.reshape(4, 4).T
                          for name, i, matrix in zip(candidate_names, cs['joints'], ci)}
    binary = bytearray(c.binary)
    conditions, vertices = [], 0

    def write_accessor(index, values):
        accessor = c.d['accessors'][index]
        if accessor['componentType'] != 5126 or accessor.get('sparse'):
            raise ValueError('Expected dense float accessor')
        view = c.d['bufferViews'][accessor['bufferView']]
        columns = len(values[0])
        start = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        stride = view.get('byteStride', 4 * columns)
        if not np.all(np.isfinite(values)):
            raise ValueError('Non-finite recovered data')
        for k, value in enumerate(values):
            struct.pack_into('<' + 'f' * columns, binary, start + k * stride, *value)
        for bound, fn in [('min', np.min), ('max', np.max)]:
            if bound in accessor:
                accessor[bound] = fn(values, axis=0).tolist()

    seen = set()
    for node in c.nodes:
        if 'mesh' not in node or 'skin' not in node:
            continue
        if node['skin'] != 0:
            raise ValueError('Unexpected skin index')
        for primitive in c.d['meshes'][node['mesh']]['primitives']:
            attributes = primitive['attributes']
            signature = tuple(attributes[key] for key in ('POSITION', 'NORMAL', 'JOINTS_0', 'WEIGHTS_0'))
            if signature in seen:
                continue
            seen.add(signature)
            if 'JOINTS_1' in attributes:
                raise ValueError('More than four influences not reviewed')
            positions, normals = c.acc(attributes['POSITION']), c.acc(attributes['NORMAL'])
            joints, weights = c.acc(attributes['JOINTS_0']).astype(int), c.acc(attributes['WEIGHTS_0'])
            if (not np.all(np.isfinite(weights)) or np.any(weights < 0)
                    or np.any(joints < 0) or np.any(joints >= len(candidate_names))
                    or np.any(np.abs(weights.sum(axis=1) - 1) > 1e-5)):
                raise ValueError('Invalid skin influences')
            output_positions, output_normals = [], []
            for position, normal, indices, influences in zip(positions, normals, joints, weights):
                source_blend = sum(weight * source_palettes[candidate_names[j]]
                                   for j, weight in zip(indices, influences))
                candidate_blend = sum(weight * candidate_palettes[candidate_names[j]]
                                      for j, weight in zip(indices, influences))
                condition = float(np.linalg.cond(source_blend))
                if not np.isfinite(condition) or condition >= 1e6:
                    raise ValueError('Singular or ill-conditioned rest blend')
                conditions.append(condition)
                change = np.linalg.solve(source_blend, candidate_blend)
                recovered = change @ np.r_[position, 1]
                if abs(recovered[3] - 1) > 1e-5:
                    raise ValueError('Invalid homogeneous position')
                output_positions.append(recovered[:3])
                # Blender glTF importer bakes normals with the weighted 3x3, not inverse transpose.
                # Undo that actual operation with the same inverse coordinate map.
                recovered_normal = change[:3, :3] @ normal
                length = np.linalg.norm(recovered_normal)
                if not np.isfinite(length) or length <= 1e-12:
                    raise ValueError('Invalid normal')
                output_normals.append(recovered_normal / length)
            write_accessor(attributes['POSITION'], np.array(output_positions))
            write_accessor(attributes['NORMAL'], np.array(output_normals))
            vertices += len(output_positions)
    write_accessor(cs['inverseBindMatrices'], np.array([si[source_names.index(name)] for name in candidate_names]))
    document = json.dumps(c.d, separators=(',', ':')).encode()
    document += b' ' * (-len(document) % 4)
    chunks = (struct.pack('<II', len(document), 0x4E4F534A) + document
              + struct.pack('<II', len(binary), 0x004E4942) + binary)
    content = struct.pack('<III', 0x46546C67, 2, 12 + len(chunks)) + chunks
    if hashlib.sha256(source.read_bytes()).hexdigest() != source_before:
        raise RuntimeError('Source changed')
    with tempfile.NamedTemporaryFile(dir=candidate.parent, delete=False, suffix='.glb') as handle:
        tmp = Path(handle.name)
        handle.write(content)
    try:
        os.replace(tmp, candidate)
    finally:
        tmp.unlink(missing_ok=True)
    return {'vertices_recovered': vertices, 'max_condition': max(conditions),
            'method': 'inverse blended rest transform; source bind matrices remapped by semantic joint name',
            'source_sha256': source_before, 'candidate_sha256': hashlib.sha256(content).hexdigest()}
