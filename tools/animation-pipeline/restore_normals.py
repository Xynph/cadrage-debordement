"""Preserve source normal attribute after algebraic position/bind recovery.

Explicit source attribute preservation, not a pure Blender normal round trip.
Positions and motions are never copied. Geometry/weights/material/topology must
match before any byte is written. Extra vertices are removed only when their
attributes are byte-identical and remapping preserves every triangle corner.
"""
from collections import Counter, defaultdict
import hashlib
from itertools import product
import json
import math
import os
from pathlib import Path
import struct
import tempfile
import numpy as np
from skin_math import Glb


def angle(a, b):
    a, b = np.asarray(a, float), np.asarray(b, float)
    la, lb = np.linalg.norm(a), np.linalg.norm(b)
    if not np.isfinite(a).all() or not np.isfinite(b).all() or min(la, lb) < 1e-10:
        raise ValueError('Invalid normal')
    a, b = a/la, b/lb
    return float(np.arctan2(np.linalg.norm(np.cross(a,b)), np.dot(a,b)))


def skinned_primitives(mesh):
    for node in mesh.nodes:
        if 'mesh' not in node or 'skin' not in node:
            continue
        for primitive in mesh.d['meshes'][node['mesh']]['primitives']:
            index = primitive['material']
            yield mesh.d['materials'][index].get('name', str(index)), primitive


def accessor_rows(document, binary, index):
    accessor = document['accessors'][index]
    if 'bufferView' not in accessor or 'sparse' in accessor or 'extensions' in accessor:
        raise ValueError('Vertex compaction requires dense accessors')
    view = document['bufferViews'][accessor['bufferView']]
    components = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}.get(accessor['type'])
    width = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}.get(accessor['componentType'])
    if view['buffer'] != 0 or 'extensions' in view or not components or not width:
        raise ValueError('Vertex compaction does not support this accessor layout')
    size = components * width
    view_start = view.get('byteOffset', 0)
    view_end = view_start + view['byteLength']
    start = view_start + accessor.get('byteOffset', 0)
    stride = view.get('byteStride', size)
    count = accessor['count']
    if not (0 <= view_start <= start <= view_end <= len(binary) and stride >= size
            and count > 0 and start + (count - 1) * stride + size <= view_end):
        raise ValueError('Vertex compaction accessor exceeds its buffer view')
    return [bytes(binary[offset:offset + size]) for offset in range(start, start + count * stride, stride)]


def append_accessor(document, binary, index, rows, target):
    accessor = dict(document['accessors'][index])
    accessor.pop('byteOffset', None)
    binary.extend(b'\0' * (-len(binary) % 4))
    start = len(binary)
    padding = b'\0' * (-len(rows[0]) % 4) if target == 34962 else b''
    for row in rows:
        binary.extend(row + padding)
    view = {'buffer': 0, 'byteOffset': start, 'byteLength': len(binary) - start, 'target': target}
    if padding:
        view['byteStride'] = len(rows[0]) + len(padding)
    accessor.update(bufferView=len(document['bufferViews']), count=len(rows))
    document['bufferViews'].append(view)
    document['accessors'].append(accessor)
    return len(document['accessors']) - 1


def compact_split_vertices(source, candidate, binary, repairs):
    def by_material(mesh):
        groups = defaultdict(list)
        for material, primitive in skinned_primitives(mesh):
            count = mesh.d['accessors'][primitive['attributes']['POSITION']]['count']
            groups[material].append((count, primitive))
        return groups

    originals = by_material(source)
    document = candidate.d
    removed = {}
    for material, group in by_material(candidate).items():
        expected = sorted(count for count, _ in originals[material])
        # With multiple primitives of this material, only identical counts
        # can be confirmed without guessing which source primitive is which.
        if len(set(expected)) == 1 and [count for count, _ in group] == expected:
            continue
        if len(group) != 1 or len(expected) != 1 or len(document['buffers']) != 1:
            raise ValueError(f'Vertex compaction has no unique source primitive for {material}')
        count, primitive = group[0]
        if count < expected[0] or 'targets' in primitive or 'extensions' in primitive:
            raise ValueError(f'Vertex compaction cannot restore the source layout for {material}')
        attributes = primitive['attributes']
        # Include every vertex attribute, even ones the skin comparator does not read.
        vertices = list(zip(*(accessor_rows(document, binary, index) for index in attributes.values()), strict=True))
        unique = {}
        remap = [unique.setdefault(vertex, len(unique)) for vertex in vertices]
        if len(unique) != expected[0]:
            raise ValueError(f'Vertex compaction cannot reach the source count with exact duplicates for {material}')

        index = primitive['indices']
        accessor = document['accessors'][index]
        if accessor['type'] != 'SCALAR' or accessor['componentType'] not in (5121, 5123, 5125) or accessor.get('normalized'):
            raise ValueError('Vertex compaction requires unsigned scalar indices')
        rows = accessor_rows(document, binary, index)
        old = [int.from_bytes(row, 'little') for row in rows]
        new = [remap[i] for i in old]
        for start in range(0, len(old), 3):
            if len(set(new[start:start + 3])) != len(set(old[start:start + 3])):
                raise ValueError(f'Vertex compaction would introduce a repeated corner in {material}')

        # Give the primitive its own accessors rather than modifying shared bytes.
        for name, values in zip(attributes, zip(*unique, strict=True), strict=True):
            attributes[name] = append_accessor(document, binary, attributes[name], values, 34962)
        primitive['indices'] = append_accessor(document, binary, index,
                                               [i.to_bytes(len(rows[0]), 'little') for i in new], 34963)
        document['accessors'][primitive['indices']].update(min=[min(new)], max=[max(new)])
        for repair in repairs:
            if repair['material'] == material:
                repair['candidate_local_indices'] = [remap[i] for i in repair['candidate_local_indices']]
        removed[material] = count - expected[0]
    return removed


def records(g):
    normals, pointers, triangles = [], [], []
    offset = 0
    for material, prim in skinned_primitives(g):
        if prim.get('mode',4) != 4 or 'indices' not in prim:
            raise ValueError('Only indexed triangles supported')
        attrs = prim['attributes']
        ns = g.acc(attrs['NORMAL'])
        normals.extend(ns)
        pointers.extend((attrs['NORMAL'], i) for i in range(len(ns)))
        indices = g.acc(prim['indices']).ravel().astype(int)
        if len(indices)%3 or min(indices)<0 or max(indices)>=len(ns):
            raise ValueError('Invalid triangles')
        triangles.extend((material,tuple(int(i+offset) for i in tri)) for tri in indices.reshape(-1,3))
        offset += len(ns)
    return np.asarray(normals), pointers, triangles


def restore_source_normals(source, candidate, position_epsilon=1e-5, weight_epsilon=1e-5):
    source, candidate = Path(source).resolve(), Path(candidate).resolve()
    if source.samefile(candidate):
        raise ValueError('Candidate aliases source')
    source_sha = hashlib.sha256(source.read_bytes()).hexdigest()
    s,c = Glb(source),Glb(candidate)
    sp,sm=s.sample(); cp,cm=c.sample()
    sn,_,st=records(s); cn,pointers,ct=records(c)
    if not len(sp) or len(sn)!=len(sp) or len(cn)!=len(cp):
        raise ValueError('Invalid vertex/normal counts')
    cells=defaultdict(list)
    def cell(p): return tuple(int(v) for v in np.floor(p/position_epsilon))
    def near(point):
        base=cell(point)
        for delta in product((-1,0,1),repeat=3):
            yield from cells.get(tuple(x+y for x,y in zip(base,delta)),[])
    def equivalent(point,meta,index):
        if meta[0]!=sm[index][0] or np.linalg.norm(point-sp[index])>position_epsilon:
            return False
        a,b=dict(meta[1]),dict(sm[index][1])
        return max(abs(a.get(k,0)-b.get(k,0)) for k in a.keys()|b.keys())<=weight_epsilon
    canonical=[]
    # Geometry/weight/material classes deliberately do not use approximate normals.
    for i,(point,meta) in enumerate(zip(sp,sm)):
        matches=[j for j in near(point) if equivalent(point,meta,j)]
        canonical.append(canonical[min(matches)] if matches else i)
        cells[cell(point)].append(i)
    mapping=[]
    for i,(point,meta) in enumerate(zip(cp,cm)):
        possible={canonical[j] for j in near(point) if equivalent(point,meta,j)}
        if len(possible)!=1:
            raise ValueError('No unique source geometry/weight/material class at candidate vertex '+str(i))
        mapping.append(next(iter(possible)))
    if set(canonical)!=set(mapping):
        raise ValueError('Source geometry is missing from candidate')
    def triangle_key(material, ids):
        ids=tuple(ids)
        return material,min(ids,ids[1:]+ids[:1],ids[2:]+ids[:2])
    expected=Counter(triangle_key(mat,[canonical[i] for i in tri]) for mat,tri in st)
    actual=Counter(triangle_key(mat,[mapping[i] for i in tri]) for mat,tri in ct)
    source_faces=defaultdict(list)
    for material,tri in st:
        source_faces[triangle_key(material,[canonical[i] for i in tri])].append(tri)
    restored=[None]*len(cp)
    def assign(index,normal):
        if restored[index] is not None and angle(restored[index],normal)>1e-5:
            raise ValueError('Shared candidate vertex would require distinct source normal directions')
        restored[index]=normal
    for material,tri in ct:
        ids=tuple(mapping[i] for i in tri)
        options=[]
        for source_tri in source_faces[triangle_key(material,ids)]:
            for shift in range(3):
                aligned=source_tri[shift:]+source_tri[:shift]
                if tuple(canonical[i] for i in aligned)==ids:
                    options.append(tuple(sn[i] for i in aligned))
        if not options: raise ValueError('No oriented source face match')
        first=options[0]
        if any(any(angle(a,b)>1e-5 for a,b in zip(first,other)) for other in options[1:]):
            raise ValueError('Ambiguous distinct normal directions on coincident source faces')
        for index,normal in zip(tri,first): assign(index,normal)
    for i,normal in enumerate(restored):
        if normal is not None: continue
        options=[sn[j] for j,v in enumerate(canonical) if v==mapping[i]]
        if not options or any(angle(options[0],n)>1e-5 for n in options[1:]):
            raise ValueError('Unused candidate vertex has ambiguous source normal')
        restored[i]=options[0]
    max_noise=max(angle(a,b) for a,b in zip(cn,restored))
    if actual-expected:
        raise ValueError('Candidate contains changed/extra material triangles or winding')
    missing = expected-actual
    # Only exact repeated-index source faces may be restored. No area epsilon or
    # general triangle-count exception is allowed.
    source_degenerate = Counter(triangle_key(mat,[canonical[i] for i in tri])
                                for mat,tri in st if len(set(tri))<3)
    if missing-source_degenerate:
        raise ValueError('Nondegenerate source topology is missing')
    normal_accessors={pointer[0] for pointer in pointers}
    other_accessors=set()
    skinned_meshes = {node['mesh'] for node in c.nodes if 'mesh' in node and 'skin' in node}
    unskinned_meshes = {node['mesh'] for node in c.nodes if 'mesh' in node and 'skin' not in node}
    if skinned_meshes & unskinned_meshes:
        raise ValueError('Normal restoration aliases an unskinned mesh')
    for mesh_index, mesh in enumerate(c.d.get('meshes',[])):
        for primitive in mesh['primitives']:
            other_accessors.update(v for k,v in primitive['attributes'].items()
                                   if k != 'NORMAL' or mesh_index not in skinned_meshes)
            for target in primitive.get('targets', []):
                other_accessors.update(target.values())
            if 'indices' in primitive: other_accessors.add(primitive['indices'])
    for skin in c.d.get('skins',[]): other_accessors.add(skin['inverseBindMatrices'])
    for animation in c.d.get('animations',[]):
        for sampler in animation['samplers']: other_accessors.update((sampler['input'],sampler['output']))
    if normal_accessors & other_accessors:
        raise ValueError('Normal accessor aliases geometry, skin or motion')
    normal_views={c.d['accessors'][i]['bufferView'] for i in normal_accessors}
    if len(normal_views) != len(normal_accessors):
        raise ValueError('Distinct normal accessors share a buffer view')
    for i,accessor in enumerate(c.d['accessors']):
        sparse = accessor.get('sparse', {})
        referenced_views = {accessor.get('bufferView'), sparse.get('indices', {}).get('bufferView'),
                            sparse.get('values', {}).get('bufferView')}
        if i not in normal_accessors and referenced_views & normal_views:
            raise ValueError('Interleaved/shared normal buffer views are not supported')
    for nv in normal_views:
        view=c.d['bufferViews'][nv];a=view.get('byteOffset',0);b=a+view['byteLength']
        for i,other in enumerate(c.d['bufferViews']):
            if i == nv: continue
            x=other.get('byteOffset',0);y=x+other['byteLength']
            if max(a,x)<min(b,y): raise ValueError('Normal buffer overlaps other attributes')
    binary=bytearray(c.binary)
    repairs=[]
    primitive_offsets=[]; offset=0
    for material, prim in skinned_primitives(c):
        count=len(c.acc(prim['attributes']['POSITION']))
        primitive_offsets.append((prim,offset,count,material))
        offset+=count
    for (material,corners),count in missing.items():
        source_options=[]
        for source_tri in source_faces[(material,corners)]:
            if len(set(source_tri))>=3: continue
            for shift in range(3):
                aligned=source_tri[shift:]+source_tri[:shift]
                if tuple(canonical[i] for i in aligned)==corners:
                    source_options.append(tuple(sn[i] for i in aligned))
        if not source_options: raise ValueError('No exact repeated-index source normal corners')
        directions=source_options[0]
        if any(any(angle(a,b)>1e-5 for a,b in zip(directions,other)) for other in source_options[1:]):
            raise ValueError('Ambiguous degenerate source normal corners')
        possible=[]
        for prim,offset,length,mat in primitive_offsets:
            if mat!=material: continue
            indices=[]
            for corner,direction in zip(corners,directions):
                matches=[index-offset for index in range(offset,offset+length)
                         if mapping[index]==corner and angle(restored[index],direction)<1e-5]
                if not matches: break
                indices.append(min(matches))
            if len(indices)==3: possible.append((prim,indices))
        if len(possible)!=1:
            raise ValueError('Repeated-index face has no unique candidate primitive mapping')
        prim,indices=possible[0]
        if len(set(indices))>=3:
            raise ValueError('Degenerate repair would create a nondegenerate triangle')
        old_indices=c.acc(prim['indices']).ravel().astype(int).tolist()
        new_indices=old_indices+indices*count
        binary.extend(b'\0'*(-len(binary)%4)); start=len(binary)
        binary.extend(struct.pack('<'+'I'*len(new_indices),*new_indices))
        view_index=len(c.d['bufferViews'])
        c.d['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':4*len(new_indices),'target':34963})
        accessor_index=len(c.d['accessors'])
        c.d['accessors'].append({'bufferView':view_index,'componentType':5125,'count':len(new_indices),'type':'SCALAR','min':[min(new_indices)],'max':[max(new_indices)]})
        prim['indices']=accessor_index
        repairs.append({'material':material,'source_canonical_corners':list(corners),
                        'candidate_local_indices':indices,'count':count,'reason':'exact repeated-index zero-area source face lost on Blender import'})
    writes={}
    for pointer,normal in zip(pointers,restored):
        if pointer in writes and not np.array_equal(writes[pointer],normal):
            raise ValueError('Shared normal accessor has incompatible source directions')
        writes[pointer]=normal
    for (accessor_index,row),normal in writes.items():
        accessor=c.d['accessors'][accessor_index]
        if accessor['componentType']!=5126 or accessor['type']!='VEC3' or accessor.get('sparse'):
            raise ValueError('Expected dense float normals')
        view=c.d['bufferViews'][accessor['bufferView']]
        offset=view.get('byteOffset',0)+accessor.get('byteOffset',0)+row*view.get('byteStride',12)
        struct.pack_into('<fff',binary,offset,*normal)
    for accessor_index in {p[0] for p in pointers}:
        accessor=c.d['accessors'][accessor_index]
        rows=[v for (index,_),v in writes.items() if index==accessor_index]
        for bound,fn in [('min',np.min),('max',np.max)]:
            if bound in accessor: accessor[bound]=fn(rows,axis=0).tolist()
    compacted = compact_split_vertices(s, c, binary, repairs)
    binary.extend(b'\0' * (-len(binary) % 4))
    c.d['buffers'][0]['byteLength']=len(binary)
    document=json.dumps(c.d,separators=(',',':')).encode();document+=b' '*(-len(document)%4)
    chunks=struct.pack('<II',len(document),0x4E4F534A)+document+struct.pack('<II',len(binary),0x004E4942)+binary
    content=struct.pack('<III',0x46546C67,2,12+len(chunks))+chunks
    if hashlib.sha256(source.read_bytes()).hexdigest()!=source_sha:
        raise RuntimeError('Source changed during normal preservation')
    with tempfile.NamedTemporaryFile(dir=candidate.parent,delete=False,suffix='.glb') as handle:
        tmp=Path(handle.name);handle.write(content)
    try: os.replace(tmp,candidate)
    finally: tmp.unlink(missing_ok=True)
    return {'preservationSourceNormals':True,'normal_vertices':len(cp),
            'source_normal_vertices':len(sp),'triangles_verified':sum(expected.values()),
            'compacted_vertices_by_material':compacted,
            'restoredRepeatedIndexDegenerateTriangles':repairs,
            'max_pre_preservation_normal_noise_rad':max_noise,
            'positions_or_motion_copied':False,'source_sha256':source_sha,
            'candidate_sha256':hashlib.sha256(content).hexdigest(),
            'matching':'fixed rest position, semantic weights, material; oriented source face corner normal with coincident-direction ambiguity refused; exact material triangle topology/winding'}
