# Répare les pouces du Gabi rigué (demande de Léo, 12 novembre 2026 : « les pouces ne sont pas complets »).
# ajouter-pouces-gabi.py pondérait chaque sommet du pouce à 100 % sur une seule phalange (coupures nettes à 2,2 et
# 4,4 cm de la pointe) : dès que les gestes pliaient le pouce, le maillage se cassait en morceaux aux articulations
# (pouce qui paraît coupé ou raccourci). Ce script, appliqué au .blend (après adapter-animations-gabi.py) :
#   1. repondère les sommets du pouce avec des fondus entre phalanges (FONDU de part et d'autre de chaque
#      articulation) et vers la main, sur la même distance le long de la surface depuis la pointe ;
#   2. met en commun les poids des sommets confondus non soudés (souder_poids : déchirures, fentes entre doigts) ;
#   3. réduit (AMPLITUDE) la rotation des phalanges du pouce dans tous les gestes : les os du pouce,
#      ajoutés après coup, n'ont pas l'orientation de ceux du squelette source, et les grandes flexions Mixamo
#      repliaient le pouce dans la paume ou dans le carnet.
# Usage : python3 reparer-pouces-gabi.py -- <gabi.blend>      (le .blend est modifié et enregistré ; une seule fois :
# relancé, il réduirait encore les rotations)
import bpy, sys, numpy as np, heapq
from mathutils import Quaternion

blend = sys.argv[sys.argv.index('--') + 1]
TIPS = {'Left': ('Gabi_Main_G_Distale', (0.434, -0.18, 0.728)), 'Right': ('Gabi_Main_D_Distale', (-0.435, -0.18, 0.73))}
ARTICULATIONS = (0.022, 0.044)   # distances à la pointe (m) : phalange 3 | 2 | 1
FONDU = 0.009                    # demi-largeur des fondus aux articulations
BASE = (0.058, 0.085)            # le pouce rejoint la main entre ces distances
# Part gardée de la rotation de chaque phalange, par côté. La dernière reste dans l'axe de la deuxième. Le pouce
# gauche reste solidaire de la main : son maillage (pièces non soudées au bout) se déchire dès qu'il plie, même
# à 25 % ; il tient le carnet presque tout le temps.
AMPLITUDE = {'Right': {1: 0.6, 2: 0.5, 3: 0.0}, 'Left': {1: 0.0, 2: 0.0, 3: 0.0}}

bpy.ops.wm.open_mainfile(filepath=blend)


def souder_poids():
    """Les mains (Gabi_Main_*_Distale) sont faites de morceaux non soudés : sommets confondus (coutures d'UV, bord
    des pièces), en particulier au bout du pouce et entre les doigts. Quand ces sommets confondus n'ont pas les
    mêmes poids d'os, ils se séparent dès que la main bouge : déchirure à la base de l'ongle du pouce gauche,
    fentes noires entre les doigts. Ici, les poids de tous les sommets confondus sont mis en commun (moyenne)."""
    for nom in ('Gabi_Main_G_Distale', 'Gabi_Main_D_Distale'):
        o = bpy.data.objects[nom]
        M = o.matrix_world; P = np.array([list(M @ v.co) for v in o.data.vertices])
        cle = {}
        groupes = [cle.setdefault(tuple(np.round(p / 2e-4).astype(int)), []) for p in P]   # à 0,2 mm près
        for i, gr in enumerate(groupes): gr.append(i)
        n = 0
        for membres in {id(g): g for g in groupes}.values():
            if len(membres) < 2: continue
            somme = {}
            for i in membres:
                for gr in o.data.vertices[i].groups: somme[gr.group] = somme.get(gr.group, 0.0) + gr.weight / len(membres)
            differents = any({gr.group: round(gr.weight, 4) for gr in o.data.vertices[i].groups} !=
                             {gr.group: round(gr.weight, 4) for gr in o.data.vertices[membres[0]].groups} for i in membres)
            if not differents: continue
            for i in membres:
                for gr in list(o.data.vertices[i].groups):
                    if gr.group not in somme: o.vertex_groups[gr.group].remove([i])
                for gi, w in somme.items(): o.vertex_groups[gi].add([i], w, 'REPLACE')
            n += 1
        print(nom, ': poids mis en commun sur', n, 'groupes de sommets confondus')




def ss(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)


def geod(o, tip):
    W = np.array(o.matrix_world); P = (np.c_[np.array([list(v.co) for v in o.data.vertices]), np.ones(len(o.data.vertices))] @ W.T)[:, :3]
    key = {}; rep = np.array([key.setdefault(tuple(np.round(p, 5)), i) for i, p in enumerate(P)])
    adj = {}
    for e in o.data.edges:
        a, b = rep[e.vertices[0]], rep[e.vertices[1]]
        if a != b:
            d = float(np.linalg.norm(P[a] - P[b])); adj.setdefault(a, []).append((b, d)); adj.setdefault(b, []).append((a, d))
    s = rep[int(np.argmin(np.linalg.norm(P - np.array(tip), axis=1)))]; dist = {s: 0.0}; h = [(0.0, s)]
    while h:
        d, x = heapq.heappop(h)
        if d > dist.get(x, 9): continue
        for y, w in adj.get(x, []):
            if d + w < dist.get(y, 9): dist[y] = d + w; heapq.heappush(h, (d + w, y))
    D = np.array([dist.get(rep[i], 9) for i in range(len(P))])
    # Pièces non soudées : à gauche, une partie de la peau du pouce (près de l'ongle) est une pièce à part, à
    # quelques dixièmes de millimètre du reste : non atteinte par le parcours, elle restait sur la main et
    # s'ouvrait en trou dès que le pouce bougeait. Elle prend la distance de la surface atteinte la plus proche.
    from scipy.spatial import cKDTree
    atteint = D < 9
    if (~atteint).any():
        d, k = cKDTree(P[atteint]).query(P[~atteint])
        proches = d < 0.003
        Dn = D[~atteint]; Dn[proches] = D[atteint][k[proches]] + d[proches]; D[~atteint] = Dn
    return D


for cote, (nom, tip) in TIPS.items():
    o = bpy.data.objects[nom]; D = geod(o, tip)
    g = {i: o.vertex_groups[f'mixamorig:{cote}HandThumb{i}'] for i in (1, 2, 3)}
    main = o.vertex_groups[f'mixamorig:{cote}Hand']
    a3, a2 = ARTICULATIONS
    w3 = 1 - ss(a3 - FONDU, a3 + FONDU, D)
    w2 = ss(a3 - FONDU, a3 + FONDU, D) * (1 - ss(a2 - FONDU, a2 + FONDU, D))
    w1 = ss(a2 - FONDU, a2 + FONDU, D)
    pouce = 1 - ss(BASE[0], BASE[1], D)
    n = 0
    for v in o.data.vertices:
        d = D[v.index]
        if d >= BASE[1]: continue
        t = float(pouce[v.index])
        # part hors pouce : celle de la main (les autres groupes du sommet sont remis à l'échelle)
        autres = [(gr.group, gr.weight) for gr in v.groups if o.vertex_groups[gr.group].name not in {x.name for x in g.values()}]
        total = sum(w for _, w in autres) or 1.0
        for gi, w in autres: o.vertex_groups[gi].add([v.index], (1 - t) * w / total, 'REPLACE')
        if not autres: main.add([v.index], 1 - t, 'REPLACE')
        for i, wi in ((1, w1), (2, w2), (3, w3)):
            g[i].add([v.index], t * float(wi[v.index]), 'REPLACE')
        n += 1
    print('pouce', cote, 'sommets repondérés', n)



def pouce_dans_le_visage():
    """La base et le milieu du pouce ne sont pas dans Gabi_Main_*_Distale mais dans Mesh_0, où ils n'étaient
    pondérés que sur la main : quand le pouce pliait, son bout (Distale) partait et le milieu restait, d'où un
    trou à la jointure. Les sommets de Mesh_0 autour de la chaîne des os du pouce reçoivent les mêmes poids que
    Distale, calculés sur la distance à la pointe le long de l'axe du pouce (mêmes articulations, mêmes fondus)."""
    arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE'); W = arm.matrix_world
    o = bpy.data.objects['Mesh_0']; M = o.matrix_world
    P = np.array([list(M @ v.co) for v in o.data.vertices])
    for cote in TIPS:
        os_ = [arm.data.bones[f'mixamorig:{cote}HandThumb{i}'] for i in (1, 2, 3)]
        J = [np.array(W @ os_[0].head_local)] + [np.array(W @ b.tail_local) for b in os_]
        seg = [(J[i], J[i + 1]) for i in range(3)]
        long_ = [np.linalg.norm(b - a) for a, b in seg]; L = sum(long_)
        meilleur = np.full(len(P), 9.0); u = np.zeros(len(P))
        cumul = 0.0
        for (a, b), l in zip(seg, long_):
            ab = (b - a) / l; t = np.clip((P - a) @ ab, -0.03 if cumul == 0 else 0, l)
            d = np.linalg.norm(P - (a + np.outer(t, ab)), axis=1)
            mieux = d < meilleur; meilleur[mieux] = d[mieux]; u[mieux] = cumul + t[mieux]; cumul += l
        D = L - u                                   # distance à la pointe le long de l'axe
        dom = np.where((meilleur < 0.016) & (D < BASE[1]))[0]
        a3, a2 = ARTICULATIONS
        g = {i: o.vertex_groups.get(f'mixamorig:{cote}HandThumb{i}') or o.vertex_groups.new(name=f'mixamorig:{cote}HandThumb{i}') for i in (1, 2, 3)}
        noms_pouce = {x.name for x in g.values()}
        for i in map(int, dom):
            d = D[i]; v = o.data.vertices[i]
            t = float(1 - ss(BASE[0], BASE[1], d)) * float(1 - ss(0.012, 0.016, meilleur[i]))
            autres = [(gr.group, gr.weight) for gr in v.groups if o.vertex_groups[gr.group].name not in noms_pouce]
            total = sum(w for _, w in autres) or 1.0
            for gi, w in autres: o.vertex_groups[gi].add([i], (1 - t) * w / total, 'REPLACE')
            w3 = 1 - ss(a3 - FONDU, a3 + FONDU, d); w1 = ss(a2 - FONDU, a2 + FONDU, d); w2 = 1 - w3 - w1
            for k, wk in ((1, w1), (2, w2), (3, w3)): g[k].add([i], t * float(max(wk, 0.0)), 'REPLACE')
        print('pouce', cote, ': sommets de Mesh_0 pondérés sur les os du pouce :', len(dom))


pouce_dans_le_visage()
souder_poids()

arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
from bpy_extras import anim_utils
reduits = 0
for act in bpy.data.actions:
    if not act.slots: continue
    cb = anim_utils.action_get_channelbag_for_slot(act, act.slots[0])
    if cb is None: continue
    for cote in TIPS:
        for i in (1, 2, 3):
            chemin = f'pose.bones["mixamorig:{cote}HandThumb{i}"].rotation_quaternion'
            fcs = [cb.fcurves.find(chemin, index=j) for j in range(4)]
            if not all(fcs): continue
            n = len(fcs[0].keyframe_points)
            vals = np.array([[fc.keyframe_points[k].co[1] for fc in fcs] for k in range(n)])
            out = []
            for q in vals:
                q = Quaternion(q); q.normalize()
                if q.w < 0: q.negate()
                out.append(Quaternion().slerp(q, AMPLITUDE[cote][i]))
            for j, fc in enumerate(fcs):
                co = np.empty(n * 2); fc.keyframe_points.foreach_get('co', co); co = co.reshape(-1, 2)
                co[:, 1] = [q[j] for q in out]; fc.keyframe_points.foreach_set('co', co.ravel()); fc.update()
            reduits += 1
print('rotations de phalanges réduites :', reduits, 'courbes')
bpy.ops.wm.save_mainfile(); print('ok', blend)
