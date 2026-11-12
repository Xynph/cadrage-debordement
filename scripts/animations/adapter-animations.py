# Adapte des animations Mixamo (squelette mixamorig, 65 os) au squelette du joueur du jeu (Quaternius, 31 os).
# Outil hors jeu (Blender en module Python : pip install bpy). Les fichiers Mixamo ne sont jamais
# dans le dépôt : leur licence interdit de les redistribuer. La bibliothèque produite non plus.
# Usage : python3 adapter-animations.py -- <joueur.glb> <liste.json> <sortie.glb|.blend> <mesures.json>
#           [--racine <dossier des .fbx>] [--sans-maillage]
# liste.json : [{"nom": "mx_course", "fbx": "Standard Run.fbx", "sur_place": true}, ...]
#   sur_place : retire l'avancée du bassin (boucles de déplacement) ; sinon le déplacement est gardé.
# Méthode : pour chaque os, rotation monde de la source par rapport à sa pose de repos (T), appliquée
# à la pose de repos du joueur (T aussi). Bassin : déplacement mis à l'échelle des jambes (horizontal)
# et de la hauteur du bassin (vertical). Pieds : os libres sous la racine chez ce joueur, recollés au
# bout du tibia ; le corps est remonté si un pied passerait sous le sol.
import bpy, sys, json, math, os
from mathutils import Matrix, Vector, Quaternion
ath, specf, outf, metaf = sys.argv[sys.argv.index('--')+1:][:4]
spec = json.load(open(specf))
RACINE = sys.argv[sys.argv.index('--racine')+1] if '--racine' in sys.argv else os.path.dirname(os.path.abspath(specf))
P = 'mixamorig:'
MAP = {  # os du joueur <- os Mixamo
 'Body':'Hips','Hips':'Spine','Abdomen':'Spine1','Torso':'Spine2','Neck':'Neck','Head':'Head',
 'Shoulder.L':'LeftShoulder','UpperArm.L':'LeftArm','LowerArm.L':'LeftForeArm','Palm.L':'LeftHand',
 'MiddleHand.L':'LeftHandMiddle1','Fingers.L':'LeftHandMiddle2','Thumb1.L':'LeftHandThumb1','Thumb2.L':'LeftHandThumb2',
 'Shoulder.R':'RightShoulder','UpperArm.R':'RightArm','LowerArm.R':'RightForeArm','Palm.R':'RightHand',
 'MiddleHand.R':'RightHandMiddle1','Fingers.R':'RightHandMiddle2','Thumb1.R':'RightHandThumb1','Thumb2.R':'RightHandThumb2',
 'UpperLeg.L':'LeftUpLeg','LowerLeg.L':'LeftLeg','Foot.L':'LeftFoot','UpperLeg.R':'RightUpLeg','LowerLeg.R':'RightLeg','Foot.R':'RightFoot'}
FEET = {'Foot.L':'LowerLeg.L','Foot.R':'LowerLeg.R'}  # pieds : os libres sous la racine, à recoller au bout du tibia
FPS = 30
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene; sc.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=ath)
tgt = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
if tgt.animation_data: tgt.animation_data_clear()
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.name.startswith('Icosphere'): bpy.data.objects.remove(o, do_unlink=True)
if '--sans-maillage' in sys.argv:
    for o in list(bpy.data.objects):
        if o.type == 'MESH': bpy.data.objects.remove(o, do_unlink=True)
Tw = tgt.matrix_world.copy(); Tw_rot = Tw.to_quaternion(); t_scale = Tw.to_scale()[0]
order = []  # parents d'abord
def walk(b):
    order.append(b.name)
    for c in b.children: walk(c)
for b in tgt.data.bones:
    if b.parent is None: walk(b)
order = [b for b in order if b not in ('Foot.L','Foot.R')] + ['Foot.L','Foot.R']
REST = {b.name: b.matrix_local.copy() for b in tgt.data.bones}
PAR = {b.name: (b.parent.name if b.parent else None) for b in tgt.data.bones}
for pb in tgt.pose.bones: pb.rotation_mode = 'QUATERNION'
t_leg = (Tw @ REST['UpperLeg.L'].to_translation()).z - (Tw @ REST['Foot.L'].to_translation()).z
foot_off = {f: REST[l].inverted() @ REST[f] for f, l in FEET.items()}
meta = {}
def fcurves_of(act):
    if hasattr(act, 'layers') and len(act.layers):
        return [c for L in act.layers for s in L.strips for cb in s.channelbags for c in cb.fcurves]
    return list(act.fcurves)
for it in spec:
    before = set(bpy.data.objects); acts_before = set(bpy.data.actions)
    bpy.ops.import_scene.fbx(filepath=it['fbx'] if os.path.isabs(it['fbx']) else os.path.join(RACINE, it['fbx']))
    new = [o for o in bpy.data.objects if o not in before]
    src = next(o for o in new if o.type == 'ARMATURE')
    act = max((a for a in bpy.data.actions if a not in acts_before), key=lambda a: a.frame_range[1]-a.frame_range[0])
    f0, f1 = int(round(act.frame_range[0])), int(round(act.frame_range[1]))
    if it.get('debut') is not None: f0 = f0 + int(round(it['debut']*FPS))
    if it.get('fin') is not None: f1 = min(f1, int(round(act.frame_range[0])) + int(round(it['fin']*FPS)))
    Sw = src.matrix_world.copy(); Sw_rot = Sw.to_quaternion()
    srest = {b.name: (Sw_rot @ b.matrix_local.to_quaternion()) for b in src.data.bones}
    s_hips_rest = Sw @ src.data.bones[P+'Hips'].head_local
    s_leg = (Sw @ src.data.bones[P+'LeftUpLeg'].head_local).z - (Sw @ src.data.bones[P+'LeftFoot'].head_local).z
    k = t_leg / s_leg
    kz = (Tw @ REST['Body'].to_translation()).z / s_hips_rest.z
    frames = []
    for f in range(f0, f1+1):
        sc.frame_set(f)
        rot = {t: (Sw_rot @ src.pose.bones[P+s].matrix.to_quaternion()) @ srest[P+s].inverted() for t, s in MAP.items()}
        hips = Sw @ src.pose.bones[P+'Hips'].head
        feet = [(Sw @ src.pose.bones[P+n].head).z for n in ('LeftFoot','RightFoot')]
        frames.append((rot, hips.copy(), min(feet)))
    for o in new: bpy.data.objects.remove(o, do_unlink=True)
    bpy.data.actions.remove(act)
    n = len(frames)
    net = frames[-1][1] - frames[0][1]
    inplace = bool(it.get('sur_place'))
    body_rest = Tw @ REST['Body'].to_translation()
    out = {b: {'q': [], 'p': []} for b in order}
    prevq = {}
    s_foot_rest = None
    foot_rest_z = min((Tw @ REST[f].to_translation()).z for f in FEET)
    for i, (rot, hips, sfoot) in enumerate(frames):
      lift = 0.0
      for attempt in (0, 1):
            d = hips - s_hips_rest
            if inplace:
                u = i/(n-1) if n > 1 else 0
                d.x -= net.x*u + (frames[0][1].x - s_hips_rest.x); d.y -= net.y*u + (frames[0][1].y - s_hips_rest.y)
            body_w = body_rest + Vector((d.x*k, d.y*k, d.z*kz + lift))
            M = {}
            for b in order:
                p = PAR[b]
                base = (M[p] @ REST[p].inverted() @ REST[b]) if p else REST[b].copy()
                if b in MAP:
                    q_arm = Tw_rot.inverted() @ rot[b] @ Tw_rot @ REST[b].to_quaternion()
                    if b == 'Body': pos = Tw.inverted() @ body_w
                    elif b in FEET: pos = (M[FEET[b]] @ foot_off[b]).to_translation()
                    else: pos = base.to_translation()
                    Mb = Matrix.Translation(pos) @ q_arm.to_matrix().to_4x4()
                else:
                    Mb = base
                M[b] = Mb
                L = base.inverted() @ Mb
                q = L.to_quaternion()
                if attempt == 0: continue
                if b in prevq and prevq[b].dot(q) < 0: q.negate()
                prevq[b] = q
                out[b]['q'].append(q); out[b]['p'].append(L.to_translation())
            if attempt == 0:
                low = min((Tw @ M[f].to_translation()).z for f in FEET)
                lift = max(0.0, foot_rest_z - low)
    # écrire l'action
    name = it['nom']
    a = bpy.data.actions.new(name)
    tgt.animation_data_create(); tgt.animation_data.action = a
    for b in order:
        if b not in MAP: continue
        pb = tgt.pose.bones[b]
        chans = [('rotation_quaternion', 4, lambda i, j, b=b: out[b]['q'][i][j])]
        if b == 'Body' or b in FEET: chans.append(('location', 3, lambda i, j, b=b: out[b]['p'][i][j]))
        for path, dim, get in chans:
            for j in range(dim):
                fc = a.fcurve_ensure_for_datablock(tgt, f'pose.bones["{b}"].{path}', index=j)
                fc.keyframe_points.add(n)
                co = [0.0]*(2*n)
                for i in range(n): co[2*i] = float(i); co[2*i+1] = get(i, j)
                fc.keyframe_points.foreach_set('co', co)
                fc.keyframe_points.foreach_set('interpolation', [1]*n)  # LINEAR
                fc.update()
    a.use_fake_user = True
    tr = tgt.animation_data.nla_tracks.new(); tr.name = name
    st = tr.strips.new(name, 0, a); st.name = name
    tgt.animation_data.action = None
    meta[name] = dict(source=os.path.basename(it['fbx']), duree=round((n-1)/FPS, 3), images=n, sur_place=inplace,
        deplacement_source_m=[round(net.x, 3), round(net.y, 3)], vitesse_source_m_s=round(math.hypot(net.x, net.y)/max((n-1)/FPS, 1e-6), 3),
        echelle_jambes=round(k, 4))
    bpy.data.orphans_purge(do_recursive=True)
    print('ok', name, n, 'images', flush=True)
json.dump(meta, open(metaf, 'w'), ensure_ascii=False, indent=1)
if outf.endswith('.blend'):
    bpy.ops.wm.save_as_mainfile(filepath=outf)
else:
    bpy.ops.export_scene.gltf(filepath=outf, export_format='GLB', export_animations=True, export_animation_mode='NLA_TRACKS',
        export_force_sampling=True, export_frame_step=1, export_optimize_animation_size=False, export_skins=True, export_yup=True)
print('exporté', outf, os.path.getsize(outf))
