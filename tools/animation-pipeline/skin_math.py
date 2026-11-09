"""Raw glTF 2 CPU skin math; requires NumPy and SciPy. No game/calibration writes.
Supports dense LINEAR/STEP animations, at most four influences, one or more skinned meshes.
"""
import json, struct
from pathlib import Path
import numpy as np
def quaternion_matrix(q):
 q=np.asarray(q,dtype=float);q=q/np.linalg.norm(q);x,y,z,w=q
 return np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                  [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                  [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])


class Glb:
 def __init__(self,path):
  r=Path(path).read_bytes();assert r[:4]==b'glTF';n=struct.unpack_from('<I',r,12)[0];self.d=json.loads(r[20:20+n]);self.binary=r[28+n:];self.cache={};self.nodes=self.d['nodes'];self.parents={c:i for i,n in enumerate(self.nodes) for c in n.get('children',[])}
 def acc(self,i):
  if i in self.cache:return self.cache[i]
  a=self.d['accessors'][i];assert not a.get('sparse');v=self.d['bufferViews'][a['bufferView']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']];fmt={5126:'f',5123:'H',5121:'B',5125:'I'}[a['componentType']];size=struct.calcsize(fmt);out=np.array([struct.unpack_from('<'+fmt*n,self.binary,v.get('byteOffset',0)+a.get('byteOffset',0)+k*v.get('byteStride',size*n)) for k in range(a['count'])]);
  if a.get('normalized'):out=out/({5121:255,5123:65535}[a['componentType']])
  self.cache[i]=out;return out
 def world_transforms(self,clip=None,t=0):
  trs={i:{'translation':np.array(n.get('translation',[0,0,0])),'rotation':np.array(n.get('rotation',[0,0,0,1])),'scale':np.array(n.get('scale',[1,1,1]))} for i,n in enumerate(self.nodes)}
  if clip:
   an=next(x for x in self.d['animations'] if x['name']==clip)
   for c in an['channels']:
    sm=an['samplers'][c['sampler']];ts=self.acc(sm['input'])[:,0];vs=self.acc(sm['output']);i=max(0,min(np.searchsorted(ts,t,side='right')-1,len(ts)-1));val=vs[i];path=c['target']['path'];interp=sm.get('interpolation','LINEAR');assert interp in ['LINEAR','STEP']
    if i<len(ts)-1 and interp!='STEP':
     from scipy.spatial.transform import Rotation, Slerp
     f=min(1,max(0,(t-ts[i])/(ts[i+1]-ts[i])));val=Slerp([0,1],Rotation.from_quat(vs[i:i+2]))([f]).as_quat()[0] if path=='rotation' else vs[i]*(1-f)+vs[i+1]*f
    trs[c['target']['node']][path]=val
  world={}
  def w(i):
   if i in world:return world[i]
   if 'matrix' in self.nodes[i]:m=np.array(self.nodes[i]['matrix']).reshape(4,4).T
   else:
    v=trs[i];m=np.eye(4);m[:3,:3]=quaternion_matrix(v['rotation'])@np.diag(v['scale']);m[:3,3]=v['translation']
   world[i]=w(self.parents[i])@m if i in self.parents else m;return world[i]
  return {i:w(i) for i in range(len(self.nodes))}
 def sample(self,clip=None,t=0):
  world=self.world_transforms(clip,t)
  def w(i):return world[i]
  points=[];meta=[]
  for node in self.nodes:
   if 'mesh' not in node or 'skin' not in node:continue
   sk=self.d['skins'][node['skin']];ibs=self.acc(sk['inverseBindMatrices']);names=[self.nodes[j]['name'] for j in sk['joints']];palette=np.array([w(j)@ib.reshape(4,4).T for j,ib in zip(sk['joints'],ibs)])
   for prim in self.d['meshes'][node['mesh']]['primitives']:
    at=prim['attributes'];assert 'JOINTS_1' not in at;v=self.acc(at['POSITION']);js=self.acc(at['JOINTS_0']).astype(int);ws=self.acc(at['WEIGHTS_0']);hp=np.column_stack([v,np.ones(len(v))]);posed=np.zeros((len(v),4))
    for influence in range(js.shape[1]):posed+=ws[:,influence,None]*np.einsum('vij,vj->vi',palette[js[:,influence]],hp)
    points.extend(posed[:,:3]);material=self.d.get('materials',[])[prim['material']].get('name',str(prim['material']))
    for jj,ww in zip(js,ws):meta.append((material,tuple(sorted((names[j],float(weight)) for j,weight in zip(jj,ww) if weight>1e-6))))
  return np.array(points),meta
 def clips(self):return {an['name']:max(float(self.acc(sm['input'])[-1,0]) for sm in an['samplers']) for an in self.d['animations']}
