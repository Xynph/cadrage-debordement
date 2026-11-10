import bpy,math,json
from mathutils.bvhtree import BVHTree
body=bpy.data.objects["SK_Gabi"]
eyes=[bpy.data.objects[name] for name in ("Globe_L","Globe_R")]
objects=[body,*eyes]

deps=bpy.context.evaluated_depsgraph_get()
from itertools import product
failed=0
for phase, jaw in product((0,.14,.22,.30,.39,.46,.54,.64,.76,.85,.91,.96,1), (0,.66)):
    body.data.shape_keys.key_blocks["Machoire"].value=jaw
    rig=bpy.data.objects["Gabi_Rig"]
    rig.animation_data.action=bpy.data.actions["Repos" if jaw==0 else "Parole"]
    bpy.context.scene.frame_set(1 if jaw==0 else 22)
    a,b=(phase/.54,0.0) if phase<=.54 else ((1-phase)/.46,(phase-.54)/.46)
    for obj in objects:
        keys=obj.data.shape_keys.key_blocks
        keys["Paupiere_Mi"].value=a
        keys["Paupiere_Fermee"].value=b
    bpy.context.view_layer.update()
    evaluated=body.evaluated_get(deps)
    skin=evaluated.to_mesh()
    skin_vertices=[evaluated.matrix_world @ vert.co for vert in skin.vertices]
    skin_tris=[tuple(poly.vertices) for poly in skin.polygons]
    tissue=BVHTree.FromPolygons(skin_vertices,skin_tris,all_triangles=True)
    counts={}
    for eye in eyes:
        eye_eval=eye.evaluated_get(deps)
        globe=eye_eval.to_mesh()
        eye_bvh=BVHTree.FromPolygons([eye_eval.matrix_world @ vert.co for vert in globe.vertices],
                                     [tuple(poly.vertices) for poly in globe.polygons],all_triangles=True)
        counts[eye.name]=len(tissue.overlap(eye_bvh))
        eye_eval.to_mesh_clear()
    evaluated.to_mesh_clear()
    failed+=sum(counts.values())
    print("LIDS",phase,jaw,json.dumps(counts))
assert failed == 0, f"{failed} intersecting triangle pairs across the sampled poses"
