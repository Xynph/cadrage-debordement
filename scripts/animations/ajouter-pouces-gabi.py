# Prépare le Gabi rigué : os de pouce ajoutés (Mixamo n'en a pas fait), pondérés sur la géométrie du pouce.
import bpy, sys, numpy as np, heapq
from mathutils import Vector
src, out = sys.argv[sys.argv.index('--')+1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True); bpy.ops.import_scene.fbx(filepath=src)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
if arm.animation_data: arm.animation_data_clear()
TIPS = {'Left': ('Gabi_Main_G_Distale', (0.434, -0.18, 0.728)), 'Right': ('Gabi_Main_D_Distale', (-0.435, -0.18, 0.73))}
def geod(o, tip):
    W = np.array(o.matrix_world); P = (np.c_[np.array([list(v.co) for v in o.data.vertices]), np.ones(len(o.data.vertices))] @ W.T)[:, :3]
    key = {}; rep = np.array([key.setdefault(tuple(np.round(p, 5)), i) for i, p in enumerate(P)])
    adj = {}
    for e in o.data.edges:
        a, b = rep[e.vertices[0]], rep[e.vertices[1]]
        if a != b: d = float(np.linalg.norm(P[a]-P[b])); adj.setdefault(a, []).append((b, d)); adj.setdefault(b, []).append((a, d))
    s = rep[int(np.argmin(np.linalg.norm(P-np.array(tip), axis=1)))]; dist = {s: 0.0}; h = [(0.0, s)]
    while h:
        d, x = heapq.heappop(h)
        if d > dist.get(x, 9): continue
        for y, w in adj.get(x, []):
            if d+w < dist.get(y, 9): dist[y] = d+w; heapq.heappush(h, (d+w, y))
    return P, np.array([dist.get(rep[i], 9) for i in range(len(P))])
data = {}
for cote, (mesh, tip) in TIPS.items():
    o = bpy.data.objects[mesh]; P, D = geod(o, tip)
    pts = lambda a, b: P[(D >= a) & (D < b)].mean(0)
    data[cote] = (o, D, [pts(0.062, 0.072), pts(0.036, 0.044), pts(0.014, 0.022), pts(0.0, 0.006)])
bpy.context.view_layer.objects.active = arm; bpy.ops.object.mode_set(mode='EDIT')
Winv = arm.matrix_world.inverted(); eb = arm.data.edit_bones
for cote, (o, D, J) in data.items():
    parent = eb['mixamorig:%sHand' % cote]
    for i in range(3):
        b = eb.new('mixamorig:%sHandThumb%d' % (cote, i+1)); b.head = Winv @ Vector(J[i]); b.tail = Winv @ Vector(J[i+1]); b.roll = 0
        b.parent = parent; b.use_connect = i > 0; parent = b
bpy.ops.object.mode_set(mode='OBJECT')
for cote, (o, D, J) in data.items():
    groups = {i: o.vertex_groups.get('mixamorig:%sHandThumb%d' % (cote, i)) or o.vertex_groups.new(name='mixamorig:%sHandThumb%d' % (cote, i)) for i in (1, 2, 3)}
    hand = o.vertex_groups.get('mixamorig:%sHand' % cote)
    n = 0
    for v in o.data.vertices:
        d = D[v.index]
        if d >= 0.085: continue
        # part du pouce : 1 jusqu'à 6,5 cm de la pointe, fondu jusqu'à 8,5 cm ; répartie sur 3 phalanges
        t = 1.0 if d < 0.065 else (0.085-d)/0.02
        seg = 3 if d < 0.022 else (2 if d < 0.044 else 1)
        for g in list(v.groups):
            vg = o.vertex_groups[g.group]
            vg.add([v.index], g.weight*(1-t), 'REPLACE')
        groups[seg].add([v.index], t, 'REPLACE'); n += 1
    print('pouce', cote, 'sommets', n)
bpy.ops.wm.save_as_mainfile(filepath=out); print('ok', out)
