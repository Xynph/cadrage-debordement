"""GLB read-only audit: binary accessors, sparse/normalized data, skin and topology observations."""
import struct,json,hashlib,math,sys
from pathlib import Path

FORMATS={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
WIDTH={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}

def accessor(g,raw,index):
    a=g['accessors'][index];fmt,size=FORMATS[a['componentType']];n=WIDTH[a['type']]
    rows=[[0]*n for _ in range(a['count'])]
    if 'bufferView' in a:
        view=g['bufferViews'][a['bufferView']];offset=view.get('byteOffset',0)+a.get('byteOffset',0)
        stride=view.get('byteStride',n*size)
        for i in range(a['count']):rows[i]=list(struct.unpack_from('<'+fmt*n,raw,offset+i*stride))
    if 'sparse' in a:
        s=a['sparse'];ind=s['indices'];val=s['values'];iform,isize=FORMATS[ind['componentType']]
        io=g['bufferViews'][ind['bufferView']].get('byteOffset',0)+ind.get('byteOffset',0)
        vo=g['bufferViews'][val['bufferView']].get('byteOffset',0)+val.get('byteOffset',0)
        for i in range(s['count']):
            j=struct.unpack_from('<'+iform,raw,io+i*isize)[0]
            assert j<len(rows),'Sparse index out of bounds'
            rows[j]=list(struct.unpack_from('<'+fmt*n,raw,vo+i*n*size))
    if a.get('normalized') and a['componentType']!=5126:
        maximum={5120:127,5121:255,5122:32767,5123:65535,5125:4294967295}[a['componentType']]
        rows=[[max(-1,x/maximum) for x in row] for row in rows]
    return rows

def skin_errors(weights,joints,count):
    assert len(weights)==len(joints)
    invalid=sum(any(not math.isfinite(x) or x<0 or x>1 for x in row) for row in weights)
    sums=sum(not math.isfinite(sum(row)) or abs(sum(row)-1)>.001 for row in weights)
    outside=sum(any(not isinstance(x,int) or x<0 or x>=count for x in row) for row in joints)
    return [invalid,sums,outside]

def read(file):
    data=Path(file).read_bytes();assert data[:4]==b'glTF' and struct.unpack_from('<II',data,4)==(2,len(data))
    offset=12;g=None;raw=b''
    while offset<len(data):
        length,kind=struct.unpack_from('<II',data,offset);offset+=8
        assert length%4==0 and offset+length<=len(data)
        chunk=data[offset:offset+length];offset+=length
        if kind==0x4e4f534a:g=json.loads(chunk)
        elif kind==0x004e4942:raw=chunk
    assert g and not any(x.get('uri') for x in g.get('buffers',[])+g.get('images',[]))
    assert all(len(s['joints'])==53 for s in g.get('skins',[])) and g.get('skins'),'53 joints required'
    errors=[0,0,0];vertices=triangles=0;degenerate=boundary=nonmanifold=0
    for mesh in g.get('meshes',[]):
        for p in mesh['primitives']:
            attrs=p['attributes'];pos=accessor(g,raw,attrs['POSITION']);vertices+=len(pos)
            assert all(math.isfinite(x) for row in pos for x in row)
            if 'WEIGHTS_0' in attrs:
                e=skin_errors(accessor(g,raw,attrs['WEIGHTS_0']),accessor(g,raw,attrs['JOINTS_0']),53)
                errors=[a+b for a,b in zip(errors,e)]
            assert p.get('mode',4)==4,'Triangles required'
            ids=[x[0] for x in accessor(g,raw,p['indices'])] if 'indices' in p else list(range(len(pos)))
            assert len(ids)%3==0 and all(0<=x<len(pos) for x in ids)
            edges={}
            for i in range(0,len(ids),3):
                a,b,c=ids[i:i+3];triangles+=1
                u=[y-x for x,y in zip(pos[a],pos[b])];v=[y-x for x,y in zip(pos[a],pos[c])]
                cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                degenerate+=len({a,b,c})<3 or sum(x*x for x in cross)<1e-20
                for edge in [(a,b),(b,c),(c,a)]:
                    k=tuple(sorted(edge));edges[k]=edges.get(k,0)+1
            boundary+=sum(x==1 for x in edges.values());nonmanifold+=sum(x>2 for x in edges.values())
    matrices=[accessor(g,raw,s['inverseBindMatrices']) for s in g['skins']]
    assert all(math.isfinite(v) for mat in matrices for row in mat for v in row)
    parents={child:i for i,n in enumerate(g['nodes']) for child in n.get('children',[])}
    signature=[(g['nodes'][i].get('name'),g['nodes'][parents[i]].get('name') if i in parents else None) for i in g['skins'][0]['joints']]
    clips=[]
    for animation in g.get('animations',[]):
        for sampler in animation['samplers']:
            for key in ['input','output']:assert all(math.isfinite(x) for row in accessor(g,raw,sampler[key]) for x in row)
            times=[r[0] for r in accessor(g,raw,sampler['input'])];assert all(b>a for a,b in zip(times,times[1:]))
        clips.append(animation.get('name'))
    return {'file':str(file),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'joints':53,'vertices':vertices,'triangles':triangles,'skinErrors':errors,'signature':signature,'inverseBindMatrices':matrices,'clips':clips,'topology':{'degenerateTriangles':degenerate,'boundaryEdgesByIndex':boundary,'nonManifoldEdgesByIndex':nonmanifold,'note':'Observation by index; seams/open garments are not watertight solids'},'pass':not any(errors)}

if __name__=='__main__':
    files=sorted(Path(sys.argv[1]).rglob('*.glb'));results=[read(p) for p in files]
    out=Path(sys.argv[2]);out.write_text(json.dumps({'results':results,'allPass':all(r['pass'] for r in results)},indent=2)+'\n')
    assert len(results)==16,len(results)
    assert all(r['pass'] for r in results)
