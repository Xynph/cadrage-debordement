# Usage : python3 corriger-yeux-gabi.py <gabi.glb> <sortie.glb> [abaissement paupière, degrés (10)]
# Corrige les yeux de Gabi dans un .glb : pupilles dirigées vers l'interlocuteur (les deux regardaient
# sur sa droite) et paupières couleur peau (elles étaient blanches, effet « lunettes »).
import pygltflib, numpy as np, sys
src, dst = sys.argv[1], sys.argv[2]
g=pygltflib.GLTF2().load(src); blob=bytearray(g.binary_blob())
def view(i):
    a=g.accessors[i]; bv=g.bufferViews[a.bufferView]; assert a.componentType==5126 and not (bv.byteStride and bv.byteStride!=12)
    off=(bv.byteOffset or 0)+(a.byteOffset or 0); return np.frombuffer(blob,dtype=np.float32,count=a.count*3,offset=off).reshape(a.count,3), off
def rot(u,v):
    u=u/np.linalg.norm(u); v=v/np.linalg.norm(v); k=np.cross(u,v); s=np.linalg.norm(k); c=np.dot(u,v)
    if s<1e-9: return np.eye(3)
    k/=s; K=np.array([[0,-k[2],k[1]],[k[2],0,-k[0]],[-k[1],k[0],0]]); return np.eye(3)+s*K+(1-c)*K@K
ABAISSE=float(sys.argv[3]) if len(sys.argv)>3 else 12.0
CIBLE=np.array([0.0,1.57,1.4])   # interlocuteur ~1,3 m devant, un peu sous les yeux
PUPILLE={'Gabi_Oeil_D':np.array([-0.139,0.005,0.99]),'Gabi_Oeil_G':np.array([-0.05,0.005,0.999])}
for m in g.meshes:
    if m.name in PUPILLE:
        p=m.primitives[0]; P,offp=view(p.attributes.POSITION); N,offn=view(p.attributes.NORMAL)
        c=(P.min(0)+P.max(0))/2; R=rot(PUPILLE[m.name], CIBLE-c)
        P2=((P-c)@R.T+c).astype(np.float32); N2=(N@R.T).astype(np.float32)
        blob[offp:offp+P2.nbytes]=P2.tobytes(); blob[offn:offn+N2.nbytes]=N2.tobytes()
        a=g.accessors[p.attributes.POSITION]; a.min=P2.min(0).tolist(); a.max=P2.max(0).tolist()
        ang=np.degrees(np.arccos(np.clip(np.dot(PUPILLE[m.name]/np.linalg.norm(PUPILLE[m.name]),(CIBLE-c)/np.linalg.norm(CIBLE-c)),-1,1)))
        print(m.name,'rotation %.1f°'%ang)
# Paupière supérieure abaissée d'environ 12° autour du centre de l'œil (elle recouvre le haut de l'iris,
# comme un regard détendu) ; la paupière inférieure ne bouge pas.
CENTRES={}
for m in g.meshes:
    if m.name in PUPILLE:
        P,_=view(m.primitives[0].attributes.POSITION); CENTRES[m.name.replace('Oeil','Paupieres')]=(P.min(0)+P.max(0))/2
for m in g.meshes:
    if m.name in CENTRES:
        c=CENTRES[m.name]
        for p in m.primitives:
            P,offp=view(p.attributes.POSITION); N,offn=view(p.attributes.NORMAL)
            h=(P[:,1]-c[1]); w=np.clip(h/0.012,0,1)**1.5   # 0 sous le centre, 1 au-dessus de 1,2 cm
            ang=np.radians(ABAISSE)*w
            ca,sa=np.cos(ang),np.sin(ang); y=P[:,1]-c[1]; z=P[:,2]-c[2]
            P2=P.copy(); P2[:,1]=c[1]+y*ca-z*sa; P2[:,2]=c[2]+y*sa+z*ca   # rotation autour de X : le haut vient vers l'avant puis descend
            ny,nz=N[:,1].copy(),N[:,2].copy(); N2=N.copy(); N2[:,1]=ny*ca-nz*sa; N2[:,2]=ny*sa+nz*ca
            blob[offp:offp+P2.nbytes]=P2.astype(np.float32).tobytes(); blob[offn:offn+N2.nbytes]=N2.astype(np.float32).tobytes()
            a=g.accessors[p.attributes.POSITION]; a.min=P2.min(0).tolist(); a.max=P2.max(0).tolist()
        print(m.name,'paupière supérieure abaissée')
lin=lambda x: x/12.92 if x<=0.04045 else ((x+0.055)/1.055)**2.4
for mat in g.materials:
    if mat.name=='Gabi_Paupières':
        mat.pbrMetallicRoughness.baseColorFactor=[lin(0.80),lin(0.53),lin(0.46),1.0]
        mat.pbrMetallicRoughness.roughnessFactor=0.6; print('paupières', [round(x,3) for x in mat.pbrMetallicRoughness.baseColorFactor])
g.set_binary_blob(bytes(blob)); g.save(dst); print('ok', dst)
