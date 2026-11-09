#!/usr/bin/env python3
"""Inventaire GLB 2 autonome, sans import moteur ni modification de la source.

Périmètre volontaire : un buffer BIN embarqué, accessors non sparse, données non
compressées. Les variantes non prises en charge échouent explicitement. Ce n'est
pas un remplacement du validateur complet Khronos ni une validation visuelle.
Code original du projet, aucune copie du toolkit Scenario.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import sys
import tempfile


class InventoryError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise InventoryError(message)


def integer(value, label, minimum=0):
    require(type(value) is int and value >= minimum, f'{label}: entier >= {minimum} attendu')
    return value


def array(doc, key):
    value = doc.get(key, [])
    require(isinstance(value, list), f'{key}: tableau attendu')
    require(all(isinstance(item, dict) for item in value), f'{key}: objets attendus')
    return value


def index(items, value, label):
    integer(value, label)
    require(value < len(items), f'{label}: indice hors limites ({value})')
    return items[value]


def _json(blob):
    def pairs(entries):
        result = {}
        for key, value in entries:
            require(key not in result, f'JSON: clé dupliquée {key}')
            result[key] = value
        return result
    def invalid(value):
        raise InventoryError(f'JSON: nombre non fini {value}')
    def finite_float(text):
        value = float(text)
        require(math.isfinite(value), 'JSON: nombre flottant hors limites')
        return value
    try:
        value = json.loads(blob.decode('utf-8'), object_pairs_hook=pairs, parse_constant=invalid, parse_float=finite_float)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise InventoryError(f'JSON illisible: {error}') from error
    require(isinstance(value, dict), 'JSON racine: objet attendu')
    return value


def read_glb(data):
    require(len(data) >= 20, 'GLB tronqué: en-tête/chunk manquant')
    magic, version, length = struct.unpack_from('<4sII', data)
    require(magic == b'glTF' and version == 2, 'GLB: signature/version 2 attendue')
    require(length == len(data), 'GLB: longueur déclarée différente du fichier')
    chunks = []
    cursor = 12
    while cursor < length:
        require(cursor + 8 <= length, 'GLB: en-tête de chunk tronqué')
        size, kind = struct.unpack_from('<II', data, cursor)
        cursor += 8
        require(size % 4 == 0 and cursor + size <= length, 'GLB: chunk mal aligné ou tronqué')
        chunks.append((kind, data[cursor:cursor + size]))
        cursor += size
    require(chunks and chunks[0][0] == 0x4E4F534A, 'GLB: premier chunk JSON attendu')
    require(sum(kind == 0x4E4F534A for kind, _ in chunks) == 1, 'GLB: JSON dupliqué')
    bins = [blob for kind, blob in chunks if kind == 0x004E4942]
    require(len(bins) == 1, 'GLB: un unique buffer BIN embarqué est requis')
    return _json(chunks[0][1]), bins[0]


def inventory(source):
    source = Path(source)
    data = source.read_bytes()
    doc, binary = read_glb(data)
    require(isinstance(doc.get('asset'), dict) and doc['asset'].get('version') == '2.0', 'asset.version: 2.0 attendu')
    require(not doc.get('extensionsRequired'), 'Extensions requises non prises en charge')
    buffers = array(doc, 'buffers')
    require(len(buffers) == 1 and 'uri' not in buffers[0], 'Un seul buffer embarqué sans URI est pris en charge')
    buffer_size = integer(buffers[0].get('byteLength'), 'buffers[0].byteLength', 1)
    require(buffer_size <= len(binary) <= buffer_size + 3, 'BIN: taille incohérente avec buffer.byteLength')
    views, accessors = array(doc, 'bufferViews'), array(doc, 'accessors')
    nodes, skins = array(doc, 'nodes'), array(doc, 'skins')
    meshes, materials = array(doc, 'meshes'), array(doc, 'materials')
    for i, view in enumerate(views):
        index(buffers, view.get('buffer'), f'bufferViews[{i}].buffer')
        offset = integer(view.get('byteOffset', 0), f'bufferViews[{i}].byteOffset')
        size = integer(view.get('byteLength'), f'bufferViews[{i}].byteLength', 1)
        require(offset + size <= buffer_size, f'bufferViews[{i}]: débordement BIN')
        if 'byteStride' in view:
            stride = integer(view['byteStride'], f'bufferViews[{i}].byteStride', 4)
            require(stride <= 252 and stride % 4 == 0, f'bufferViews[{i}]: stride invalide')
    components = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    shapes = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT2': 4, 'MAT3': 9, 'MAT4': 16}
    layouts = []
    for i, acc in enumerate(accessors):
        require('sparse' not in acc, f'accessors[{i}]: sparse non pris en charge')
        view = index(views, acc.get('bufferView'), f'accessors[{i}].bufferView')
        component, shape = acc.get('componentType'), acc.get('type')
        require(type(component) is int and component in components and shape in shapes, f'accessors[{i}]: type invalide')
        width = components[component]
        # Matrices byte/short ont un padding de colonne glTF spécifique.
        require(not (shape.startswith('MAT') and width < 4), f'accessors[{i}]: matrice compacte non prise en charge')
        size = width * shapes[shape]
        count = integer(acc.get('count'), f'accessors[{i}].count', 1)
        offset = integer(acc.get('byteOffset', 0), f'accessors[{i}].byteOffset')
        stride = view.get('byteStride', size)
        require(stride >= size and stride % width == 0, f'accessors[{i}]: stride incompatible')
        start = view.get('byteOffset', 0) + offset
        require(start % width == 0, f'accessors[{i}]: offset mal aligné')
        require(offset + (count - 1) * stride + size <= view['byteLength'], f'accessors[{i}]: débordement bufferView')
        layouts.append((start, stride))
        if component == 5126:
            for row in range(count):
                values = struct.unpack_from('<' + 'f' * shapes[shape], binary, start + row * stride)
                require(all(math.isfinite(value) for value in values), f'accessors[{i}]: valeur FLOAT non finie')
    for i, node in enumerate(nodes):
        for field, items in [('mesh', meshes), ('skin', skins)]:
            if field in node:
                index(items, node[field], f'nodes[{i}].{field}')
        children = node.get('children', [])
        require(isinstance(children, list), f'nodes[{i}].children: tableau attendu')
        for child in children:
            index(nodes, child, f'nodes[{i}].children')
    for i, mesh in enumerate(meshes):
        primitives = mesh.get('primitives')
        require(isinstance(primitives, list) and primitives, f'meshes[{i}].primitives: tableau non vide attendu')
        for primitive in primitives:
            require(isinstance(primitive, dict), 'primitive: objet attendu')
            require(isinstance(primitive.get('attributes'), dict), 'primitive.attributes: objet attendu')
            for value in primitive['attributes'].values():
                index(accessors, value, 'primitive.attributes')
            if 'indices' in primitive:
                index(accessors, primitive['indices'], 'primitive.indices')
            if 'material' in primitive:
                index(materials, primitive['material'], 'primitive.material')
    skin_rows = []
    for i, skin in enumerate(skins):
        joints = skin.get('joints')
        require(isinstance(joints, list) and joints, f'skins[{i}].joints: tableau non vide attendu')
        names = [index(nodes, joint, f'skins[{i}].joints').get('name', '') for joint in joints]
        require(len(set(joints)) == len(joints), f'skins[{i}]: joints dupliqués')
        if 'skeleton' in skin:
            index(nodes, skin['skeleton'], f'skins[{i}].skeleton')
        if 'inverseBindMatrices' in skin:
            bind = index(accessors, skin['inverseBindMatrices'], f'skins[{i}].inverseBindMatrices')
            require(bind['type'] == 'MAT4' and bind['componentType'] == 5126 and bind['count'] == len(joints), 'inverseBindMatrices: disposition incompatible')
        skin_rows.append({'index': i, 'name': skin.get('name', ''), 'joint_count': len(joints), 'joint_names': names})
    def times_for(accessor_id):
        acc = index(accessors, accessor_id, 'animation.sampler.input')
        require(acc['componentType'] == 5126 and acc['type'] == 'SCALAR', 'animation.input: FLOAT SCALAR attendu')
        start, stride = layouts[accessor_id]
        values = [struct.unpack_from('<f', binary, start + i * stride)[0] for i in range(acc['count'])]
        require(all(math.isfinite(t) and t >= 0 for t in values), 'animation.input: temps négatif ou non fini')
        require(all(a < b for a, b in zip(values, values[1:])), 'animation.input: temps non strictement croissants')
        return values
    animation_rows = []
    for i, animation in enumerate(array(doc, 'animations')):
        samplers, channels = array(animation, 'samplers'), array(animation, 'channels')
        require(samplers and channels, f'animations[{i}]: samplers/channels vides')
        inputs = []
        for sampler in samplers:
            values = times_for(sampler.get('input'))
            index(accessors, sampler.get('output'), 'animation.sampler.output')
            require(sampler.get('interpolation', 'LINEAR') in ('LINEAR', 'STEP', 'CUBICSPLINE'), 'animation: interpolation invalide')
            inputs.append(values)
        targets = set()
        paths = {}
        for channel in channels:
            si = channel.get('sampler')
            sampler = index(samplers, si, 'animation.channel.sampler')
            target = channel.get('target')
            require(isinstance(target, dict), 'animation.channel.target: objet attendu')
            node = target.get('node')
            index(nodes, node, 'animation.channel.target.node')
            path = target.get('path')
            require(path in ('translation', 'rotation', 'scale', 'weights'), 'animation.channel.target.path invalide')
            require((node, path) not in targets, 'animation: cible dupliquée')
            targets.add((node, path))
            paths[path] = paths.get(path, 0) + 1
            out = accessors[sampler['output']]
            factor = 3 if sampler.get('interpolation') == 'CUBICSPLINE' else 1
            if path != 'weights':
                require(out['componentType'] == 5126 and out['type'] == ('VEC4' if path == 'rotation' else 'VEC3'), 'animation.output: type incompatible avec cible')
                require(out['count'] == len(inputs[si]) * factor, 'animation.output: nombre de clés incohérent')
        start, end = min(v[0] for v in inputs), max(v[-1] for v in inputs)
        animation_rows.append({'index': i, 'name': animation.get('name', ''), 'start_seconds': start, 'end_seconds': end,
                               'duration_seconds': end - start, 'track_count': len(channels), 'sampler_count': len(samplers),
                               'target_node_count': len({node for node, _ in targets}), 'paths': paths, 'loop': 'not_defined_by_gltf'})
    return {'schema': 'oval.animation-inventory.v1', 'source': source.name, 'bytes': len(data),
            'sha256': hashlib.sha256(data).hexdigest(), 'json_sha256': hashlib.sha256(json.dumps(doc, sort_keys=True, separators=(',', ':'), ensure_ascii=False).encode()).hexdigest(),
            'bin_sha256': hashlib.sha256(binary[:buffer_size]).hexdigest(), 'node_count': len(nodes), 'mesh_count': len(meshes),
            'primitive_count': sum(len(mesh['primitives']) for mesh in meshes), 'material_count': len(materials),
            'material_names': [m.get('name', '') for m in materials], 'skin_count': len(skins), 'skins': skin_rows,
            'joint_count': sum(row['joint_count'] for row in skin_rows), 'animation_count': len(animation_rows), 'animations': animation_rows,
            'limits': ['La boucle n’est pas une propriété glTF standard.', 'Inventaire structurel, sans validation visuelle ni certification complète glTF.']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('--output', type=Path, help='JSON UTF-8 écrit atomiquement ; sinon stdout')
    args = parser.parse_args()
    temporary = None
    try:
        require(args.output is None or args.output.resolve() != args.source.resolve(), 'La sortie ne peut pas remplacer la source')
        if args.output is not None and args.output.exists() and args.source.exists():
            require(not args.output.samefile(args.source), 'La sortie ne peut pas être un alias de la source')
        report = inventory(args.source)
        content = json.dumps(report, ensure_ascii=False, indent=2, allow_nan=False) + '\n'
        if args.output:
            with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=args.output.parent, prefix='.inventory-', delete=False) as handle:
                temporary = handle.name
                handle.write(content)
            os.replace(temporary, args.output)
            temporary = None
        else:
            sys.stdout.write(content)
        return 0
    except (InventoryError, OSError, TypeError, KeyError, struct.error) as error:
        print(json.dumps({'ok': False, 'error': str(error)}, ensure_ascii=False), file=sys.stderr)
        return 2
    finally:
        if temporary:
            Path(temporary).unlink(missing_ok=True)


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    sys.exit(main())
