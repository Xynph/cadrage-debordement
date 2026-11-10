from pathlib import Path
import bpy
import json
import numpy as np
import sys
from mathutils.bvhtree import BVHTree

out = Path(sys.argv[sys.argv.index('--') + 1])
prop_path = Path(sys.argv[sys.argv.index('--') + 2])
body = bpy.data.objects['SK_Gabi']
rig = bpy.data.objects['Gabi_Rig']
anchor = bpy.data.objects['AttacheCarnet']
scene = bpy.context.scene
rig.animation_data.action = bpy.data.actions['Carnet']
body.data.shape_keys.key_blocks['CorrectionCarnet'].value = 1
bpy.ops.import_scene.gltf(filepath=str(prop_path))
prop = bpy.data.objects['SM_GabiCarnet']
prop.parent = anchor
body_groups = {g.name:g.index for g in body.vertex_groups}
hand_id = body_groups['Hand.L']
hand_map = np.array([sum(g.weight for g in v.groups if g.group == hand_id) for v in body.data.vertices])
forearm_id = body_groups['Forearm.L']
forearm_map = np.array([sum(g.weight for g in v.groups if g.group == forearm_id) for v in body.data.vertices])
left_limb = hand_map+forearm_map
bind = np.array([v.co[:] for v in body.data.vertices])
results = []
for frame in range(1,162,8):
    scene.frame_set(frame)
    bpy.context.view_layer.update()
    now = bpy.context.evaluated_depsgraph_get()
    shell = body.evaluated_get(now).data
    object_mesh = prop.evaluated_get(now)
    mesh = object_mesh.data
    shell.calc_loop_triangles()
    mesh.calc_loop_triangles()
    triangles = [f.vertices[:] for f in shell.loop_triangles]
    visible = BVHTree.FromPolygons([v.co for v in shell.vertices],triangles,all_triangles=True)
    book = BVHTree.FromPolygons([object_mesh.matrix_world @ v.co for v in mesh.vertices],[f.vertices[:] for f in mesh.loop_triangles],all_triangles=True)
    pairs = visible.overlap(book)
    other = [i for i,_ in pairs if max(hand_map[j] for j in triangles[i]) < .50]
    outside = [i for i,_ in pairs if max(left_limb[j] for j in triangles[i]) < .50]
    if frame == 1:
        for name,ids in [('hand+', [i for i,_ in pairs]),('non hand',other),('non limb',outside)]:
            if ids:
                used=sorted({j for i in ids for j in triangles[i]})
                world=np.array([shell.vertices[j].co[:] for j in used])
                print(name,len(ids),'bind',bind[used].min(0),bind[used].max(0),'posed',world.min(0),world.max(0),'hand weight',hand_map[used].min(),hand_map[used].max(),'forearm',forearm_map[used].min(),forearm_map[used].max())
    results.append({'frame':frame,'pairs':len(pairs),'other_than_hand':len(other),'outside_left_limb':len(outside)})
with out.open('w',encoding='utf-8') as f:
    json.dump({'triangles_prop':len(mesh.loop_triangles),'frames':results},f,indent=2)
print('pairs',min(r['pairs'] for r in results),max(r['pairs'] for r in results),'outside hand',max(r['other_than_hand'] for r in results))
assert all(r['pairs']==0 for r in results)
