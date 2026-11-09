"""Preserve source normal attribute after algebraic position/bind recovery.

Explicit source attribute preservation, not a pure Blender normal round trip.
Positions and motions are never copied. Geometry/weights/material/topology must
match before any byte is written. Ambiguous distinct normal directions fail.
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


def records(g):
    normals, pointers, triangles = [], [], []
    offset = 0
    for node in g.nodes:
        if 'mesh' not in node or 'skin' not in node:
            continue
        for prim in g.d['meshes'][node['mesh']]['primitives']:
            if prim.get('mode',4) != 4 or 'indices' not in prim:
                raise ValueError('Only indexed triangles supported')
            attrs = prim['attributes']
            ns = g.acc(attrs['NORMAL'])
            normals.extend(ns)
            pointers.extend((attrs['NORMAL'], i) for i in range(len(ns)))
            indices = g.acc(prim['indices']).ravel().astype(int)
            if len(indices)%3 or min(indices)<0 or max(indices)>=len(ns):
                raise ValueError('Invalid triangles')
            material = g.d['materials'][prim['material']].get('name',str(prim['material']))
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
    for mesh in c.d.get('meshes',[]):
        for primitive in mesh['primitives']:
            other_accessors.update(v for k,v in primitive['attributes'].items() if k!='NORMAL')
            if 'indices' in primitive: other_accessors.add(primitive['indices'])
    for skin in c.d.get('skins',[]): other_accessors.add(skin['inverseBindMatrices'])
    for animation in c.d.get('animations',[]):
        for sampler in animation['samplers']: other_accessors.update((sampler['input'],sampler['output']))
    if normal_accessors & other_accessors:
        raise ValueError('Normal accessor aliases geometry, skin or motion')
    normal_views={c.d['accessors'][i]['bufferView'] for i in normal_accessors}
    for i,accessor in enumerate(c.d['accessors']):
        if i not in normal_accessors and accessor.get('bufferView') in normal_views:
            raise ValueError('Interleaved/shared normal buffer views are not supported')
    for nv in normal_views:
        view=c.d['bufferViews'][nv];a=view.get('byteOffset',0);b=a+view['byteLength']
        for i,other in enumerate(c.d['bufferViews']):
            if i in normal_views: continue
            x=other.get('byteOffset',0);y=x+other['byteLength']
            if max(a,x)<min(b,y): raise ValueError('Normal buffer overlaps other attributes')
    binary=bytearray(c.binary)
    repairs=[]
    primitive_offsets=[]; offset=0
    for node in c.nodes:
        if 'mesh' not in node or 'skin' not in node: continue
        for prim in c.d['meshes'][node['mesh']]['primitives']:
            count=len(c.acc(prim['attributes']['POSITION']))
            material=c.d['materials'][prim['material']].get('name',str(prim['material']))
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
    c.d['buffers'][0]['byteLength']=len(binary)
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
            'restoredRepeatedIndexDegenerateTriangles':repairs,
            'max_pre_preservation_normal_noise_rad':max_noise,
            'positions_or_motion_copied':False,'source_sha256':source_sha,
            'candidate_sha256':hashlib.sha256(content).hexdigest(),
            'matching':'fixed rest position, semantic weights, material; oriented source face corner normal with coincident-direction ambiguity refused; exact material triangle topology/winding'}
