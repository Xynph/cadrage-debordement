# Mesure chaque .fbx d'un dossier : os, durée, déplacement net du bassin, amplitude, écart de boucle.
# Usage : python3 analyser-animations.py <dossier> <sortie.json>   (pip install bpy)
import bpy, sys, os, glob, json, math
root, out = sys.argv[-2], sys.argv[-1]
files = sorted(glob.glob(os.path.join(root, '**', '*.fbx'), recursive=True))
def fcurves(act):
    if hasattr(act, 'layers') and len(act.layers):
        r = []
        for L in act.layers:
            for s in L.strips:
                for cb in s.channelbags: r += list(cb.fcurves)
        return r
    return list(act.fcurves)
rows = []
for i, f in enumerate(files):
    rel = os.path.relpath(f, root)
    try:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.context.scene.render.fps = 30
        bpy.ops.import_scene.fbx(filepath=f, automatic_bone_orientation=False)
        arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
        meshes = [o for o in bpy.data.objects if o.type == 'MESH']
        d = dict(f=rel, bones=len(arm.data.bones) if arm else 0, skin=len(meshes), verts=sum(len(m.data.vertices) for m in meshes), anims=len(bpy.data.actions))
        if bpy.data.actions:
            act = max(bpy.data.actions, key=lambda a: a.frame_range[1]-a.frame_range[0])
            fr = act.frame_range; fc = fcurves(act)
            hips = [c for c in fc if 'Hips"].location' in c.data_path]
            d['dur'] = round((fr[1]-fr[0])/30, 3)
            d['keys'] = max((len(c.keyframe_points) for c in hips), default=0)
            sc = arm.scale[0] if arm else 1
            if len(hips) == 3:
                hips.sort(key=lambda c: c.array_index)
                P = [[c.evaluate(t) * sc for c in hips] for t in range(int(fr[0]), int(fr[1])+1)]
                # os Hips Mixamo : X latéral, Y haut, Z avant (repère de l'os, avant correction d'axes)
                d['net'] = [round(P[-1][k]-P[0][k], 2) for k in range(3)]
                d['amp'] = [round(max(p[k] for p in P)-min(p[k] for p in P), 2) for k in range(3)]
                d['h0'] = round(P[0][1], 2); d['hmin'] = round(min(p[1] for p in P), 2)
                # boucle : écart de pose entre première et dernière image sur les rotations
                rot = [c for c in fc if 'rotation_quaternion' in c.data_path]
                if rot:
                    e = max(abs(c.evaluate(fr[0]) - c.evaluate(fr[1])) for c in rot)
                    d['loop'] = round(e, 3)
        rows.append(d)
    except Exception as ex:
        rows.append(dict(f=rel, err=str(ex)[:200]))
    if i % 40 == 0: print(i, len(files), rel, flush=True)
json.dump(rows, open(out, 'w'), ensure_ascii=False, indent=0)
print('fini', len(rows))
