# Même correction des yeux sur le Gabi rigué par Mixamo (gabi.blend), en coordonnées Blender (Z haut, -Y avant).
import bpy, sys, numpy as np
from mathutils import Matrix, Vector
blend = sys.argv[sys.argv.index('--')+1]; ABAISSE = 10.0
bpy.ops.wm.open_mainfile(filepath=blend)
g2b = lambda v: np.array([v[0], -v[2], v[1]])
PUPILLE = {'Gabi_Oeil_D': g2b((-0.139, 0.005, 0.99)), 'Gabi_Oeil_G': g2b((-0.05, 0.005, 0.999))}
CIBLE = g2b((0.0, 1.57, 1.4))
def rot(u, v):
    u = u/np.linalg.norm(u); v = v/np.linalg.norm(v); k = np.cross(u, v); s = np.linalg.norm(k); c = np.dot(u, v)
    if s < 1e-9: return np.eye(3)
    k /= s; K = np.array([[0,-k[2],k[1]],[k[2],0,-k[0]],[-k[1],k[0],0]]); return np.eye(3)+s*K+(1-c)*K@K
def coords(o):
    W = np.array(o.matrix_world); P = np.array([list(v.co) for v in o.data.vertices])
    return W, (np.c_[P, np.ones(len(P))] @ W.T)[:, :3]
def ecrire(o, W, Pw):
    L = np.linalg.inv(W); P = (np.c_[Pw, np.ones(len(Pw))] @ L.T)[:, :3]
    o.data.vertices.foreach_set('co', P.astype(np.float32).ravel())
    if o.data.shape_keys:
        for kb in o.data.shape_keys.key_blocks: kb.data.foreach_set('co', P.astype(np.float32).ravel())
    o.data.update()
centres = {}
for n, d in PUPILLE.items():
    o = bpy.data.objects[n]; W, P = coords(o); c = (P.min(0)+P.max(0))/2; R = rot(d, CIBLE-c)
    ecrire(o, W, (P-c) @ R.T + c); centres[n.replace('Oeil', 'Paupieres')] = c; print('œil', n)
for n, c in centres.items():
    o = bpy.data.objects[n]; W, P = coords(o)
    up = P[:, 2]-c[2]; fw = -(P[:, 1]-c[1])
    w = np.clip(up/0.012, 0, 1)**1.5; a = np.radians(ABAISSE)*w; ca, sa = np.cos(a), np.sin(a)
    up2 = up*ca - fw*sa; fw2 = up*sa + fw*ca
    P2 = P.copy(); P2[:, 2] = c[2]+up2; P2[:, 1] = c[1]-fw2
    ecrire(o, W, P2); print('paupière', n)
bpy.ops.wm.save_mainfile(); print('ok')
