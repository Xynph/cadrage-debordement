from pathlib import Path
import json
import struct
import sys

import numpy as np


def parse(path):
    raw = path.read_bytes()
    size = struct.unpack_from('<I', raw, 12)[0]
    return json.loads(raw[20:20 + size]), raw[28 + size:]


def array(glb, index):
    doc, bin_data = glb
    accessor = doc['accessors'][index]
    component = {5120: 'i1', 5121: 'u1', 5122: '<i2', 5123: '<u2', 5125: '<u4', 5126: '<f4'}
    dtype = np.dtype(component[accessor['componentType']])
    count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[accessor['type']]
    def buffer(view_id, offset, rows, columns, value_type):
        view = doc['bufferViews'][view_id]
        start = view.get('byteOffset', 0) + offset
        return np.ndarray((rows, columns), value_type, bin_data, start, (view.get('byteStride', columns*value_type.itemsize), value_type.itemsize))

    if 'bufferView' in accessor:
        result = buffer(accessor['bufferView'],accessor.get('byteOffset',0),accessor['count'],count,dtype)
    else:
        result = np.zeros((accessor['count'],count),dtype=dtype)
    sparse = accessor.get('sparse')
    if sparse:
        ids = sparse['indices']
        values = sparse['values']
        indexes = buffer(ids['bufferView'],ids.get('byteOffset',0),sparse['count'],1,np.dtype(component[ids['componentType']]))[:,0]
        result = result.copy()
        result[indexes] = buffer(values['bufferView'],values.get('byteOffset',0),sparse['count'],count,dtype)
    return result


def equal_payloads(first, second, old, new):
    return np.array_equal(array(first, old), array(second, new))


base, trial = [parse(Path(name)) for name in sys.argv[1:]]
doc_a, bin_a = base
doc_b, bin_b = trial
def nodes(doc):
    names=[node['name'] for node in doc['nodes']]
    return {node['name']:{**node,'children':[names[c] for c in node.get('children',[]) if names[c]!='AttacheCarnet']}
            for node in doc['nodes'] if node['name']!='AttacheCarnet'}

assert nodes(doc_a)==nodes(doc_b),'hierarchy or rest pose changed'
attachment = next(n for n in doc_b['nodes'] if n['name']=='Hand.L')
assert [doc_b['nodes'][i]['name'] for i in attachment['children']]==['AttacheCarnet']
assert doc_a['materials']==doc_b['materials']
for sa,sb in zip(doc_a['skins'],doc_b['skins'],strict=True):
    assert [doc_a['nodes'][i]['name'] for i in sa['joints']]==[doc_b['nodes'][i]['name'] for i in sb['joints']]
    assert equal_payloads(base,trial,sa['inverseBindMatrices'],sb['inverseBindMatrices'])
for ia,ib in zip(doc_a['images'],doc_b['images'],strict=True):
    va,vb = [g[0]['bufferViews'][img['bufferView']] for g,img in [(base,ia),(trial,ib)]]
    assert bin_a[va['byteOffset']:va['byteOffset']+va['byteLength']]==bin_b[vb['byteOffset']:vb['byteOffset']+vb['byteLength']]

def track_map(doc,animation):
    return {(doc['nodes'][channel['target']['node']]['name'],channel['target']['path']):animation['samplers'][channel['sampler']]
            for channel in animation['channels']}

clips_a={clip['name']:clip for clip in doc_a['animations']}
clips_b={clip['name']:clip for clip in doc_b['animations']}
assert set(clips_b)-set(clips_a)=={'Carnet'}
tracks=0
for name, clip in clips_a.items():
    ta,tb=track_map(doc_a,clip),track_map(doc_b,clips_b[name])
    assert ta.keys()==tb.keys()
    for key,a in ta.items():
        b=tb[key]
        assert a.get('interpolation')==b.get('interpolation')
        for field in ('input','output'):
            assert equal_payloads(base,trial,a[field],b[field]),(name,key,field)
        tracks+=1
carnet_tracks=track_map(doc_b,clips_b['Carnet'])
assert len(carnet_tracks)==60

morph_arrays=0
affected=0
for ma,mb in zip(doc_a['meshes'],doc_b['meshes'],strict=True):
    assert ma['name']==mb['name']
    target_names_a=ma['extras']['targetNames']
    target_names_b=mb['extras']['targetNames']
    append = ma['name']=='Gabi_Mesh'
    assert target_names_b==target_names_a+(['CorrectionCarnet'] if append else [])
    assert not any(mb['weights'])
    for pa,pb in zip(ma['primitives'],mb['primitives'],strict=True):
        assert pa.get('material')==pb.get('material')
        assert equal_payloads(base,trial,pa['indices'],pb['indices'])
        assert pa['attributes'].keys()==pb['attributes'].keys()
        for attr, old_accessor in pa['attributes'].items():
            assert equal_payloads(base,trial,old_accessor,pb['attributes'][attr]),(ma['name'],attr)
        for ta,tb in zip(pa['targets'],pb['targets']):
            for field in ta:
                assert equal_payloads(base,trial,ta[field],tb[field]),(ma['name'],field)
                morph_arrays+=1
        if append:
            delta=array(trial,pb['targets'][-1]['POSITION'])
            moved=np.any(delta!=0,axis=1)
            pos=array(base,pa['attributes']['POSITION'])
            assert np.all(pos[moved,0]>.12) and np.all((pos[moved,1]>1.04)&(pos[moved,1]<1.44))
            affected+=int(moved.sum())
assert affected>1000
print(json.dumps({'old_clips_identical':list(clips_a),'old_tracks_identical':tracks,
 'studio_tracks':len(carnet_tracks),'bones_identical':len(doc_a['skins'][0]['joints']),
 'old_morph_arrays_identical':morph_arrays,'base_mesh_indices_and_vertex_arrays_identical':True,
 'textures_identical':len(doc_a['images']),'corrective_export_vertices':affected},indent=2))
