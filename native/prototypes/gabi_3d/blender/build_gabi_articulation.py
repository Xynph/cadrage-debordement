"""Three local lip shapes on the exact V7 basis, with no new topology."""

from pathlib import Path
import json
import sys

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree


def smoothstep(low, high, value):
    t = np.clip((value - low) / (high - low), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def curve_at(points, time):
    if time <= points[0][0] or time >= points[-1][0]:
        return 0.0
    for (a, wa), (b, wb) in zip(points[:-1], points[1:], strict=True):
        if time <= b:
            return wa + (wb - wa) * float(smoothstep(a, b, time))
    return 0.0


def contacts(coords, upper, lower):
    points = coords.tolist()
    first = BVHTree.FromPolygons(points, upper, all_triangles=True)
    second = BVHTree.FromPolygons(points, lower, all_triangles=True)
    return {(i, j) for i, j in first.overlap(second) if not set(upper[i]).intersection(lower[j])}


def normals(coords, faces):
    a, b, c = coords[faces].transpose(1, 0, 2)
    return np.cross(b - a, c - a)


out = Path(sys.argv[sys.argv.index('--') + 1])
curves = json.loads(Path(__file__).with_name('gabi-articulation-courbes.json').read_text(encoding='utf-8-sig'))
body = bpy.data.objects['SK_Gabi']
rig = bpy.data.objects['Gabi_Rig']
keys = body.data.shape_keys.key_blocks
original = {key.name: np.array([vert.co[:] for vert in key.data]) for key in keys}
basis = original['Basis']
x, y, z = basis.T
u = x / .054
axis = 1.5962 - .0061 * u * u + .0017 * u
above = z - axis
sign = 2 * smoothstep(-.0011, .0011, above) - 1
front = 1 - smoothstep(-.084, -.045, y)
width = 1 - smoothstep(.043, .070, abs(x))
height = 1 - smoothstep(.005, .022, abs(above))
centre = 1 - smoothstep(.020, .042, abs(x))
region = front * width * height

# Reduce width and let the lip rim protrude during rounded vowels.
rounded = np.column_stack((-.37 * x * region,
                           -.0061 * (.60 + .40 * centre) * region,
                           .0018 * sign * centre * region))
# Free the vertical opening locally on the open vowel, without moving the chin.
opened = np.column_stack((.025 * x * region,
                           -.0006 * centre * region,
                           np.where(sign >= 0, .0019, -.0027) * abs(sign) * centre * region))
# Stretch only a little on the two bright vowels, with no attempt at a smile.
spread = np.column_stack((.145 * x * region,
                           .0014 * centre * region,
                           .0005 * sign * centre * region))

shapes = {'ArrondiPhrase': rounded, 'OuverturePhrase': opened, 'EtirementPhrase': spread}
deltas = {}
for name, displacement in shapes.items():
    displacement[np.linalg.norm(displacement, axis=1) < 1e-5] = 0.0
    key = body.shape_key_add(name=name, from_mix=False)
    key.data.foreach_set('co', (basis + displacement).astype(np.float32).ravel())
    key.value = 0.0
    delta = np.array([vert.co[:] for vert in key.data]) - basis
    moved = np.any(delta != 0.0, axis=1)
    assert np.array_equal(moved, np.any(displacement != 0.0, axis=1)), name
    assert np.all(y[moved] < -.045) and np.all((z[moved] > 1.55) & (z[moved] < 1.63))
    deltas[name] = delta
body.data.update()
for name, before in original.items():
    assert np.array_equal(before, np.array([vert.co[:] for vert in keys[name].data])), name

triangles = np.array([tuple(poly.vertices) for poly in body.data.polygons])
material = body.data.materials.find('M_Gabi_LipPatch')
assert material >= 0
patch = np.array([poly.material_index == material for poly in body.data.polygons])
lip_faces = triangles[patch]
centres = basis[lip_faces].mean(axis=1)
centre_u = centres[:, 0] / .054
is_upper = centres[:, 2] >= 1.5962 - .0061 * centre_u ** 2 + .0017 * centre_u
upper, lower = lip_faces[is_upper].tolist(), lip_faces[~is_upper].tolist()
assert upper and lower
jaw_delta = original['Machoire'] - basis
changed = np.any(np.stack([delta != 0 for delta in deltas.values()]), axis=(0,2))
faces = triangles[np.any(changed[triangles], axis=1)]
errors = []
poses = []
for time in np.arange(0.0, 1.876, 1 / 60):
    round_weight, open_weight, stretch_weight, jaw = [curve_at(curves[name], time) for name in ['round','open','spread','jaw']]
    new_jaw = jaw * (1 - .38 * round_weight - .15 * stretch_weight) + .04 * open_weight
    same_jaw = basis + new_jaw * jaw_delta
    pose = same_jaw + round_weight * deltas['ArrondiPhrase'] + open_weight * deltas['OuverturePhrase'] + stretch_weight * deltas['EtirementPhrase']
    if not (round_weight or open_weight or stretch_weight): continue
    old_normals, new_normals = normals(same_jaw, faces), normals(pose, faces)
    flipped = int(np.sum(np.einsum('ij,ij->i', old_normals, new_normals) <= 0.0))
    new_contacts = len(contacts(pose, upper, lower) - contacts(same_jaw, upper, lower))
    if flipped or new_contacts:
        errors.append({'time_s':round(float(time),4), 'flipped':flipped, 'new_lip_contacts':new_contacts,
                       'round':round_weight,'open':open_weight,'spread':stretch_weight,'jaw':new_jaw})
    poses.append([round(float(time),4), round_weight, open_weight, stretch_weight, jaw, new_jaw])
info = {'basis_and_existing_morphs_identical':True, 'poses_checked':len(poses), 'errors':errors, 'shapes':{
    name:{'vertices':int(np.any(delta!=0,axis=1).sum()), 'max_mm':float(np.max(np.linalg.norm(delta,axis=1))*1000)}
    for name,delta in deltas.items()}, 'curves_sampled':poses}
(out / 'qa-lip-poses.json').write_text(json.dumps(info, indent=2), encoding='utf-8')
assert not errors, errors[:12]
bpy.ops.wm.save_as_mainfile(filepath=str(out / 'gabi-articulation.blend'))

rig.animation_data.nla_tracks.remove(rig.animation_data.nla_tracks['Controle_Epaules'])
bpy.data.actions.remove(bpy.data.actions['Controle_Epaules'])
bpy.ops.object.select_all(action='DESELECT')
for obj in (body, rig, bpy.data.objects['Globe_L'], bpy.data.objects['Globe_R']): obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/'gabi_articulation.glb'), export_format='GLB',
    export_image_format='JPEG', export_jpeg_quality=92, use_selection=True,
    export_skins=True, export_animation_mode='ACTIONS', export_frame_range=False,
    export_optimize_animation_size=True, export_morph=True, export_morph_normal=True)
