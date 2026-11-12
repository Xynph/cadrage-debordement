# Prépare un personnage du jeu pour l'envoi sur Mixamo (Upload Character) : maillages seuls, pose de repos,
# formes de bouche conservées, textures incluses, accessoire tenu en main retiré.
# Usage : python3 exporter-personnage-mixamo.py <personnage.glb> <sortie.fbx>   (pip install bpy)
import bpy, sys, os
src, out = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
# retirer le carnet (accessoire), l'armature et les animations
for o in list(bpy.data.objects):
    if o.type == 'MESH' and ('Carnet' in o.name or o.name.startswith('Icosphere')):
        bpy.data.objects.remove(o, do_unlink=True)
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
for o in meshes:
    for m in list(o.modifiers):
        if m.type == 'ARMATURE': o.modifiers.remove(m)
    mw = o.matrix_world.copy()
    o.parent = None
    o.matrix_world = mw
    o.vertex_groups.clear()
for o in list(bpy.data.objects):
    if o.type != 'MESH': bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions): bpy.data.actions.remove(a)
for o in meshes:
    print(o.name, len(o.data.vertices), [k.name for k in o.data.shape_keys.key_blocks] if o.data.shape_keys else '-', [round(v,3) for v in o.matrix_world.translation], [round(d,3) for d in o.dimensions])
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.fbx(filepath=out, use_selection=True, object_types={'MESH'}, apply_scale_options='FBX_SCALE_ALL',
    path_mode='COPY', embed_textures=True, mesh_smooth_type='FACE', use_mesh_modifiers=False, bake_anim=False, add_leaf_bones=False)
print('ok', os.path.getsize(out))
