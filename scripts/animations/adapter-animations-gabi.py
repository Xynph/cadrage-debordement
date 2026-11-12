# Adapte des animations Mixamo au Gabi rigué par Mixamo (même nommage d'os, autres proportions, autre pose de repos).
# Usage : python3 adapter-animations-gabi.py -- <gabi-rig.blend|gabi-mixamo.fbx> <gestes-gabi.json> <sortie.blend|.glb> [--racine <dossier>]
#   gabi-rig.blend : sortie de ajouter-pouces-gabi.py (conseillé : pouces mobiles).
#   Les chemins de gestes-gabi.json sont relatifs à --racine (défaut : dossier du .json), rangés ainsi :
#     generique/<nom>.fbx (téléchargés sur X Bot), packs/<pack>/<nom>.fbx, gabi/<nom>.fbx (téléchargés avec Gabi sélectionné).
# Entrées et sorties hors du dépôt public (fichiers Mixamo, licence). Blender en module Python (pip install bpy).
import bpy, sys, json, os
from mathutils import Matrix, Vector, Quaternion
argv = sys.argv[sys.argv.index('--')+1:]
gabi, specf, outf = argv[:3]
racine = argv[argv.index('--racine')+1] if '--racine' in argv else os.path.dirname(os.path.abspath(specf))
spec = json.load(open(specf)); FPS = 30
for it in spec: it['fbx'] = it['fbx'] if os.path.isabs(it['fbx']) else os.path.join(racine, it['fbx'])
if gabi.endswith('.blend'):
    bpy.ops.wm.open_mainfile(filepath=gabi)
else:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=gabi)
sc = bpy.context.scene; sc.render.fps = FPS
tgt = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
if tgt.animation_data: tgt.animation_data_clear()
# repos du rig : la pose de repos de Mixamo-avec-peau est la pose T
Tw = tgt.matrix_world.copy(); Tq = Tw.to_quaternion()
order = []
def walk(b):
    order.append(b.name); [walk(c) for c in b.children]
[walk(b) for b in tgt.data.bones if b.parent is None]
REST = {b.name: b.matrix_local.copy() for b in tgt.data.bones}; PAR = {b.name: (b.parent.name if b.parent else None) for b in tgt.data.bones}
for pb in tgt.pose.bones: pb.rotation_mode = 'QUATERNION'
t_hips = (Tw @ REST['mixamorig:Hips'].to_translation()).z
# Revers des manches : pièces séparées que Mixamo a pondérées entre bras et avant-bras ;
# elles glissaient. On les accroche entièrement à l'avant-bras.
for o in bpy.data.objects:
    if o.type == 'MESH' and o.name.startswith('Gabi_Revers_'):
        cote = 'Right' if o.name.endswith('_D') else 'Left'
        g = o.vertex_groups.get('mixamorig:%sForeArm' % cote) or o.vertex_groups.new(name='mixamorig:%sForeArm' % cote)
        for vg in list(o.vertex_groups):
            if vg != g: o.vertex_groups.remove(vg)
        g.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
# Doigts : une seule chaîne plie les quatre doigts collés ; flexion réduite de moitié pour ne pas ouvrir les fentes.
DOIGTS = 0.5
for it in spec:
    before = set(bpy.data.objects); ab = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=it['fbx'])
    new = [o for o in bpy.data.objects if o not in before]
    src = next(o for o in new if o.type == 'ARMATURE')
    act = max((a for a in bpy.data.actions if a not in ab), key=lambda a: a.frame_range[1]-a.frame_range[0])
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    if it.get('fin'): f1 = min(f1, f0 + int(it['fin']*FPS))
    Sw = src.matrix_world.copy(); Sq = Sw.to_quaternion()
    srest = {b.name: Sq @ b.matrix_local.to_quaternion() for b in src.data.bones}
    # Alignement des poses de repos (Gabi a été rigué bras baissés, X Bot est en T) :
    # rotation monde qui amène l'os de Gabi au repos sur la direction de l'os source au repos.
    ALIGN = {}
    for b in src.data.bones:
        if b.name not in tgt.data.bones: continue
        ds = (Sw @ b.tail_local - Sw @ b.head_local).normalized()
        tb = tgt.data.bones[b.name]; dt = (Tw @ tb.tail_local - Tw @ tb.head_local).normalized()
        ALIGN[b.name] = dt.rotation_difference(ds)
    s_hips0 = Sw @ src.data.bones['mixamorig:Hips'].head_local
    k = t_hips / s_hips0.z
    names = [b for b in order if b in src.pose.bones]
    frames = []
    for f in range(f0, f1+1):
        sc.frame_set(f)
        rot = {b: (Sq @ src.pose.bones[b].matrix.to_quaternion()) @ srest[b].inverted() for b in names}
        frames.append((rot, (Sw @ src.pose.bones['mixamorig:Hips'].head) - s_hips0))
    for o in new: bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.actions.remove(act)
    n = len(frames); net = frames[-1][1] - frames[0][1]
    a = bpy.data.actions.new(it['nom']); tgt.animation_data_create(); tgt.animation_data.action = a
    data = {b: [] for b in names}; hips = []; prev = {}
    for i, (rot, d) in enumerate(frames):
        d = d.copy()
        if it.get('sur_place', True):
            d.x -= frames[0][1].x + net.x * i / max(n-1, 1); d.y -= frames[0][1].y + net.y * i / max(n-1, 1)
        M = {}
        for b in order:
            p = PAR[b]; base = (M[p] @ REST[p].inverted() @ REST[b]) if p else REST[b].copy()
            if b in rot:
                q = Tq.inverted() @ rot[b] @ ALIGN.get(b, Quaternion()) @ Tq @ REST[b].to_quaternion()
                pos = (Tw.inverted() @ (Tw @ REST[b].to_translation() + d * k)) if b == 'mixamorig:Hips' else base.to_translation()
                Mb = Matrix.Translation(pos) @ q.to_matrix().to_4x4()
            else: Mb = base
            M[b] = Mb
            if b in rot:
                L = base.inverted() @ Mb; q = L.to_quaternion()
                if 'HandIndex' in b: q = Quaternion().slerp(q, DOIGTS)
                if b in prev and prev[b].dot(q) < 0: q.negate()
                prev[b] = q; data[b].append(q)
                if b == 'mixamorig:Hips': hips.append(L.to_translation())
    for b in names:
        for j in range(4):
            fc = a.fcurve_ensure_for_datablock(tgt, f'pose.bones["{b}"].rotation_quaternion', index=j)
            fc.keyframe_points.add(n); fc.keyframe_points.foreach_set('co', [v for i in range(n) for v in (float(i), data[b][i][j])]); fc.update()
    for j in range(3):
        fc = a.fcurve_ensure_for_datablock(tgt, 'pose.bones["mixamorig:Hips"].location', index=j)
        fc.keyframe_points.add(n); fc.keyframe_points.foreach_set('co', [v for i in range(n) for v in (float(i), hips[i][j])]); fc.update()
    a.use_fake_user = True
    tr = tgt.animation_data.nla_tracks.new(); tr.name = it['nom']; tr.strips.new(it['nom'], 0, a).name = it['nom']
    tgt.animation_data.action = None
    print('ok', it['nom'], n, flush=True)
if outf.endswith('.blend'): bpy.ops.wm.save_as_mainfile(filepath=outf)
else:
    bpy.ops.export_scene.gltf(filepath=outf, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_skins=True, export_morph=True, export_yup=True)
print('exporté', outf, os.path.getsize(outf))
