from pathlib import Path
import json
import sys

import bpy
import numpy as np
from mathutils.bvhtree import BVHTree


def smoothstep(low, high, value):
    blend = np.clip((value - low) / (high - low), 0.0, 1.0)
    return blend * blend * (3.0 - 2.0 * blend)


def normals(coords, triangles):
    first, second, third = coords[triangles].transpose(1, 0, 2)
    return np.cross(second - first, third - first)


def overlaps(coords, triangles, affected):
    vertices = coords.tolist()
    whole = BVHTree.FromPolygons(vertices, triangles.tolist(), all_triangles=True)
    subset = triangles[affected]
    patch = BVHTree.FromPolygons(vertices, subset.tolist(), all_triangles=True)
    return {
        tuple(sorted((int(affected[a]), b))) for a, b in patch.overlap(whole)
        if not set(subset[a]).intersection(triangles[b])
    }


output = Path(sys.argv[sys.argv.index('--') + 1])
body = bpy.data.objects['SK_Gabi']
rig = bpy.data.objects['Gabi_Rig']
keys = body.data.shape_keys.key_blocks
before = {key.name: np.array([vertex.co[:] for vertex in key.data]) for key in keys}
basis = before['Basis']
x, y, z = basis.T

# Bring back the two hooked locks which project from the rear silhouette.
# All changes are behind the ear plane. The top hair volume and collar stay fixed.
mask = smoothstep(.098, .140, y) * smoothstep(1.590, 1.620, z) * (1 - smoothstep(1.666, 1.704, z))
shift = -.012 * mask
selected = np.flatnonzero(abs(shift) > 1e-6)
assert selected.size > 50
for key in keys:
    for index in selected:
        key.data[int(index)].co.y += float(shift[index])
body.data.update()

revised = np.array([vertex.co[:] for vertex in keys['Basis'].data])
assert np.array_equal(basis[:, [0, 2]], revised[:, [0, 2]])
outside = np.ones(len(basis), dtype=bool)
outside[selected] = False
assert np.array_equal(basis[outside], revised[outside])
for key in keys:
    after = np.array([vertex.co[:] for vertex in key.data])
    assert np.array_equal(before[key.name] - basis, after - revised), key.name

triangles = np.array([tuple(face.vertices) for face in body.data.polygons])
affected = np.flatnonzero(np.any(~outside[triangles], axis=1))
old_normals = normals(basis, triangles[affected])
new_normals = normals(revised, triangles[affected])
minimum_area_ratio = float(np.min(np.linalg.norm(new_normals, axis=1) / np.linalg.norm(old_normals, axis=1)))
flipped = int(np.sum(np.einsum('ij,ij->i', old_normals, new_normals) <= 0))
old_contacts = overlaps(basis, triangles, affected)
new_contacts = overlaps(revised, triangles, affected)
assert not flipped and minimum_area_ratio > .55, (flipped, minimum_area_ratio)
assert not (new_contacts - old_contacts), (new_contacts - old_contacts)
info = {
    'vertices_changed': int(len(selected)),
    'max_moved_mm': float(np.max(np.linalg.norm(revised - basis, axis=1)) * 1000),
    'bounds_m': [basis[selected].min(axis=0).tolist(), basis[selected].max(axis=0).tolist()],
    'morph_deltas_identical': True,
    'triangles_checked': int(len(affected)),
    'flipped': flipped,
    'min_triangle_area_ratio': minimum_area_ratio,
    'nonadjacent_intersections_v6': len(old_contacts),
    'nonadjacent_intersections_essai': len(new_contacts),
}
(output / 'geometrie.json').write_text(json.dumps(info, indent=2), encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(output / 'gabi-nuque.blend'))

rig.animation_data.nla_tracks.remove(rig.animation_data.nla_tracks['Controle_Epaules'])
bpy.data.actions.remove(bpy.data.actions['Controle_Epaules'])
bpy.ops.object.select_all(action='DESELECT')
for obj in (body, rig, bpy.data.objects['Globe_L'], bpy.data.objects['Globe_R']):
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=str(output / 'gabi_nuque.glb'), export_format='GLB',
    export_image_format='JPEG', export_jpeg_quality=92, use_selection=True,
    export_skins=True, export_animation_mode='ACTIONS', export_frame_range=False,
    export_optimize_animation_size=True, export_morph=True, export_morph_normal=True,
)
