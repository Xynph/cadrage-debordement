#!/usr/bin/env python3
# Netteté de la tête de Gabi (demande de Léo, 12 novembre 2026) : le visage, la barbe, la moustache, les sourcils
# et les cheveux n'occupaient qu'une petite zone de la texture 2K du corps (Material_0) : flou de près.
# La tête reçoit sa propre texture 2K (matériau Gabi_Tete, 4e primitive de Mesh_0) :
#   1. deplier : triangles de la tête (y > 1,30 m, hors chemise, plus grande composante) dépliés à part
#      (Blender, projection intelligente ANGLE_PROJECTION rad), îlots du visage agrandis (AGRANDIR_VISAGE) ;
#      ≈ 2,8 texels/mm au visage contre ≈ 0,7 avant ;
#   2. cuire : couleur actuelle re-cuite vers la nouvelle UV (bilinéaire, texel par texel), puis détail réel :
#      - mèches directionnelles (bruit 3D étiré le long de la pousse) : sourcils vers la tempe, moustache vers le
#        bas et l'extérieur, barbe vers le bas, cheveux suivant les bandes de la texture d'origine ;
#      - la barbe continue sous la lèvre inférieure et au centre du menton (zone claire et rosée d'origine) ;
#      - front et tempes lisses (pas de mèches hors de la chevelure et des sourcils) ;
#      - peau : grain léger (pores) et variations de teinte ;
#      - carte de normales (relief des mèches et du grain, composée avec la carte de normales d'origine) ;
#   3. appliquer : ajoute la primitive Gabi_Tete (mêmes sommets, poids, formes d'expression) et retire ces
#      triangles de Material_0 ; textures en JPEG (couleur q90, normales q92, occlusion 1K) ; la coque des lèvres
#      (M_Gabi_V3_Levres) est repeinte (1024×512) avec la peau de la nouvelle texture hors du contour des lèvres.
# Usage :
#   python3 nettete-tete-gabi.py preparer <gabi.glb> <dossier de travail>        (pip install bpy opencv-python scipy pygltflib)
#   python3 nettete-tete-gabi.py appliquer <dossier de travail> <entrée.glb> <sortie.glb>
# preparer part du gabi.glb sans tête dédiée (sortie de retoucher-teint-gabi.py) ; appliquer vaut pour le Gabi
# d'origine et pour le Gabi Mixamo exporté (Mesh_0 identique : mêmes sommets, mêmes indices).
# Mémoire : environ 2,7 Go au plus pendant « preparer ».
import sys, io, os, json, struct
import numpy as np
from PIL import Image
import pygltflib as pg

ANGLE_PROJECTION = 1.4      # rad, projection intelligente de Blender
AGRANDIR_VISAGE = 0.8       # îlots du visage agrandis de 80 % avant l'empaquetage
LARGEUR_MECHE = 0.00032     # m, taille du bruit transverse aux mèches
CONTRASTE_MECHES = 0.22     # variation de luminosité des mèches
RELIEF_MECHES = 0.00012     # m, relief des mèches (carte de normales)

CT={5126:np.float32,5123:np.uint16,5125:np.uint32,5121:np.uint8,5122:np.int16}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
CT={5126:np.float32,5123:np.uint16,5125:np.uint32,5121:np.uint8,5122:np.int16}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
class GLB:
    def __init__(s,path):
        d=open(path,'rb').read(); l=struct.unpack('<I',d[12:16])[0]
        s.j=json.loads(d[20:20+l]); o=20+l; bl=struct.unpack('<I',d[o:o+4])[0]; s.bin=bytearray(d[o+8:o+8+bl])
    def acc(s,i):
        a=s.j['accessors'][i]; bv=s.j['bufferViews'][a['bufferView']]
        off=bv.get('byteOffset',0)+a.get('byteOffset',0); n=NC[a['type']]; dt=np.dtype(CT[a['componentType']])
        st=bv.get('byteStride',0) or n*dt.itemsize
        if st==n*dt.itemsize:
            return np.frombuffer(bytes(s.bin[off:off+a['count']*st]),dt).reshape(a['count'],n).copy()
        raw=np.frombuffer(bytes(s.bin[off:off+a['count']*st]),np.uint8).reshape(a['count'],st)[:,:n*dt.itemsize]
        return raw.copy().view(dt).reshape(a['count'],n)
    def image(s,i):
        bv=s.j['bufferViews'][s.j['images'][i]['bufferView']]; o=bv.get('byteOffset',0)
        return bytes(s.bin[o:o+bv['byteLength']])

def rasterize(UVt, N):
    """UVt (T,3,2) en coordonnées glTF [0,1] (v vers le bas). Renvoie tid (N,N) int32 (-1 vide), bary (N,N,3)."""
    tid=-np.ones((N,N),np.int32); bary=np.zeros((N,N,3),np.float32)
    X=UVt*N-0.5  # centres de texels en entiers
    for t in range(len(X)):
        a,b,c=X[t]
        x0=int(np.floor(min(a[0],b[0],c[0]))); x1=int(np.ceil(max(a[0],b[0],c[0])))
        y0=int(np.floor(min(a[1],b[1],c[1]))); y1=int(np.ceil(max(a[1],b[1],c[1])))
        x0=max(x0,0); y0=max(y0,0); x1=min(x1,N-1); y1=min(y1,N-1)
        if x1<x0 or y1<y0: continue
        xs,ys=np.meshgrid(np.arange(x0,x1+1),np.arange(y0,y1+1))
        d=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
        if abs(d)<1e-12: continue
        l0=((b[1]-c[1])*(xs-c[0])+(c[0]-b[0])*(ys-c[1]))/d
        l1=((c[1]-a[1])*(xs-c[0])+(a[0]-c[0])*(ys-c[1]))/d
        l2=1-l0-l1
        e=-0.02
        m=(l0>=e)&(l1>=e)&(l2>=e)
        # conservative: also take texels whose centre is within half a texel (bord), only if empty
        m2=(l0>=-0.5/ max(1,np.sqrt(abs(d))))&(l1>=-0.5/max(1,np.sqrt(abs(d))))&(l2>=-0.5/max(1,np.sqrt(abs(d))))
        sel=m|(m2&(tid[ys,xs]<0))
        if not sel.any(): continue
        yy=ys[sel]; xx=xs[sel]
        tid[yy,xx]=t
        L=np.stack([l0[sel],l1[sel],l2[sel]],1); L=np.clip(L,0,None); L/=L.sum(1,keepdims=True)
        bary[yy,xx]=L
    return tid,bary
def dilate(img,mask,it=16):
    """Étend les texels couverts vers l'extérieur (marge des îlots)."""
    import cv2
    img=img.copy(); m=mask.copy().astype(np.uint8)
    k=np.ones((3,3),np.uint8)
    for _ in range(it):
        m2=cv2.dilate(m,k)
        ring=(m2>0)&(m==0)
        if not ring.any(): break
        acc=np.zeros(img.shape,np.float64); cnt=np.zeros(img.shape[:2],np.float64)
        for dy in (-1,0,1):
            for dx in (-1,0,1):
                sm=np.roll(np.roll(m,dy,0),dx,1).astype(bool); si=np.roll(np.roll(img,dy,0),dx,1)
                acc[sm]+=si[sm]; cnt[sm]+=1
        img[ring]=(acc[ring]/cnt[ring][...,None]) if img.ndim==3 else acc[ring]/cnt[ring]
        m=m2
    return img
def bilinear(tex,uv):
    H,W=tex.shape[:2]
    x=(uv[:,0]%1)*W-0.5; y=(uv[:,1]%1)*H-0.5
    x0=np.floor(x).astype(int); y0=np.floor(y).astype(int); fx=(x-x0)[:,None]; fy=(y-y0)[:,None]
    x1=(x0+1)%W; y1=(y0+1)%H; x0%=W; y0%=H
    return (tex[y0,x0]*(1-fx)*(1-fy)+tex[y0,x1]*fx*(1-fy)+tex[y1,x0]*(1-fx)*fy+tex[y1,x1]*fx*fy)

CT={5126:np.float32,5123:np.uint16,5125:np.uint32,5121:np.uint8,5122:np.int16}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
def lire(g,blob,i):
    a=g.accessors[i]; n=NC[a.type]; dt=np.dtype(CT[a.componentType])
    if a.bufferView is not None:
        bv=g.bufferViews[a.bufferView]; off=(bv.byteOffset or 0)+(a.byteOffset or 0); st=bv.byteStride or n*dt.itemsize
        raw=np.frombuffer(bytes(blob[off:off+st*(a.count-1)+n*dt.itemsize]),np.uint8)
        if st==n*dt.itemsize: out=raw.view(dt).reshape(a.count,n).copy()
        else: out=np.stack([raw[k*st:k*st+n*dt.itemsize].view(dt) for k in range(a.count)])
    else: out=np.zeros((a.count,n),dt)
    if a.sparse:
        s=a.sparse; bi=g.bufferViews[s.indices.bufferView]; bv=g.bufferViews[s.values.bufferView]
        idx=np.frombuffer(bytes(blob[(bi.byteOffset or 0)+(s.indices.byteOffset or 0):][:s.count*np.dtype(CT[s.indices.componentType]).itemsize]),CT[s.indices.componentType])
        val=np.frombuffer(bytes(blob[(bv.byteOffset or 0)+(s.values.byteOffset or 0):][:s.count*n*dt.itemsize]),dt).reshape(s.count,n)
        out[idx]=val
    return out
def ecrire(g,blob,data,cible=None,minmax=False,sparse_ok=False):
    data=np.ascontiguousarray(data); 
    while len(blob)%4: blob.append(0)
    ct={np.dtype(np.float32):5126,np.dtype(np.uint16):5123,np.dtype(np.uint32):5125,np.dtype(np.uint8):5121}[data.dtype]
    typ={1:'SCALAR',2:'VEC2',3:'VEC3',4:'VEC4'}[data.shape[1] if data.ndim>1 else 1]
    off=len(blob); blob.extend(data.tobytes())
    g.bufferViews.append(pg.BufferView(buffer=0,byteOffset=off,byteLength=data.nbytes,target=cible))
    acc=pg.Accessor(bufferView=len(g.bufferViews)-1,componentType=ct,count=len(data),type=typ)
    if minmax: acc.min=data.min(0).tolist(); acc.max=data.max(0).tolist()
    g.accessors.append(acc); return len(g.accessors)-1
def ajouter_image(g,blob,octets,mime,nom):
    while len(blob)%4: blob.append(0)
    off=len(blob); blob.extend(octets)
    g.bufferViews.append(pg.BufferView(buffer=0,byteOffset=off,byteLength=len(octets)))
    g.images.append(pg.Image(bufferView=len(g.bufferViews)-1,mimeType=mime,name=nom))
    return len(g.images)-1
def compacter(g, blob):
    refs=[]
    for a in g.accessors:
        if a.bufferView is not None: refs.append((a,'bufferView'))
        if a.sparse: refs.append((a.sparse.indices,'bufferView')); refs.append((a.sparse.values,'bufferView'))
    for im in g.images:
        if im.bufferView is not None: refs.append((im,'bufferView'))
    used=sorted({getattr(o,k) for o,k in refs}); neuf=bytearray(); vues=[]; nouvel={}
    for i in used:
        bv=g.bufferViews[i]
        while len(neuf)%4: neuf.append(0)
        off=len(neuf); neuf.extend(blob[(bv.byteOffset or 0):(bv.byteOffset or 0)+bv.byteLength]); bv.byteOffset=off; nouvel[i]=len(vues); vues.append(bv)
    for o,k in refs: setattr(o,k,nouvel[getattr(o,k)])
    g.bufferViews=vues; return neuf


def deplier(src, dossier):
    import bpy, bmesh
    g=GLB(src)
    p=g.j['meshes'][10]['primitives'][0]
    P=g.acc(p['attributes']['POSITION']); UV=g.acc(p['attributes']['TEXCOORD_0']); I=g.acc(p['indices']).reshape(-1,3)
    mat=g.j['materials'][p['material']]; ti=mat['pbrMetallicRoughness']['baseColorTexture']['index']
    tex=np.asarray(Image.open(io.BytesIO(g.image(g.j['textures'][ti]['source']))).convert('RGB')).astype(float)/255
    H=tex.shape[0]
    def samp(uv):
      x=np.clip((uv[:,0]%1)*H,0,H-1).astype(int); y=np.clip((uv[:,1]%1)*H,0,H-1).astype(int); return tex[y,x]
    _,W=np.unique(np.round(P/2e-5).astype(np.int64),axis=0,return_inverse=True); W=W.ravel(); IW=W[I]
    c=P[I].mean(1); cc=samp(UV[I].mean(1))
    shirt=(cc[:,0]<0.5)&(cc[:,1]<0.2)
    lab=(c[:,1]>1.30)&~shirt
    # adjacency smoothing via shared edges
    from collections import defaultdict
    E=defaultdict(list)
    for t,(a,b,cx) in enumerate(IW):
      for e in ((a,b),(b,cx),(cx,a)): E[tuple(sorted(e))].append(t)
    nb=[[] for _ in I]
    for ts in E.values():
      for x in ts:
        for y in ts:
          if x!=y: nb[x].append(y)
    for it in range(4):
      new=lab.copy()
      for t in np.where(c[:,1]>1.28)[0]:
        if nb[t]:
          f=np.mean(lab[nb[t]])
          if f>0.6: new[t]=True
          elif f<0.34: new[t]=False
      lab=new
    lab&=c[:,1]>1.28
    # keep largest connected component
    seen=np.zeros(len(I),bool); comps=[]
    for s in np.where(lab)[0]:
      if seen[s]: continue
      st=[s]; seen[s]=True; cp=[]
      while st:
        t=st.pop(); cp.append(t)
        for u in nb[t]:
          if lab[u] and not seen[u]: seen[u]=True; st.append(u)
      comps.append(cp)
    comps.sort(key=len,reverse=True); print('comps',[len(x) for x in comps[:8]])
    keep=np.zeros(len(I),bool)
    for cp in comps:
      if len(cp)>=30 or cp is comps[0]: keep[cp]=True
    head=np.where(keep)[0]; print('head tris',len(head))
    T=IW[head]; vu,inv=np.unique(T,return_inverse=True); inv=inv.reshape(-1,3)
    rep=np.zeros(W.max()+1,int); rep[W]=np.arange(len(W))
    bpy.ops.wm.read_factory_settings(use_empty=True)
    me=bpy.data.meshes.new('t'); Pb=P[rep[vu]][:,[0,2,1]]*np.array([1,-1,1])
    me.from_pydata(Pb.tolist(),[],inv.tolist()); me.update()
    o=bpy.data.objects.new('t',me); bpy.context.scene.collection.objects.link(o); bpy.context.view_layer.objects.active=o; o.select_set(True)
    me.uv_layers.new(name='n')
    # zone visage : un seul îlot déplié (ABF), le reste en projection intelligente
    fcen=np.array([list(f.center) for f in me.polygons]); fnor=np.array([list(f.normal) for f in me.polygons])
    F=(fnor[:,1]<-0.15)&(fcen[:,2]>1.37)&(fcen[:,2]<1.70)&(np.abs(fcen[:,0])<0.185)&(fcen[:,1]<-0.02)
    # lisser la zone (voisins par arêtes)
    bm=bmesh.new(); bm.from_mesh(me); bm.faces.ensure_lookup_table()
    for it in range(3):
      Fn=F.copy()
      for f in bm.faces:
        nbv=[l.link_loop_radial_next.face.index for l in f.loops if l.link_loop_radial_next.face is not f]
        if nbv:
          r=np.mean(F[nbv])
          if r>0.5: Fn[f.index]=True
          elif r<0.34: Fn[f.index]=False
      F=Fn
    # plus grande composante
    seen=set(); best=[]
    for f in bm.faces:
      if not F[f.index] or f.index in seen: continue
      st=[f]; seen.add(f.index); cp=[]
      while st:
        x=st.pop(); cp.append(x.index)
        for l in x.loops:
          y=l.link_loop_radial_next.face
          if F[y.index] and y.index not in seen: seen.add(y.index); st.append(y)
      if len(cp)>len(best): best=cp
    F[:]=False; F[best]=True
    for e in bm.edges:
      fs=[F[f.index] for f in e.link_faces]
      e.seam = len(set(fs))>1 or len(fs)<2
    bm.to_mesh(me); bm.free(); print('visage faces',F.sum())
    for i,pp in enumerate(me.polygons): pp.select=bool(F[i])
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=ANGLE_PROJECTION, island_margin=0.0, area_weight=0.0, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    FACE=F
    bm=bmesh.new(); bm.from_mesh(me); uvl=bm.loops.layers.uv[0]; bm.faces.ensure_lookup_table()
    # islands
    import collections
    fi=[-1]*len(bm.faces); k=0
    def key(l): return (l.vert.index, round(l[uvl].uv.x,6), round(l[uvl].uv.y,6))
    for f in bm.faces:
      if fi[f.index]>=0: continue
      st=[f]; fi[f.index]=k
      while st:
        ff=st.pop()
        for l in ff.loops:
          for l2 in l.vert.link_loops:
            if fi[l2.face.index]<0 and (l2[uvl].uv-l[uvl].uv).length<1e-6:
              fi[l2.face.index]=k; st.append(l2.face)
      k+=1
    print('islands',k)
    fc=np.array([list(f.calc_center_median()) for f in bm.faces])  # blender coords: x, y(-z gltf), z(up)
    fn=np.array([list(f.normal) for f in bm.faces])
    fi=np.array(fi)
    # face front weight: in front of ears, between chin and brows, facing forward
    w=FACE.astype(float)
    S=1.0+AGRANDIR_VISAGE*np.array([w[fi==i].mean() if (fi==i).any() else 0 for i in range(k)])
    for f in bm.faces:
      s=S[fi[f.index]]
      for l in f.loops: l[uvl].uv*=s
    bm.to_mesh(me); bm.free()
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.select_all(action='SELECT')
    bpy.ops.uv.pack_islands(rotate=True, margin_method='FRACTION', margin=0.0035, shape_method='CONCAVE')
    bpy.ops.object.mode_set(mode='OBJECT')
    uv=np.zeros(len(me.loops)*2,np.float32); me.uv_layers[0].data.foreach_get('uv',uv); uv=uv.reshape(-1,3,2)
    # loops follow polygon order = face order (triangles)
    assert all(len(pp.vertices)==3 for pp in me.polygons)
    lv=np.zeros(len(me.loops),np.int32); me.loops.foreach_get('vertex_index',lv); lv=lv.reshape(-1,3)
    assert (lv==inv).all()
    cov=0
    np.savez(os.path.join(dossier,'tete.npz'),head=head,uvn=uv,S=S,face=FACE)
    print('uv bounds',uv.reshape(-1,2).min(0),uv.reshape(-1,2).max(0))


def cuire(src, dossier):
    import cv2
    N=2048
    g=GLB(src); d=np.load(os.path.join(dossier,'tete.npz'))
    p=g.j['meshes'][10]['primitives'][0]
    P=g.acc(p['attributes']['POSITION']).astype(np.float64); NO=g.acc(p['attributes']['NORMAL']).astype(np.float64); UV=g.acc(p['attributes']['TEXCOORD_0']).astype(np.float64); I=g.acc(p['indices']).reshape(-1,3)
    head=d['head']; uvn=d['uvn'].astype(np.float64).copy(); uvn[...,1]=1-uvn[...,1]
    tid,bary=rasterize(uvn,N)
    m=tid>=0; t=tid[m]; L=bary[m].astype(np.float64)
    cor=I[head][t]
    X=(P[cor]*L[...,None]).sum(1); Nv=(NO[cor]*L[...,None]).sum(1); Nv/=np.linalg.norm(Nv,axis=1,keepdims=True)
    ouv=(UV[cor]*L[...,None]).sum(1)
    def frames(Pt,Ut):
        e1=Pt[:,1]-Pt[:,0]; e2=Pt[:,2]-Pt[:,0]; d1=Ut[:,1]-Ut[:,0]; d2=Ut[:,2]-Ut[:,0]
        det=d1[:,0]*d2[:,1]-d1[:,1]*d2[:,0]; det=np.where(np.abs(det)<1e-14,1e-14,det)
        T=(e1*d2[:,1:2]-e2*d1[:,1:2])/det[:,None]; B=(e2*d1[:,0:1]-e1*d2[:,0:1])/det[:,None]
        return T,B
    Pt=P[I[head]]; Tn,Bn=frames(Pt,uvn); To,Bo=frames(Pt,UV[I[head]])
    def basis(T,B,Nn):
        Th=T-(T*Nn).sum(1,keepdims=True)*Nn; Th/=np.maximum(np.linalg.norm(Th,axis=1,keepdims=True),1e-12)
        Bh=np.cross(Nn,Th); s=np.sign((Bh*(-B)).sum(1,keepdims=True)); s[s==0]=1; return Th,Bh*s
    img=lambda k: np.asarray(Image.open(io.BytesIO(g.image(k))).convert('RGB')).astype(np.float64)/255
    col=bilinear(img(4),ouv)
    nold=bilinear(img(2),ouv)*2-1; nold[:,:2]*=0.32; nold/=np.linalg.norm(nold,axis=1,keepdims=True)
    ao=bilinear(img(3),ouv)[:,0]
    Tho,Bho=basis(To[t],Bo[t],Nv); Thn,Bhn=basis(Tn[t],Bn[t],Nv)
    nobj=nold[:,0:1]*Tho+nold[:,1:2]*Bho+nold[:,2:3]*Nv
    print('base ok',len(t),flush=True)
    # ---------- bruit 3D ----------
    def h3(ix,iy,iz):
        h=(ix*73856093)^(iy*19349663)^(iz*83492791); h=(h^(h>>13))*1274126177; h=h^(h>>16)
        return (h&0xffffff).astype(np.float64)/16777215.0
    def vnoise(Q):
        if len(Q)>250000: return np.concatenate([vnoise(Q[i:i+250000]) for i in range(0,len(Q),250000)])
        i=np.floor(Q).astype(np.int64); f=Q-i; f=f*f*(3-2*f)
        out=0
        for dx in (0,1):
            for dy in (0,1):
                for dz in (0,1):
                    w=(f[:,0] if dx else 1-f[:,0])*(f[:,1] if dy else 1-f[:,1])*(f[:,2] if dz else 1-f[:,2])
                    out=out+w*h3(i[:,0]+dx,i[:,1]+dy,i[:,2]+dz)
        return out
    def fbm(Q,o=3):
        s=0; a=1; tot=0
        for k in range(o): s=s+a*vnoise(Q*(2**k)+k*17.3); tot+=a; a*=0.5
        return s/tot
    # ---------- masques et directions ----------
    x,y,z=X[:,0],X[:,1],X[:,2]
    ss=lambda a,b,v: np.clip((v-a)/(b-a),0,1)**2*(3-2*np.clip((v-a)/(b-a),0,1))
    mx=col.max(1); mn=col.min(1); sat=(mx-mn)/np.maximum(mx,1e-6)
    shirt=((col[:,0]<0.45)&(col[:,1]<0.16)).astype(float)
    sx=np.sign(x); sx[sx==0]=1; ax=np.abs(x)
    avant=ss(0.0,0.06,z)
    lum=col@np.array([0.3,0.59,0.11])
    # poids des zones
    w_sourcil=ss(1.595,1.612,y)*ss(1.68,1.655,y)*ss(0.12,0.10,ax)*avant
    w_moust=ss(1.47,1.48,y)*ss(1.54,1.525,y)*ss(0.13,0.11,ax)*ss(0.06,0.10,z)
    w_barbe=ss(1.53,1.51,y)*(1-w_moust)
    w_cuir=np.clip(1-w_sourcil-w_moust-w_barbe,0,1)
    front_=ss(0.05,0.09,z)*ss(0.16,0.13,ax)*ss(1.645,1.665,y)*ss(1.78,1.76,y)
    cheveu=np.maximum(ss(0.30,0.18,sat)*(1-front_)+ss(0.14,0.07,sat)*front_,w_sourcil*ss(0.37,0.31,lum))*(1-shirt)*ss(1.33,1.37,y)
    # front et tempes lisses : au-dessus des sourcils, hors de la chevelure, pas de mèches
    sourc=w_sourcil*ss(0.37,0.31,lum)
    front_lisse=ss(0.05,0.09,z)*ss(0.165,0.14,ax)*ss(1.60,1.62,y)*(1-ss(0.30,0.22,sat)*ss(1.74,1.77,y))
    cheveu=np.where(front_lisse>0, np.maximum(cheveu*(1-front_lisse),sourc), cheveu)
    # barbe continue sous la lèvre et au centre du menton (zone claire et rosée d'origine) jusqu'au bord des lèvres
    zone_b=ss(1.372,1.392,y)*ss(1.478,1.462,y)*ss(0.120,0.095,ax)*ss(0.04,0.08,z)
    ref=(w_barbe>0.5)&(cheveu>0.8)&(ax>0.06)
    coul_b=np.median(col[ref],0); print('barbe ref',coul_b.round(3),flush=True)
    k_b=(zone_b*0.6*ss(0.12,0.28,sat))[:,None]
    col=col+(coul_b[None,:]*(lum[:,None]*0+1)-col)*k_b
    cheveu=np.maximum(cheveu,zone_b*(1-shirt))
    lum=col@np.array([0.3,0.59,0.11])
    np.savez(os.path.join(dossier,'texels.npz'),X=X.astype(np.float32),pix=np.flatnonzero(m).astype(np.int64),nz=Nv[:,2].astype(np.float32))
    peau=(1-cheveu)*(1-shirt)*ss(1.31,1.35,y)
    def unit(v): return v/np.maximum(np.linalg.norm(v,axis=1,keepdims=True),1e-9)
    def proj(v): return v-(v*Nv).sum(1,keepdims=True)*Nv
    one=np.ones_like(x); zero=np.zeros_like(x)
    d_sourcil=np.stack([sx*(0.35+ss(0.01,0.06,ax)), 0.55*ss(0.06,0.01,ax)+0.12, zero],1)
    d_moust=np.stack([sx*1.0, -0.55*one, zero],1)
    d_barbe=np.stack([0.15*sx, -one, -0.6*one],1)
    # cuir chevelu : orientation suivant les bandes de la texture d'origine (tenseur de structure)
    base=np.zeros((N,N),np.float64); base[m]=col.mean(1)
    base=dilate(base,m,6)
    gx=cv2.Sobel(base,cv2.CV_64F,1,0,ksize=3); gy=cv2.Sobel(base,cv2.CV_64F,0,1,ksize=3)
    k=(0,0); sg=3.0
    Jxx=cv2.GaussianBlur(gx*gx,k,sg); Jxy=cv2.GaussianBlur(gx*gy,k,sg); Jyy=cv2.GaussianBlur(gy*gy,k,sg)
    ang=0.5*np.arctan2(2*Jxy,Jxx-Jyy)+np.pi/2   # perpendiculaire au gradient
    coh=np.sqrt((Jxx-Jyy)**2+4*Jxy**2)/np.maximum(Jxx+Jyy,1e-9)
    du=np.cos(ang)[m]; dv=np.sin(ang)[m]
    d_st=du[:,None]*Tn[t]/N*N + dv[:,None]*Bn[t]   # direction 3D (dP/du*du + dP/dv*dv)
    d_st=unit(d_st)
    d_def=np.stack([zero,-0.4*one,-one],1)
    c=ss(0.15,0.5,coh[m])[:,None]
    d_cuir=unit(proj(unit(d_st)))*c+unit(proj(d_def))*(1-c)*0.3
    D=w_sourcil[:,None]*unit(proj(d_sourcil))+w_moust[:,None]*unit(proj(d_moust))+w_barbe[:,None]*unit(proj(d_barbe))+w_cuir[:,None]*unit(d_cuir)
    D=unit(proj(D))
    # ---------- mèches : convolution de bruit le long de la direction ----------
    Lm=(w_sourcil*4+w_moust*9+w_barbe*6+w_cuir*7)*1e-3
    cellw=LARGEUR_MECHE
    idx=np.where(cheveu>0.02)[0]; print('texels cheveux',len(idx),flush=True)
    K=24; acc=np.zeros(len(idx)); acc2=np.zeros(len(idx))
    Xi=X[idx]; Di=D[idx]; Li=Lm[idx]
    # repère : on étire le bruit le long de D
    for c0 in range(0,len(idx),200000):
      sl=slice(c0,c0+200000)
      for s in np.linspace(-0.5,0.5,K):
        Q=(Xi[sl]+Di[sl]*(s*Li[sl])[:,None])/cellw
        acc[sl]+=vnoise(Q); acc2[sl]+=vnoise(Q*0.5+31.7)
    mech=(acc/K-0.5)*np.sqrt(K)*0.9 + 0.5*(acc2/K-0.5)*np.sqrt(K)*0.9
    mech=np.clip(mech,-1.5,1.5)
    H=np.zeros(len(X)); H[idx]=mech*cheveu[idx]
    # ---------- peau : grain et variations de teinte ----------
    pores=(fbm(X/0.0007,2)-0.5)
    tache=fbm(X/0.012,3)-0.5; tache2=fbm(X/0.004+5,2)-0.5
    Hs=pores*peau; print('peau',flush=True)
    # ---------- couleur ----------
    A=CONTRASTE_MECHES
    out=col.copy()
    A_=A*(1+0.5*w_sourcil+0.8*w_moust+0.25*w_barbe)
    lum_=1+A_*np.tanh(H)  # mèches plus claires / plus foncées
    out=out*lum_[:,None]
    rouge=np.array([1.04,0.985,0.985]); 
    out=out*(1+peau[:,None]*(tache[:,None]*0.10*(rouge-1)/0.04*0.4+tache2[:,None]*0.05))
    out=out*(1-0.035*peau[:,None]*(pores[:,None]>0.18))
    out=np.clip(out,0,1); print('couleur',flush=True)
    import gc; del acc,acc2,Xi,Di,pores,tache,tache2,base,gx,gy,Jxx,Jxy,Jyy,ang,coh,bary; gc.collect()
    # ---------- normales ----------
    HT=np.zeros((N,N)); HT[m]=H*RELIEF_MECHES*(1+0.6*w_moust)+Hs*0.00004
    HT=dilate(HT,m,4)
    hx=(np.roll(HT,-1,1)-np.roll(HT,1,1))/2*N; hy=(np.roll(HT,-1,0)-np.roll(HT,1,0))/2*N  # dh/du, dh/dv
    hu=hx[m]; hv=hy[m]
    # gradient de surface = hu*grad(u)+hv*grad(v) ; base duale de (Tn,Bn)
    Tt=Tn[t]; Bt=Bn[t]
    a11=(Tt*Tt).sum(1); a12=(Tt*Bt).sum(1); a22=(Bt*Bt).sum(1); det=a11*a22-a12**2; det=np.where(det<1e-20,1e-20,det)
    gu=( a22[:,None]*Tt - a12[:,None]*Bt)/det[:,None]; gv=(-a12[:,None]*Tt + a11[:,None]*Bt)/det[:,None]
    gs=hu[:,None]*gu+hv[:,None]*gv
    npert=unit(nobj-gs)
    nts=np.stack([(npert*Thn).sum(1),(npert*Bhn).sum(1),(npert*Nv).sum(1)],1)
    nts[:,2]=np.maximum(nts[:,2],0.05); nts=unit(nts)
    def save(arr,name,ch=3,dil=12,size=None,q=None):
        im=np.zeros((N,N,ch),np.float32); im[m]=arr.reshape(len(t),ch); im=dilate(im,m,dil)
        im=(im*255+0.5).clip(0,255).astype(np.uint8)
        pi=Image.fromarray(im if ch==3 else im[...,0])
        if size: pi=pi.resize((size,size),Image.LANCZOS)
        pi.save(name)
    save(out,os.path.join(dossier,'tete_couleur.png')); save(nts*0.5+0.5,os.path.join(dossier,'tete_normale.png')); save(np.repeat(ao[:,None],3,1),os.path.join(dossier,'tete_ao.png'),size=1024)
    save(np.stack([cheveu,w_sourcil+w_moust,w_barbe],1),os.path.join(dossier,'tete_masques.png'))
    print('fini')


def appliquer(dossier, src, dst):
    g=pg.GLTF2().load(src); blob=bytearray(g.binary_blob())
    d=np.load(os.path.join(dossier,'tete.npz')); head=d['head']; uvn=d['uvn'].astype(np.float64).copy(); uvn[...,1]=1-uvn[...,1]
    if any(m.name=='Gabi_Tete' for m in g.materials): sys.exit(f'{src} : tête déjà en texture dédiée')
    me=next(m for m in g.meshes if m.name=='Mesh_0'); p=me.primitives[0]
    I=lire(g,blob,p.indices).reshape(-1,3)
    rest=np.setdiff1d(np.arange(len(I)),head)
    cor=I[head].ravel(); uvc=uvn.reshape(-1,2).astype(np.float32)
    key=np.concatenate([cor[:,None].astype(np.float64),np.round(uvc*1e6)],1)
    _,first,inv=np.unique(key,axis=0,return_index=True,return_inverse=True); inv=inv.ravel()
    vsrc=cor[first]; vuv=uvc[first]; print('sommets tete',len(vsrc))
    att={}
    for k in ('POSITION','NORMAL','JOINTS_0','WEIGHTS_0'):
        a=getattr(p.attributes,k); arr=lire(g,blob,a)[vsrc]
        att[k]=ecrire(g,blob,arr,34962,minmax=(k=='POSITION'))
    att['TEXCOORD_0']=ecrire(g,blob,vuv,34962)
    targets=[]
    for tg in p.targets:
        nt={}
        for k,a in tg.items():
            arr=lire(g,blob,a)[vsrc].astype(np.float32); nz=np.where(np.abs(arr).max(1)>0)[0]
            ai=ecrire(g,blob,nz.astype(np.uint16 if len(arr)<65536 else np.uint32).reshape(-1,1)); av=ecrire(g,blob,arr[nz])
            iv,vv=g.accessors[ai],g.accessors[av]; g.accessors.pop(); g.accessors.pop()
            acc=pg.Accessor(componentType=5126,count=len(arr),type='VEC3',min=arr.min(0).tolist(),max=arr.max(0).tolist(),
                sparse=pg.Sparse(count=len(nz),indices=pg.AccessorSparseIndices(bufferView=iv.bufferView,componentType=iv.componentType),values=pg.AccessorSparseValues(bufferView=vv.bufferView)))
            g.accessors.append(acc); nt[k]=len(g.accessors)-1
        targets.append(nt)
    idx=inv.astype(np.uint32 if len(vsrc)>65535 else np.uint16).reshape(-1,1)
    ii=ecrire(g,blob,idx,34963)
    k_=ecrire(g,blob,I[rest].astype(np.uint32 if I.max()>65535 else np.uint16).reshape(-1,1),34963)
    g.accessors[p.indices]=g.accessors.pop(k_)
    def tex(path,mime,q,nom):
        b=io.BytesIO(); im=Image.open(path).convert('RGB')
        if mime=='image/jpeg': im.save(b,'JPEG',quality=q,optimize=True,subsampling=0 if 'norm' in nom.lower() else 2)
        else: im.save(b,'PNG',optimize=True)
        k=ajouter_image(g,blob,b.getvalue(),mime,nom); g.textures.append(pg.Texture(sampler=1,source=k)); print(nom,len(b.getvalue())); return len(g.textures)-1
    tc=tex(os.path.join(dossier,'tete_couleur.png'),'image/jpeg',90,'Gabi_Tete_Couleur')
    tn=tex(os.path.join(dossier,'tete_normale.png'),'image/jpeg',92,'Gabi_Tete_Normale')
    ta=tex(os.path.join(dossier,'tete_ao.png'),'image/jpeg',88,'Gabi_Tete_Occlusion')
    # coque des lèvres : hors du contour, la peau de la nouvelle texture de la tête (mèches de barbe jusqu'au bord)
    import importlib.util; sys.dont_write_bytecode=True
    from scipy.spatial import cKDTree
    sp=importlib.util.spec_from_file_location('sourire',os.path.join(os.path.dirname(os.path.abspath(__file__)),'ajouter-sourire-gabi.py')); S=importlib.util.module_from_spec(sp); sp.loader.exec_module(S)
    pl=next(q for q in me.primitives if g.materials[q.material].name=='M_Gabi_V3_Levres')
    PL=lire(g,blob,pl.attributes.POSITION).astype(np.float64); UL=lire(g,blob,pl.attributes.TEXCOORD_0).astype(np.float64)
    u2x=np.polyfit(UL[:,0],PL[:,0],1); v2y=np.polyfit(UL[:,1],PL[:,1],1)
    tx=np.load(os.path.join(dossier,'texels.npz')); TX=tx['X']; TC=np.asarray(Image.open(os.path.join(dossier,'tete_couleur.png')).convert('RGB')).reshape(-1,3).astype(np.float64)[tx['pix']]
    sel=np.where((tx['nz']>0.2)&(TX[:,2]>0.09)&(np.abs(TX[:,1]-1.47)<0.06)&(np.abs(TX[:,0])<0.12))[0]
    arbre=cKDTree(TX[sel][:,:2].astype(np.float64))
    def peau(X,Y):
        _,k=arbre.query(np.stack([X.ravel(),Y.ravel()],1),k=8)
        zz=TX[sel][k][...,2]; j=np.argmax(zz,1); kk=sel[k[np.arange(len(k)),j]]
        return (TC[kk]*S.PEAU_COQUE).reshape(X.shape+(3,))
    ti=g.materials[pl.material].pbrMetallicRoughness.baseColorTexture.index; src_i=g.textures[ti].source
    T=S.peindre_levres(u2x,v2y,(1024,512),peau)
    b=io.BytesIO(); Image.fromarray(T).save(b,'JPEG',quality=92,optimize=True)
    k=ajouter_image(g,blob,b.getvalue(),'image/jpeg','Gabi_Vermillon_Rose'); g.images[src_i].bufferView=g.images[k].bufferView; g.images[src_i].mimeType='image/jpeg'; g.images.pop()
    print('coque des lèvres repeinte',len(b.getvalue()))
    m0=g.materials[p.material]
    mt=pg.Material(name='Gabi_Tete',doubleSided=m0.doubleSided,alphaMode=m0.alphaMode,
      pbrMetallicRoughness=pg.PbrMetallicRoughness(baseColorFactor=[1,1,1,1],metallicFactor=0.0,roughnessFactor=m0.pbrMetallicRoughness.roughnessFactor,baseColorTexture=pg.TextureInfo(index=tc)),
      normalTexture=pg.NormalMaterialTexture(index=tn,scale=1.0),occlusionTexture=pg.OcclusionTextureInfo(index=ta,strength=m0.occlusionTexture.strength),emissiveFactor=[0,0,0])
    g.materials.append(mt)
    np_=pg.Primitive(attributes=pg.Attributes(**att),indices=ii,material=len(g.materials)-1,mode=4,targets=targets)
    me.primitives.append(np_)
    blob=compacter(g,blob)
    g.buffers[0].byteLength=len(blob); g.set_binary_blob(bytes(blob)); g.save(dst); print('ok',len(blob))



if __name__ == '__main__':
    a = sys.argv[1:]
    if len(a) == 3 and a[0] == 'preparer':
        os.makedirs(a[2], exist_ok=True)
        deplier(a[1], a[2]); cuire(a[1], a[2])
    elif len(a) == 4 and a[0] == 'appliquer':
        appliquer(a[1], a[2], a[3])
    else:
        sys.exit(__doc__ if __doc__ else 'usage : preparer <gabi.glb> <dossier> | appliquer <dossier> <entrée.glb> <sortie.glb>')
