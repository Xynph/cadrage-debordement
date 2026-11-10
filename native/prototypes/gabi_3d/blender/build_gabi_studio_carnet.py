"""Derive a single notebook action and bone attachment from the exact V8 rig."""
from pathlib import Path
import json
import math
import sys

import bpy
import numpy as np
from mathutils import Euler, Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

out = Path(sys.argv[sys.argv.index("--") + 1])
out.mkdir(parents=True, exist_ok=True)
rig = bpy.data.objects["Gabi_Rig"]
body = bpy.data.objects["SK_Gabi"]
scene = bpy.context.scene
idle = bpy.data.actions["Repos"]
first, last = map(round, idle.frame_range)
bones = ("UpperArm.L", "Forearm.L", "Hand.L")
book_dimensions = Vector((.15, .025, .20))
args = sys.argv[sys.argv.index("--") + 2:]
review_only = "--review" in args
old_sleeve = Path(args[args.index("--sleeve") + 1]) if "--sleeve" in args else None
preview_book = Path(args[args.index("--prop") + 1]) if "--prop" in args else None


def frame(action, time):
    rig.animation_data.action = action
    scene.frame_set(time)
    bpy.context.view_layer.update()


def aim_bone(name, target):
    bone = rig.pose.bones[name]
    direction = (Vector(target) - bone.head).normalized()
    delta = bone.y_axis.rotation_difference(direction)
    bone.matrix = Matrix.LocRotScale(bone.head, delta @ bone.matrix.to_quaternion(), (1, 1, 1))
    bpy.context.view_layer.update()
    return bone.rotation_quaternion.copy()


def vertices():
    mesh = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    points = np.empty(len(mesh.data.vertices) * 3, dtype=np.float32)
    mesh.data.vertices.foreach_get("co", points)
    return points.reshape(-1, 3)


def axis_angle(a,b):
    return math.degrees(a.normalized().angle(b.normalized()))


def relative_lengths(a, b, edges):
    start = np.linalg.norm(a[edges[:,0]] - a[edges[:,1]], axis=1)
    end = np.linalg.norm(b[edges[:,0]] - b[edges[:,1]], axis=1)
    ratio = end[start>1e-6]/start[start>1e-6]
    return {"samples":len(ratio),"p05":float(np.percentile(ratio,5)), "p95":float(np.percentile(ratio,95)),
            "p99":float(np.percentile(ratio,99)), "min":float(ratio.min()), "max":float(ratio.max())}


frame(idle,first)
base = vertices()
shoulder_rest = rig.pose.bones[bones[0]].y_axis.copy()
clip = idle.copy()
clip.name = "Carnet"
clip.use_fake_user = True
frame(clip, first)
hold = {
    "UpperArm.L": aim_bone("UpperArm.L", (.258, -.065, 1.146)),
    "Forearm.L": aim_bone("Forearm.L", (.090, -.218, 1.236)),
    "Hand.L": aim_bone("Hand.L", (-.060, -.262, 1.246)),
}
hold["Hand.L"] @= Quaternion((0,1,0),math.radians(28))
rig.pose.bones["Hand.L"].rotation_quaternion = hold["Hand.L"]
bpy.context.view_layer.update()
pose = Matrix.Translation(Vector((.000, -.173, 1.278))) @ Euler(tuple(map(math.radians, (-18, -11, 3)))).to_matrix().to_4x4()
attachment = bpy.data.objects.new("AttacheCarnet", None)
bpy.context.collection.objects.link(attachment)
attachment.parent = rig
attachment.parent_type = "BONE"
attachment.parent_bone = "Hand.L"
attachment.matrix_world = pose
bpy.context.view_layer.update()
book_rest = attachment.matrix_world.copy()
keys = sorted({round(k.co.x) for layer in clip.layers for strip in layer.strips for bag in strip.channelbags
               for curve in bag.fcurves for k in curve.keyframe_points})
for at in keys:
    frame(clip, at)
    for name, q in hold.items():
        bone = rig.pose.bones[name]
        bone.rotation_quaternion = q
        bone.keyframe_insert("rotation_quaternion", frame=at, group=name)
frame(clip,first)

weight_map = {v.name:v.index for v in body.vertex_groups}
edges = np.array([e.vertices[:] for e in body.data.edges], dtype=np.int32)
triangles = np.array([f.vertices[:] for f in body.data.polygons], dtype=np.int32)
weights = np.zeros((len(base),len(weight_map)),dtype=np.float32)
for vertex in body.data.vertices:
    for group in vertex.groups: weights[vertex.index,group.group] = group.weight
correction = None
corrective_report = None
if old_sleeve:
    with np.load(old_sleeve) as data:
        donor_coords = data["coordinates"]
        donor_weights = data["weights"]
        donor_names = list(data["names"])
    source_basis = body.data.shape_keys.key_blocks["Basis"]
    local = np.empty(len(source_basis.data)*3,dtype=np.float32)
    source_basis.data.foreach_get("co",local)
    local = local.reshape(-1,3)
    locator = KDTree(len(donor_coords))
    for index, coordinate in enumerate(donor_coords):
        locator.insert(coordinate,index)
    donor_weights = donor_weights[:,[donor_names.index(name) for name in weight_map]]
    locator.balance()

    def ramp(lo,hi,x):
        t = min(1.0,max(0.0,(x-lo)/(hi-lo)))
        return t*t*(3-2*t)

    modified = weights.copy()
    for i, co in enumerate(local):
        x,_,z = co
        fade = ramp(.12,.20,x) * ramp(.98,1.07,z) * (1-ramp(1.35,1.46,z))
        if fade <= 0.0:
            continue
        _, donor_id, distance = locator.find(co)
        if distance > 1e-5:
            continue
        substitute = donor_weights[donor_id]
        if substitute.sum() > 1e-6:
            modified[i] += fade * (substitute/substitute.sum() - modified[i])

    indices = np.flatnonzero(np.max(abs(modified-weights),axis=1) > 1e-4)
    ordered = list(weight_map)
    matrices = np.array([rig.pose.bones[n].matrix @ rig.data.bones[n].matrix_local.inverted() for n in ordered])
    rest_skin = np.einsum("ij,jkl->ikl",weights[indices],matrices)
    alt_skin = np.einsum("ij,jkl->ikl",modified[indices],matrices)
    current = vertices()
    local_homogeneous = np.column_stack([local[indices],np.ones(len(indices),dtype=np.float32)])
    reference_pose = np.einsum("nij,nj->ni",rest_skin,local_homogeneous)[:,:3]
    skin_fit_error = float(np.max(np.linalg.norm(reference_pose-current[indices],axis=1)))
    assert skin_fit_error < 1e-5, skin_fit_error
    target_pose = np.einsum("nij,nj->ni",alt_skin,local_homogeneous)[:,:3]
    correction_co = local.copy()
    correction_co[indices] = np.linalg.solve(rest_skin[:,:3,:3],(target_pose-rest_skin[:,:3,3])[...,None])[...,0]
    corrective_report = {
        "vertices":len(indices),
        "max_correction_mm":float(1000*np.max(np.linalg.norm(correction_co-local,axis=1))),
        "verification_pose_reference_mm":skin_fit_error*1000,
        "lowest_skin_determinant":float(np.min(np.linalg.det(rest_skin[:,:3,:3]))),
        "bounds_m":[local[indices].min(axis=0).tolist(),local[indices].max(axis=0).tolist()],
    }
    correction = body.shape_key_add(name="CorrectionCarnet",from_mix=False)
    correction.data.foreach_set("co",correction_co.reshape(-1))
    correction.value = 1.0
    body.data.update()
    bpy.context.view_layer.update()

left_hand = weights[:,weight_map["Hand.L"]] > .68
left_forearm = weights[:,weight_map["Forearm.L"]] > .55
left_limb = weights[:,weight_map["Hand.L"]] + weights[:,weight_map["Forearm.L"]] > .50
left_shoulder = ((weights[:,weight_map["UpperArm.L"]]>.45)&(base[:,2] > 1.26)) | (weights[:,weight_map["Clavicle.L"]]>.36)
torso = sum(weights[:,weight_map[n]] for n in ("Pelvis","Spine","Chest","Neck")) > .50
torso_faces = triangles[np.all(torso[triangles],axis=1)].tolist()
shoulder_edges = edges[np.all(left_shoulder[edges],axis=1)]
forearm_edges = edges[np.all(left_forearm[edges],axis=1)]
samples = np.linspace(-.95,.95,9)
book_size = np.array(tuple(book_dimensions))
qa = {"angles_deg":{}, "samples":[], "book_dimensions_m":book_size.tolist(), "clip":clip.name, "keys":keys,
      "pose_blender":[list(row) for row in book_rest], "corrective":corrective_report}
for at in np.linspace(first,last,17).astype(int):
    frame(clip,int(at))
    current = vertices()
    upper, fore, hand = (rig.pose.bones[n] for n in bones)
    xf = attachment.matrix_world.copy()
    local = (current - np.array(tuple(xf.translation))) @ np.array(xf.to_3x3())
    half = book_size / 2
    hands = local[left_hand]
    in_book = np.all(np.abs(hands)<half,axis=1)
    depth = np.min(half-np.abs(hands),axis=1)
    limb_depth = np.min(half-np.abs(local[left_limb]),axis=1)
    near_cover = np.abs(hands[:,0])<half[0]
    near_cover &= np.abs(hands[:,2])<half[2]
    skin_to_cover = -half[1] - hands[near_cover,1]
    rear = BVHTree.FromPolygons(current.tolist(),torso_faces,all_triangles=True)
    gap = []
    direction = xf.to_3x3().col[1].normalized()
    for x in samples:
        for z in samples:
            origin = xf @ Vector((x*half[0],half[1]-.09,z*half[2]))
            contact, _, _, distance = rear.ray_cast(origin,direction,.23)
            if contact is not None: gap.append((distance-.09)*1000)
    qa["samples"].append({
       "frame":int(at),"elbow_flex_deg":axis_angle(upper.y_axis,fore.y_axis),"wrist_flex_deg":axis_angle(fore.y_axis,hand.y_axis),
       "shoulder_movement_deg":axis_angle(shoulder_rest,upper.y_axis),"hand_vertices_inside":int(in_book.sum()),
       "hand_max_penetration_mm":float(max(0,depth.max())*1000),
       "limb_max_penetration_mm":float(max(0,limb_depth.max())*1000),
       "hand_cover_distance_mm":([float(skin_to_cover.min()*1000),float(np.percentile(np.abs(skin_to_cover),10)*1000)] if skin_to_cover.size else []),
       "torso_gap_min_med_max_mm":([float(min(gap)),float(np.median(gap)),float(max(gap))] if gap else []),
       "torso_book_penetration_samples":sum(d<-1.0 for d in gap),
       "shoulder_edges":relative_lengths(base,current,shoulder_edges),
       "forearm_edges":relative_lengths(base,current,forearm_edges),
       "attachment_xyz_mm":[float(v*1000) for v in xf.translation],
    })
qa["loop_attachment_delta_mm"]=1000*(attachment.matrix_world.translation-book_rest.translation).length
(out/"qa-pose.json").write_text(json.dumps(qa,indent=2),encoding="utf-8")
print("Pose frames",first,last,"keys",keys,"first",json.dumps(qa["samples"][0]),"loop delta mm",qa["loop_attachment_delta_mm"])
frame(clip,first)

if review_only:
    if preview_book:
        existing_objects=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(preview_book))
        preview=[obj for obj in bpy.data.objects if obj not in existing_objects]
        for obj in preview:
            if obj.parent is None:
                obj.parent=attachment
    else:
        bpy.ops.mesh.primitive_cube_add(size=1)
        block=bpy.context.object
        block.name="Repere_Carnet_temporaire"
        block.dimensions=book_dimensions
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        block.parent=attachment
        block.matrix_basis=Matrix.Identity(4)
        mat=bpy.data.materials.new("M_Bloc_Carnet")
        mat.diffuse_color=(.15,.065,.024,1)
        shader=next(n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
        shader.inputs["Base Color"].default_value=mat.diffuse_color
        shader.inputs["Roughness"].default_value=.82
        block.data.materials.append(mat)
        preview=[block]
    camera=scene.camera
    camera.data.type="ORTHO"
    camera.data.ortho_scale=1.22
    scene.render.resolution_percentage=78
    target=Vector((0,0,1.23))
    for label,angle in [("face",0),("trois-quarts",30),("profil",90)]:
        rad=math.radians(angle)
        camera.location=target+Vector((3.5*math.sin(rad),-3.5*math.cos(rad),0.035))
        camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
        scene.render.filepath=str(out/f"{label}.png")
        bpy.ops.render.render(write_still=True)
    for obj in preview: bpy.data.objects.remove(obj,do_unlink=True)

bpy.ops.wm.save_as_mainfile(filepath=str(out/"gabi-carnet-studio.blend"))
if correction is not None:
    correction.value = 0.0
rig.animation_data.nla_tracks.remove(rig.animation_data.nla_tracks["Controle_Epaules"])
bpy.data.actions.remove(bpy.data.actions["Controle_Epaules"])
bpy.ops.object.select_all(action="DESELECT")
for obj in (body,rig,bpy.data.objects["Globe_L"],bpy.data.objects["Globe_R"],attachment): obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(out/"extraction_carnet.glb"),export_format="GLB",
   export_image_format="JPEG",export_jpeg_quality=92,use_selection=True,export_skins=True,
   export_animation_mode="ACTIONS",export_frame_range=False,export_optimize_animation_size=True,export_morph=True,export_morph_normal=True)
