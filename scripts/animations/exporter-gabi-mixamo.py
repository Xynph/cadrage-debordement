# Exporte le Gabi rigué par Mixamo et ses gestes en un .glb pour le jeu, avec le carnet du Gabi
# d'origine réattaché à la main gauche (même placement visuel : les deux modèles partagent le même
# maillage en pose de repos).
# Usage : python3 exporter-gabi-mixamo.py -- <gabi.blend> <gabi-origine.glb> <sortie.glb>   (pip install bpy)
#   <gabi.blend>        : sortie .blend de adapter-animations-gabi.py (Gabi rigué + une piste NLA par geste)
#   <gabi-origine.glb>  : native/godot/guide/assets/gabi.glb (source du carnet)
# Ni l'entrée ni la sortie ne vont dans le dépôt public : elles contiennent des animations Mixamo.
import bpy, sys, os
blend, origine, sortie = sys.argv[sys.argv.index('--') + 1:][:3]
bpy.ops.wm.open_mainfile(filepath=blend)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
MAIN = 'mixamorig:LeftHand'
if arm.animation_data: arm.animation_data.action = None
arm.data.pose_position = 'REST'
avant_objets, avant_actions = set(bpy.data.objects), set(bpy.data.actions)
bpy.ops.import_scene.gltf(filepath=origine)
importes = [o for o in bpy.data.objects if o not in avant_objets]
for o in importes:
    if o.animation_data: o.animation_data.action = None
    if o.type == 'ARMATURE':
        for pb in o.pose.bones: pb.matrix_basis.identity()
bpy.context.view_layer.update()
# Matériaux du Gabi d'origine : l'aller-retour FBX par Mixamo les a simplifiés (teinte 0,8, transparence
# des lèvres, cartes de rugosité perdues). Les maillages ayant les mêmes UV, on remet ceux d'origine.
origine_mats = {}
for o in importes:
    if o.type == 'MESH':
        for m in o.data.materials:
            if m: origine_mats[m.name.rsplit('.', 1)[0] if m.name[-4:-3] == '.' and m.name[-3:].isdigit() else m.name] = m
carnet = next(o for o in importes if o.type == 'MESH' and o.name.startswith('SM_GabiCarnet'))
monde = carnet.matrix_world.copy()
carnet.parent = None
for o in importes:
    if o is not carnet: bpy.data.objects.remove(o, do_unlink=True)
for a in list(bpy.data.actions):
    if a not in avant_actions: bpy.data.actions.remove(a)
remplaces = 0
for o in bpy.data.objects:
    if o.type != 'MESH' or o is carnet: continue
    for i, m in enumerate(o.data.materials):
        if m and m.name in origine_mats and origine_mats[m.name] is not m:
            o.data.materials[i] = origine_mats[m.name]; remplaces += 1
for nom, m in origine_mats.items():
    ancien = bpy.data.materials.get(nom)
    if ancien and ancien is not m and ancien.users == 0: bpy.data.materials.remove(ancien)
    m.name = nom
for im in bpy.data.images:
    if im.users == 0: bpy.data.images.remove(im)
print('matériaux d\'origine remis', remplaces)
carnet.name = 'SM_GabiCarnet'
carnet.parent = arm
carnet.parent_type = 'BONE'
carnet.parent_bone = MAIN
bpy.context.view_layer.update()
carnet.matrix_world = monde
bpy.context.view_layer.update()
ecart = max(abs(a - b) for ra, rb in zip(carnet.matrix_world, monde) for a, b in zip(ra, rb))
print('carnet sur', MAIN, 'écart', round(ecart, 6))
arm.data.pose_position = 'POSE'
for o in bpy.data.objects:
    o.select_set(True)
pistes = [t.name for t in arm.animation_data.nla_tracks]
bpy.ops.export_scene.gltf(filepath=sortie, export_format='GLB', export_animations=True,
    export_animation_mode='NLA_TRACKS', export_force_sampling=True, export_skins=True, export_morph=True,
    export_morph_animation=False, export_yup=True, export_apply=False)
print('exporté', sortie, os.path.getsize(sortie), 'animations', len(pistes))
