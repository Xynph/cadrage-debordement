# Gabi garde son carnet contre lui (demande de Léo, 12 novembre 2026 : « fais en sorte qu'il garde plus son
# carnet contre lui »). Dans les gestes Mixamo, le bras gauche, qui tient le carnet (attaché à mixamorig:LeftHand
# par exporter-gabi-mixamo.py), gesticule : carnet levé à l'oreille, tendu, balancé. Ce script réécrit, dans chaque
# geste du .blend, le bras gauche (bras, avant-bras, main, doigts) pour tenir le carnet à plat contre le ventre,
# côté gauche, légèrement penché comme le ventre. La pose de tenue est définie par rapport à mixamorig:Spine1 : le
# carnet suit le buste (respiration, inclinaisons, haussements), l'épaule garde son mouvement d'origine.
# Le bras droit, la tête et le corps ne changent pas : les gestes restent les mêmes, d'une seule main.
#
# Gestes où il se sert du carnet (CONSULTE) : le bras d'origine est gardé au milieu du geste, avec un passage
# progressif depuis et vers la tenue (RAMPE secondes) ; ainsi les fondus du jeu (0,2 s) relient toujours des poses
# de tenue. Gestes non joués par le jeu et laissés tels quels : IGNORES.
#
# Méthode, pour chaque image : cible du carnet = Spine1(image) × TENUE ; main = carnet × (main→carnet)⁻¹ ;
# cinématique inverse analytique à deux os (coude vers l'extérieur et l'arrière, repère du buste) ; torsion de
# l'avant-bras choisie pour plier le moins possible le poignet sans tordre le coude ; doigts : prise de « repos ».
# La relation main→carnet est celle de l'export (carnet du Gabi d'origine réattaché à la main, pose de repos).
#
# Usage : python3 tenir-carnet-gabi.py -- <gabi.blend> <gabi-origine.glb>      (le .blend est modifié et enregistré)
# Contrôle : distance carnet-corps et carnet-bras droit mesurée sur des images de chaque geste (affichée à la fin).
# Entrée et sortie hors du dépôt public (animations Mixamo). Blender en module Python (pip install bpy).
import bpy, sys, math
import numpy as np
from mathutils import Matrix, Vector, Quaternion
from bpy_extras import anim_utils

argv = sys.argv[sys.argv.index('--') + 1:]
BLEND, ORIGINE = argv[0], argv[1]
FPS = 30
# tablette : il tape sur son carnet tenu devant lui. decu (mains jointes devant le ventre) et baille (étirement) :
# la main droite traverse le carnet, avant comme après ce script ; le jeu ne les joue plus (gabi_moments.gd).
CONSULTE = {'tablette'}
IGNORES = {'bras_croises', 'telephone', 'telephone_marche'}
RAMPE = 0.8
# Tenue du carnet, en coordonnées monde Blender (Z haut, Gabi regarde vers -Y), pose de repos du squelette :
# centre du carnet 1,2 cm devant le ventre (avant du ventre mesuré sur Mesh_0 : y = -0,233 m à z = 1,06 m),
# 5 cm à gauche du milieu, couverture face à l'avant, haut penché de 11° vers l'arrière (pente du ventre), tourné
# de 15° vers la gauche (il épouse le flanc), pivoté de -10° dans son plan. Valeurs choisies parmi 324 essais
# (position, inclinaison, rotation) : poignet le moins plié (~43° de l'alignement de repos), main hors du corps.
TENUE = dict(centre=(0.05, -0.2595, 1.06), penche=11.0, lacet=15.0, plan=-10.0)
# Lecture : il lève le carnet devant la poitrine, couverture inclinée vers ses yeux (il le consulte). Joué au milieu
# des gestes de LECTURE (regarde_bas : mauvaise nouvelle, regret, attente), avec passage progressif (RAMPE).
LECTURE = dict(centre=(0.07, -0.33, 1.13), penche=50.0, lacet=12.0, plan=-10.0)
GESTES_LECTURE = {'regarde_bas'}
# Vie : la main suit en petit le mouvement du bras d'origine (VIE × écart à sa position moyenne dans le geste,
# au plus VIE_MAX, jamais vers le corps) : le carnet bouge au rythme du geste sans quitter le ventre.
VIE, VIE_MAX = 0.12, 0.025
POLE = Vector((0.6, 0.6, -0.5))     # coude : dehors, arrière, bas (repère du buste au repos)
L = 'mixamorig:Left'
CHAINE = [L + 'Arm', L + 'ForeArm', L + 'Hand']
DOIGTS = [L + 'HandIndex1', L + 'HandIndex2', L + 'HandIndex3', L + 'HandThumb1', L + 'HandThumb2', L + 'HandThumb3']

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
Wm = arm.matrix_world.copy(); Wi = Wm.inverted()
REST = {b.name: b.matrix_local.copy() for b in arm.data.bones}
PAR = {b.name: (b.parent.name if b.parent else None) for b in arm.data.bones}

# ---- relation main -> carnet, comme exporter-gabi-mixamo.py (le carnet n'est pas dans le .blend)
avant = {k: set(getattr(bpy.data, k)) for k in ('objects', 'meshes', 'materials', 'images', 'actions', 'armatures', 'textures', 'node_groups', 'cameras', 'lights', 'collections')}
action_avant = arm.animation_data.action if arm.animation_data else None
bpy.ops.import_scene.gltf(filepath=ORIGINE)
importes = [o for o in bpy.data.objects if o not in avant['objects']]
for o in importes:
    if o.animation_data: o.animation_data.action = None
    if o.type == 'ARMATURE':
        for pb in o.pose.bones: pb.matrix_basis.identity()
bpy.context.view_layer.update()
carnet = next(o for o in importes if o.type == 'MESH' and o.name.startswith('SM_GabiCarnet'))
CARNET_MONDE = carnet.matrix_world.copy()
Pc = np.array([list(v.co) for v in carnet.data.vertices])
CENTRE_LOCAL = Vector(((Pc.min(0) + Pc.max(0)) / 2).tolist())
EPAIS = float((Pc.max(0) - Pc.min(0))[1]); PC_MIN, PC_MAX = Pc.min(0), Pc.max(0)
C_SOMMETS = [Vector(p) for p in Pc[::7]]       # échantillon pour le contrôle de distance
MAIN_REPOS = Wm @ REST[L + 'Hand']
C = MAIN_REPOS.inverted() @ CARNET_MONDE         # main (monde) -> carnet (monde)
for k, s in avant.items():
    for d in [x for x in getattr(bpy.data, k) if x not in s]:
        getattr(bpy.data, k).remove(d)
print('carnet : centre local', tuple(round(x, 3) for x in CENTRE_LOCAL), 'épaisseur', round(EPAIS, 3))

# ---- tenues, exprimées dans le repère de Spine1
SPINE = 'mixamorig:Spine1'


def tenue(t):
    c = Vector(t['centre'])
    R = (Matrix.Rotation(math.radians(t['lacet']), 3, 'Z') @ Matrix.Rotation(math.radians(-t['penche']), 3, 'X')
         @ Matrix.Rotation(math.radians(t['plan']), 3, 'Y'))
    return (Wm @ REST[SPINE]).inverted() @ Matrix.Translation(c - R @ CENTRE_LOCAL) @ R.to_4x4()


D_SPINE, D_LECTURE = tenue(TENUE), tenue(LECTURE)
AVANT_SPINE = ((Wm @ REST[SPINE]).to_3x3().inverted() @ Vector((0, -1, 0))).normalized()   # devant du ventre


# Ventre et poitrine (peau) : quand le buste se plie (déçu, rire), le bas du ventre, porté par les hanches, avance
# plus que Spine1 ; on calcule par image la peau sous le carnet (pondération des os, comme le jeu) et on écarte le
# carnet le long de sa normale pour garder ECART_PEAU entre son dos et la peau.
ECART_PEAU = 0.006
corps = bpy.data.objects['Mesh_0']
_Mc = corps.matrix_world
_P = np.array([list(_Mc @ v.co) for v in corps.data.vertices])
_zone = np.where((_P[:, 0] > -0.2) & (_P[:, 0] < 0.3) & (_P[:, 2] > 0.8) & (_P[:, 2] < 1.4) & (_P[:, 1] < -0.08))[0]
_groupes = {g.index: g.name for g in corps.vertex_groups}
PEAU_P = np.c_[_P[_zone], np.ones(len(_zone))]
PEAU_OS = sorted({_groupes[g.group] for i in _zone for g in corps.data.vertices[i].groups if _groupes[g.group] in REST})
PEAU_W = np.zeros((len(_zone), len(PEAU_OS)))
for k, i in enumerate(_zone):
    for g in corps.data.vertices[i].groups:
        nomg = _groupes[g.group]
        if nomg in REST: PEAU_W[k, PEAU_OS.index(nomg)] = g.weight
PEAU_W /= np.maximum(PEAU_W.sum(1, keepdims=True), 1e-9)


def peau(pose):
    """Peau du ventre et de la poitrine en coordonnées monde pour la pose courante (skinning linéaire)."""
    out = np.zeros((len(PEAU_P), 3))
    for j, b in enumerate(PEAU_OS):
        M = np.array(Wm @ pose[b] @ REST[b].inverted() @ Wi)
        out += PEAU_W[:, j:j + 1] * (PEAU_P @ M[:3].T)
    return out


def ecarter(Dw, P):
    """Écarte le carnet (matrice monde Dw) de la peau P si son dos s'en approche à moins de ECART_PEAU."""
    Li = np.array(Dw.inverted()); Q = P @ Li[:3, :3].T + Li[:3, 3]
    lo, hi = PC_MIN, PC_MAX
    dans = (Q[:, 0] > lo[0] - 0.01) & (Q[:, 0] < hi[0] + 0.01) & (Q[:, 2] > lo[2] - 0.01) & (Q[:, 2] < hi[2] + 0.01)
    if not dans.any(): return Dw, 0.0
    y = Q[dans, 1]; cote = 1.0 if np.median(y) > (lo[1] + hi[1]) / 2 else -1.0
    marge = (y - hi[1]).min() if cote > 0 else (lo[1] - y).min()
    pousse = max(0.0, ECART_PEAU - marge)
    if pousse <= 0: return Dw, 0.0
    n = Dw.to_3x3() @ Vector((0, -cote * pousse, 0))
    return Matrix.Translation(n) @ Dw, pousse


def melange(A, B, w):
    if w <= 0: return A
    t = A.translation.lerp(B.translation, w); q = A.to_quaternion().slerp(B.to_quaternion(), w)
    return Matrix.Translation(t) @ q.to_matrix().to_4x4()
POLE_SPINE = (Wm @ REST[SPINE]).to_3x3().inverted() @ POLE
L1 = arm.data.bones[CHAINE[0]].length; L2 = arm.data.bones[CHAINE[1]].length
REL_REPOS = (Wm @ REST[CHAINE[1]]).to_3x3().inverted() @ (Wm @ REST[CHAINE[2]]).to_3x3()
UP_REPOS = (Wm @ REST[CHAINE[0]]).to_3x3()


def repere(y, x_pref):
    y = y.normalized(); x = (x_pref - y * x_pref.dot(y))
    if x.length < 1e-6: x = Vector((1, 0, 0)) if abs(y.x) < 0.9 else Vector((0, 0, 1)); x = x - y * x.dot(y)
    x.normalize(); return Matrix((x, y, x.cross(y))).transposed()


def ik(S, Mspine3, H):
    """Matrices monde (4x4) du bras, de l'avant-bras et de la main pour amener la main en H."""
    W = H.translation; d = min((W - S).length, L1 + L2 - 1e-4); ax = (W - S).normalized()
    a = (L1 * L1 - L2 * L2 + d * d) / (2 * d); h = math.sqrt(max(L1 * L1 - a * a, 0))
    pole = Mspine3 @ POLE_SPINE; pp = (pole - ax * pole.dot(ax)).normalized()
    E = S + ax * a + pp * h; W = S + ax * d
    uy = (E - S).normalized(); Ru = UP_REPOS @ Matrix.Identity(3)
    Ru = (UP_REPOS.col[1].rotation_difference(uy).to_matrix()) @ UP_REPOS
    fy = (W - E).normalized()
    porte = uy.rotation_difference(fy).to_matrix() @ Ru          # avant-bras sans torsion propre au coude
    Rh = H.to_3x3(); best = None
    for al in range(-90, 91, 5):
        Rf = Matrix.Rotation(math.radians(al), 3, fy) @ porte
        cout = (Rf.inverted() @ Rh @ REL_REPOS.inverted()).to_quaternion().angle + 0.35 * abs(math.radians(al))
        if best is None or cout < best[0]: best = (cout, Rf)
    Rf = best[1]
    return [Matrix.Translation(S) @ Ru.to_4x4(), Matrix.Translation(E) @ Rf.to_4x4(), Matrix.Translation(W) @ Rh.to_4x4()]


def channelbag(act):
    return anim_utils.action_get_channelbag_for_slot(act, act.slots[0])


for t in arm.animation_data.nla_tracks: t.mute = True
repos = bpy.data.actions['repos']
arm.animation_data.action = repos; arm.animation_data.action_slot = repos.slots[0]
sc.frame_set(0)
PRISE = {b: arm.pose.bones[b].rotation_quaternion.copy() for b in DOIGTS}

traites = []
for tr in arm.animation_data.nla_tracks:
    act = tr.strips[0].action; nom = tr.name
    if nom in IGNORES: continue
    arm.animation_data.action = act; arm.animation_data.action_slot = act.slots[0]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1]); n = f1 - f0 + 1
    rampe = int(RAMPE * FPS)
    vals = {b: [] for b in CHAINE + DOIGTS}
    # position de la main d'origine dans le repère du buste (pour la « vie »)
    mains = []; pousses = []
    for f in range(f0, f1 + 1):
        sc.frame_set(f)
        mains.append(arm.pose.bones[SPINE].matrix.inverted() @ arm.pose.bones[L + 'Hand'].head)
    moyenne = sum(mains, Vector()) / len(mains)
    for f in range(f0, f1 + 1):
        i = f - f0; milieu = min(1.0, min(i, n - 1 - i) / rampe); milieu = milieu * milieu * (3 - 2 * milieu)
        w = 1.0 - milieu if nom in CONSULTE else 1.0
        lecture = milieu if nom in GESTES_LECTURE else 0.0
        sc.frame_set(f)
        pose = {b: pb.matrix.copy() for b, pb in arm.pose.bones.items()}
        orig = {b: arm.pose.bones[b].rotation_quaternion.copy() for b in CHAINE + DOIGTS}
        if w <= 0.0:
            for b in CHAINE + DOIGTS: vals[b].append(orig[b])
            continue
        Msp = Wm @ pose[SPINE]
        ecart = (mains[i] - moyenne) * VIE
        dehors = ecart.dot(AVANT_SPINE)
        if dehors < 0: ecart -= AVANT_SPINE * dehors
        if ecart.length > VIE_MAX: ecart *= VIE_MAX / ecart.length
        D = melange(D_SPINE, D_LECTURE, lecture)
        D = Matrix.Translation(ecart) @ D
        Dw, pousse = ecarter(Msp @ D, peau(pose))
        pousses.append(pousse)
        H = Dw @ C.inverted()
        S = Wm @ pose[CHAINE[0]].translation
        cible = ik(S, Msp.to_3x3().normalized(), H)
        parent = pose[PAR[CHAINE[0]]]
        for b, Mw in zip(CHAINE, cible):
            Ma = Wi @ Mw; p = PAR[b]
            base = parent @ REST[p].inverted() @ REST[b]
            q = (base.inverted() @ Ma).to_quaternion()
            parent = Ma
            q0 = orig[b]
            if q0.dot(q) < 0: q.negate()
            vals[b].append(q0.slerp(q, w))
        for b in DOIGTS:
            q = PRISE[b].copy()
            if orig[b].dot(q) < 0: q.negate()
            vals[b].append(orig[b].slerp(q, w))
    cb = channelbag(act)
    for b in CHAINE + DOIGTS:
        prev = None
        for i, q in enumerate(vals[b]):
            if prev is not None and prev.dot(q) < 0: q.negate()
            prev = q
        for j in range(4):
            chemin = f'pose.bones["{b}"].rotation_quaternion'
            fc = cb.fcurves.find(chemin, index=j)
            if fc: cb.fcurves.remove(fc)
            fc = act.fcurve_ensure_for_datablock(arm, chemin, index=j)
            fc.keyframe_points.add(n)
            fc.keyframe_points.foreach_set('co', [v for i in range(n) for v in (float(f0 + i), vals[b][i][j])])
            fc.update()
    traites.append(nom)
    print('tenue du carnet :', nom, n, 'images ; écarté de la peau sur', sum(1 for x in pousses if x > 0), 'images, au plus',
          round(max(pousses or [0]) * 1000, 1), 'mm', flush=True)

# ---- contrôle : distance entre le carnet et le corps, quelques images par geste
from mathutils.bvhtree import BVHTree
corps = bpy.data.objects['Mesh_0']
pire = []
for tr in arm.animation_data.nla_tracks:
    nom = tr.name
    if nom not in traites: continue
    act = tr.strips[0].action; arm.animation_data.action = act; arm.animation_data.action_slot = act.slots[0]
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    for f in np.linspace(f0, f1, 6).astype(int):
        sc.frame_set(int(f))
        dg = bpy.context.evaluated_depsgraph_get(); ev = corps.evaluated_get(dg)
        me = ev.to_mesh(); me.transform(corps.matrix_world)
        bvh = BVHTree.FromPolygons([v.co.copy() for v in me.vertices], [tuple(p.vertices) for p in me.polygons])
        ev.to_mesh_clear()
        Mc = Wm @ arm.pose.bones[L + "Hand"].matrix @ C
        dmin, dedans = 9.0, 0
        for v in C_SOMMETS:
            p = Mc @ v; loc, nor, idx, dist = bvh.find_nearest(p)
            if loc is None: continue
            s = (p - loc).dot(nor)
            if s < 0 and dist < 0.05: dedans += 1; dist = -dist     # entré dans la peau (près de la surface)
            dmin = min(dmin, dist)
        pire.append((dmin, nom, int(f), dedans))
pire.sort()
print('sous la peau à plus de 5 mm :', sorted({(n, f) for d, n, f, k in pire if d < -0.005}))
print('contrôle carnet-corps (m, négatif = sous la peau ; points sous la peau) : pires', [(round(d, 3), n, f, k) for d, n, f, k in pire[:8]])
print('médiane', round(float(np.median([p[0] for p in pire])), 3), 'max', round(max(p[0] for p in pire), 3))
arm.animation_data.action = None
for t in arm.animation_data.nla_tracks: t.mute = False
bpy.ops.wm.save_mainfile()
print('ok', len(traites), 'gestes')
