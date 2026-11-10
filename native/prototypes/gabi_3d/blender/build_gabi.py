"""Build the isolated, animated Gabi prototype from the selected TRELLIS GLB."""

import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Vector


def options():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--landmarks", type=Path)
    parser.add_argument("--review-only", action="store_true")
    parser.add_argument("--mute-normal-map", action="store_true")
    parser.add_argument("--reference", type=Path)
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1 :])


def normalize(body):
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    coordinates = np.array([v.co[:] for v in body.data.vertices])
    low, high = coordinates.min(0), coordinates.max(0)
    origin = ((low[0] + high[0]) / 2, (low[1] + high[1]) / 2, low[2])
    coords = (coordinates - origin) * (1.8 / (high[2] - low[2]))
    body.data.vertices.foreach_set("co", coords.astype(np.float32).ravel())
    body.data.update()
    before = len(body.data.vertices)
    edit = bmesh.new()
    edit.from_mesh(body.data)
    bmesh.ops.remove_doubles(edit, verts=edit.verts[:], dist=0.000009)
    bmesh.ops.dissolve_degenerate(edit, edges=edit.edges[:], dist=0.000002)
    bmesh.ops.triangulate(edit, faces=edit.faces[:])
    bmesh.ops.recalc_face_normals(edit, faces=edit.faces[:])
    edit.to_mesh(body.data)
    edit.free()
    body.data.update()
    print(f"Welded {before - len(body.data.vertices)} duplicate seam vertices")
    body.name = "SK_Gabi"
    body.data.name = "Gabi_Mesh"


def make_rig(landmarks):
    armature = bpy.data.armatures.new("Gabi_Bones")
    rig = bpy.data.objects.new("Gabi_Rig", armature)
    bpy.context.scene.collection.objects.link(rig)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")

    def add(name, head, tail, parent=None, deform=True):
        bone = armature.edit_bones.new(name)
        bone.head, bone.tail = head, tail
        bone.use_deform = deform
        if parent:
            bone.parent = armature.edit_bones[parent]
            bone.use_connect = (bone.parent.tail - bone.head).length < 0.00001
        return bone

    pelvis = (0, 0.04, 0.86)
    spine = (0, 0.033, 1.025)
    chest = (0, 0.044, 1.22)
    neck = (0, 0.041, 1.447)
    head = (0, 0.016, 1.567)
    add("Root", (0, 0, 0), (0, -0.17, 0), deform=False)
    add("Pelvis", pelvis, spine, "Root")
    add("Spine", spine, chest, "Pelvis")
    add("Chest", chest, neck, "Spine")
    add("Neck", neck, head, "Chest")
    add("Head", head, (0, 0.002, 1.765), "Neck")

    for side, sign in [("L", 1), ("R", -1)]:
        p = landmarks[side]
        add(f"Clavicle.{side}", (sign * .049, .041, 1.412), p["shoulder"], "Chest")
        add(f"UpperArm.{side}", p["shoulder"], p["elbow"], f"Clavicle.{side}")
        add(f"Forearm.{side}", p["elbow"], p["wrist"], f"UpperArm.{side}")
        add(f"Hand.{side}", p["wrist"], p["fingers"], f"Forearm.{side}")
        add(f"Thigh.{side}", p["hip"], p["knee"], "Pelvis")
        add(f"Shin.{side}", p["knee"], p["ankle"], f"Thigh.{side}")
        add(f"Foot.{side}", p["ankle"], p["toe"], f"Shin.{side}")

    bpy.ops.object.mode_set(mode="OBJECT")
    rig.show_in_front = True
    return rig


V0_LANDMARKS = {
    "L": {
        "shoulder": (.225, .046, 1.398), "elbow": (.346, .066, 1.167),
        "wrist": (.458, -.022, .946), "fingers": (.491, -.028, .802),
        "hip": (.129, .026, .861), "knee": (.147, .041, .516),
        "ankle": (.173, .066, .120), "toe": (.211, -.141, .035),
    },
    "R": {
        "shoulder": (-.225, .044, 1.402), "elbow": (-.349, .020, 1.170),
        "wrist": (-.462, -.078, .945), "fingers": (-.499, -.100, .803),
        "hip": (-.129, .022, .861), "knee": (-.148, -.002, .518),
        "ankle": (-.174, .019, .118), "toe": (-.205, -.184, .035),
    },
}


def smoothstep(lower, upper, t):
    t = np.clip((t - lower) / (upper - lower), 0, 1)
    return t * t * (3 - 2 * t)


def weight_character(body, rig, landmarks):
    # The arm must separate from the torso below the armpit. A nearest-bone
    # rule would drag the sweater flank with it. Use explicit blend zones.
    vertices = np.array([v.co[:] for v in body.data.vertices])
    x, _, z = vertices.T
    ax = np.abs(x)
    rows = {}

    neck = smoothstep(1.445, 1.537, z) * (1 - smoothstep(.096, .186, ax))
    head = smoothstep(1.51, 1.589, z) * (1 - smoothstep(.142, .20, ax))
    head = np.maximum(head, smoothstep(1.53, 1.60, z))
    neck = np.maximum(neck, head)
    chest = smoothstep(1.06, 1.25, z)
    spine = smoothstep(.895, 1.055, z)
    arm_total = np.zeros(len(vertices))
    leg_total = np.zeros(len(vertices))

    for side, sign in [("L", 1), ("R", -1)]:
        p = landmarks[side]
        sx = sign * x
        # The inner edge of the upper arm progresses from the side of
        # the chest to the arm as Z falls. Its transition spans the deltoid.
        seam = np.interp(z, [.68, .98, 1.075, 1.175, 1.25, 1.36, 1.47, 1.55],
                         [.305, .311, .303, .280, .235, .185, .142, .21])
        spread = np.interp(z, [1.0, 1.16, 1.24, 1.34, 1.50],
                           [.016, .016, .028, .075, .082])
        arm = smoothstep(seam - spread, seam + spread, sx)
        arm *= smoothstep(.60, .69, z) * (1 - smoothstep(1.487, 1.543, z))
        arm_total += arm
        upper_axis = np.array(p["elbow"]) - p["shoulder"]
        upper_axis /= np.linalg.norm(upper_axis)
        fore_axis = np.array(p["wrist"]) - p["elbow"]
        fore_axis /= np.linalg.norm(fore_axis)
        shoulder_t = (vertices - p["shoulder"]) @ upper_axis
        elbow_t = (vertices - p["elbow"]) @ (upper_axis + fore_axis) / 2
        wrist_t = (vertices - p["wrist"]) @ fore_axis
        upper = smoothstep(-.03, .09, shoulder_t)
        fore = smoothstep(-.066, .068, elbow_t)
        hand = smoothstep(-.032, .037, wrist_t)
        fore = np.maximum(fore, hand)
        upper = np.maximum(upper, fore)
        rows[f"Clavicle.{side}"] = arm * (1 - upper)
        rows[f"UpperArm.{side}"] = arm * (upper - fore)
        rows[f"Forearm.{side}"] = arm * (fore - hand)
        rows[f"Hand.{side}"] = arm * hand

        # Feet stay planted while the upper body moves. The lower chain
        # remains usable in Blender for checking the asset beyond idle.
        leg = (1 - arm) * smoothstep(-.032, .032, sx) * (1 - smoothstep(.761, .943, z))
        leg_total += leg
        shin = 1 - smoothstep(.47, .564, z)
        foot = 1 - smoothstep(.086, .16, z)
        rows[f"Thigh.{side}"] = leg * (1 - shin)
        rows[f"Shin.{side}"] = leg * (shin - foot)
        rows[f"Foot.{side}"] = leg * foot

    center = 1 - arm_total - leg_total
    rows["Head"] = center * head
    rows["Neck"] = center * (neck - head)
    torso = center * (1 - neck)
    rows["Chest"] = torso * chest
    rows["Spine"] = torso * (1 - chest) * spine
    rows["Pelvis"] = torso * (1 - chest) * (1 - spine)

    names = tuple(rows)
    weights = np.column_stack(tuple(rows.values()))
    top = np.argsort(weights, axis=1)[:, -4:]
    retained = np.take_along_axis(weights, top, axis=1)
    retained[retained < .01] = 0
    totals = retained.sum(axis=1)
    assert np.all(totals > 0), "Vertices without weights"
    retained /= totals[:, None]
    groups = [body.vertex_groups.new(name=name) for name in names]
    for index, (ids, values) in enumerate(zip(top, retained)):
        for group_id, value in zip(ids, values):
            if value:
                groups[group_id].add([index], value, "REPLACE")

    skin = body.modifiers.new("Gabi_Skin", "ARMATURE")
    skin.object = rig
    body.parent = rig


def pose_key(rig, frame, rotations):
    for bone in rig.pose.bones:
        degrees = rotations.get(bone.name, (0, 0, 0))
        world = Euler(tuple(map(math.radians, degrees)), "XYZ").to_quaternion()
        rest = bone.bone.matrix_local.to_quaternion()
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = rest.inverted() @ world @ rest
        bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)


def make_action(rig, name, poses):
    rig.animation_data_create()
    data = rig.animation_data
    data.action = None
    for frame, rotations in poses:
        pose_key(rig, frame, rotations)
    action = data.action
    action.name = name
    action.use_fake_user = True
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.handle_left_type = "AUTO_CLAMPED"
                        key.handle_right_type = "AUTO_CLAMPED"
    track = data.nla_tracks.new()
    track.name = name
    track.strips.new(name, int(action.frame_range.x), action)
    track.mute = True
    data.action = None
    return action


def animation(rig):
    idle = {
        "UpperArm.L": (0, 20, 0), "UpperArm.R": (0, -20, 0),
        "Forearm.L": (-5, 1, 0), "Forearm.R": (-6, -1, 0),
    }
    inhale = idle | {"Chest": (-1.5, .5, 1), "Head": (1.5, -1, -2.7),
                     "UpperArm.L": (0, 18, 0), "UpperArm.R": (0, -19, 0)}
    settle = idle | {"Chest": (.6, -.55, -.9), "Head": (-1, 1.25, 2.3),
                     "UpperArm.L": (0, 21.5, 0), "UpperArm.R": (0, -20.5, 0)}
    idle_clip = make_action(rig, "Repos", [(1, idle), (21, idle), (58, inhale),
                                           (100, settle), (141, idle), (161, idle)])
    anticipation = idle | {"Head": (-3, -1.5, 1), "Chest": (-.7, 0, -.6),
                           "Clavicle.R": (-2, -2, 1),
                           "Forearm.R": (-16, -1, 2)}
    hand_up = idle | {"Head": (3, -1, -3), "Chest": (1.25, 0, -3),
                      "Clavicle.R": (-3, -3, 0), "UpperArm.R": (-9, -19, -3),
                      "Forearm.R": (-62, 3, 20), "Hand.R": (-8, -5, 3)}
    nod = hand_up | {"Head": (12, -2, -2), "Forearm.R": (-68, 4, 22),
                     "Hand.R": (-10, -5, 3)}
    released = idle | {"Head": (-2, 0, 2), "Forearm.R": (-17, -2, 0),
                       "UpperArm.R": (-3, -18, -3)}
    approval = make_action(rig, "Approbation", [(1, idle), (7, anticipation),
                           (19, hand_up), (25, nod), (34, hand_up),
                           (50, released), (62, idle), (69, idle)])
    open_arms = idle | {"UpperArm.L": (-3, -38, 0), "UpperArm.R": (-3, 38, 0),
                       "Forearm.L": (-17, 3, 0), "Forearm.R": (-17, -3, 0)}
    stress = make_action(rig, "Controle_Epaules", [(1, {}), (21, idle), (41, hand_up),
                         (66, open_arms), (88, idle)])
    speaking = idle | {"Chest": (-1.5, 0, -2), "Head": (-3, -1, -4),
                       "UpperArm.R": (-6, -18, 0), "Forearm.R": (-32, 2, 16)}
    emphasis = speaking | {"Head": (6, 0, -2), "Forearm.R": (-43, 2, 16),
                            "Hand.R": (-5, 0, 1)}
    speech = make_action(rig, "Parole", [(1, idle), (9, speaking), (23, emphasis),
                         (38, speaking), (58, idle), (65, idle)])
    return idle_clip, approval, speech, stress



def recalibrate_face_geometry(body):
    vertices = np.array([v.co[:] for v in body.data.vertices])
    x, y, z = vertices.T
    front = 1 - smoothstep(-.075, -.013, y)
    center = 1 - smoothstep(.036, .094, np.abs(x))
    moustache = np.exp(-((z - 1.592) / .019) ** 2)
    nose = np.exp(-((z - 1.633) / .018) ** 2)
    # Dampen the swollen upper lip without flattening the nose or jaw.
    vertices[:, 1] += front * center * (.016 * moustache + .006 * nose)
    body.data.vertices.foreach_set("co", vertices.astype(np.float32).ravel())
    body.data.update()


def project_face_albedo(body, material, reference, output):
    """Bake a feathered front-face photo projection onto the existing UV."""
    scene = bpy.context.scene
    graph = material.node_tree
    nodes, links = graph.nodes, graph.links
    shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    base = shader.inputs["Base Color"]
    source = base.links[0].from_socket
    surface = next(node for node in nodes if node.type == "OUTPUT_MATERIAL").inputs["Surface"]
    source_uv = body.data.uv_layers.active
    source_uv.name = "Surface"
    source_uv.active_render = True
    projection_uv = body.data.uv_layers.new(name="FaceProjection")
    mask = body.data.color_attributes.new(name="FaceProjectionMask", type="FLOAT_COLOR", domain="POINT")
    vertices = np.array([v.co[:] for v in body.data.vertices])
    normals = np.array([v.normal[:] for v in body.data.vertices])
    x, y, z = vertices.T
    unit = .594 / 740
    u = 310 + x / unit
    v = 370 - (z - 1.5642) / unit
    sx = np.interp(u, [150, 174, 210, 254, 310, 349, 398, 447],
                   [394, 408, 431, 456, 499, 538, 570, 605])
    sy = np.interp(v, [63, 103, 159, 206, 245, 282, 306, 331, 362, 403, 433],
                   [13, 27, 49, 96, 127, 152, 165, 180, 203, 230, 250])
    alpha = (1 - smoothstep(.057, .112, np.abs(x)))
    alpha *= smoothstep(1.522, 1.56, z) * (1 - smoothstep(1.742, 1.783, z))
    alpha *= 1 - smoothstep(-.04, .048, y)
    alpha *= smoothstep(.16, .79, -normals[:, 1])
    alpha *= .90
    mask.data.foreach_set("color", np.repeat(alpha[:, None], 4, axis=1).astype(np.float32).ravel())
    for loop in body.data.loops:
        idx = loop.vertex_index
        projection_uv.data[loop.index].uv = (sx[idx] / 1024, 1 - sy[idx] / 1536)
    body.data.uv_layers.active = source_uv

    projected = nodes.new("ShaderNodeTexImage")
    projected.image = bpy.data.images.load(str(reference), check_existing=True)
    projected_uv_node = nodes.new("ShaderNodeUVMap")
    projected_uv_node.uv_map = projection_uv.name
    links.new(projected_uv_node.outputs[0], projected.inputs["Vector"])
    mask_node = nodes.new("ShaderNodeVertexColor")
    mask_node.layer_name = mask.name
    tint = nodes.new("ShaderNodeMixRGB")
    tint.blend_type = "MULTIPLY"
    tint.inputs[0].default_value = 1
    tint.inputs[2].default_value = (.84, .81, .80, 1)
    links.new(projected.outputs["Color"], tint.inputs[1])
    mix = nodes.new("ShaderNodeMixRGB")
    links.new(mask_node.outputs["Color"], mix.inputs[0])
    links.new(source, mix.inputs[1])
    links.new(tint.outputs[0], mix.inputs[2])
    emission = nodes.new("ShaderNodeEmission")
    links.new(mix.outputs[0], emission.inputs[0])
    links.new(emission.outputs[0], surface)
    baked = nodes.new("ShaderNodeTexImage")
    baked.image = bpy.data.images.new("Gabi_Albedo", width=1536, height=1536, alpha=False)
    baked.image.colorspace_settings.name = "sRGB"
    nodes.active = baked
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.cycles.device = "CPU"
    bpy.ops.object.bake(type="EMIT", margin=12, use_clear=True)
    baked.image.filepath_raw = str(output / "gabi-albedo.png")
    baked.image.file_format = "PNG"
    baked.image.save()
    baked.image.pack()
    links.new(baked.outputs["Color"], base)
    links.new(shader.outputs[0], surface)
    for node in [projected, projected_uv_node, mask_node, tint, mix, emission]:
        nodes.remove(node)
    body.data.uv_layers.remove(projection_uv)
    body.data.color_attributes.remove(mask)


def lighting():
    scene = bpy.context.scene
    scene.render.fps = 30
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 720
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.color_mode = "RGBA"
    scene.world = bpy.data.worlds.new("ReviewStudio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (.2, .23, .29, 1)
    scene.world.node_tree.nodes["Background"].inputs[1].default_value = .42
    scene.view_settings.view_transform = "Khronos PBR Neutral"
    for name, location, power, size, color in [
        ("Key", (-2, -3, 4), 340, 2.9, (1, .92, .83)),
        ("Fill", (2, -2, 2), 140, 2.5, (.80, .89, 1)),
        ("Edge", (.8, 2.4, 3.6), 310, 2.4, (1, .95, .88)),
    ]:
        light = bpy.data.lights.new(name, "AREA")
        light.energy, light.size, light.color = power, size, color
        obj = bpy.data.objects.new(name, light)
        scene.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = (Vector((0, 0, 1.25)) - obj.location).to_track_quat("-Z", "Y").to_euler()
    data = bpy.data.cameras.new("Review_Camera")
    data.type = "ORTHO"
    camera = bpy.data.objects.new(data.name, data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera


def render_poses(rig, action, camera, output):
    scene = bpy.context.scene
    rig.animation_data.action = action
    poses = [
        ("a_pose", 1, 0, .9, 1.94),
        ("bras_bas", 21, 0, .9, 1.94),
        ("bras_bas_trois_quarts", 21, -40, 1.25, 1.19),
        ("bras_bas_dos", 21, 150, 1.25, 1.19),
        ("approbation", 41, -22, 1.22, 1.28),
        ("bras_ouverts", 66, 0, .9, 1.94),
        ("profil", 21, 90, 1.565, .57),
        ("visage", 21, 0, 1.565, .57),
    ]
    for name, frame, angle, height, scale in poses:
        scene.frame_set(frame)
        target = Vector((0, 0, height))
        azimuth = math.radians(angle)
        camera.location = target + Vector((3 * math.sin(azimuth), -3 * math.cos(azimuth), 0))
        camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
        camera.data.ortho_scale = scale
        scene.render.filepath = str(output / f"{name}.png")
        bpy.ops.render.render(write_still=True)
    rig.animation_data.action = None


def main():
    args = options()
    args.output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(args.source))
    body = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    normalize(body)
    material = body.data.materials[0]
    material.name = "M_Gabi"
    nodes = material.node_tree.nodes
    shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    metallic = shader.inputs["Metallic"]
    for link in list(metallic.links):
        material.node_tree.links.remove(link)
    metallic.default_value = 0
    roughness = shader.inputs["Roughness"]
    for link in list(roughness.links):
        material.node_tree.links.remove(link)
    roughness.default_value = .79
    for node in list(nodes):
        if node.type == "GROUP" and node.node_tree and node.node_tree.name == "glTF Material Output":
            nodes.remove(node)
    if args.reference:
        recalibrate_face_geometry(body)
        project_face_albedo(body, material, args.reference, args.output)
    if args.mute_normal_map:
        normal = shader.inputs["Normal"]
        for link in list(normal.links):
            material.node_tree.links.remove(link)
    landmarks = json.loads(args.landmarks.read_text(encoding="utf-8")) if args.landmarks else V0_LANDMARKS
    rig = make_rig(landmarks)
    weight_character(body, rig, landmarks)
    idle, _, _, stress = animation(rig)
    camera = lighting()
    render_poses(rig, stress, camera, args.output)
    rig.animation_data.action = idle
    bpy.context.scene.frame_set(1)
    bpy.context.scene.frame_end = 161
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(args.output / "gabi.blend"))
    if not args.review_only:
        rig.animation_data.nla_tracks.remove(rig.animation_data.nla_tracks["Controle_Epaules"])
        bpy.data.actions.remove(stress)
        bpy.ops.object.select_all(action="DESELECT")
        body.select_set(True)
        rig.select_set(True)
        bpy.context.view_layer.objects.active = rig
        bpy.ops.export_scene.gltf(
            filepath=str(args.output / "gabi.glb"),
            export_format="GLB",
            export_image_format="JPEG",
            export_jpeg_quality=92,
            use_selection=True,
            export_skins=True,
            export_animation_mode="ACTIONS",
            export_frame_range=False,
            export_optimize_animation_size=True,
        )
    print(f"{len(rig.data.bones)} bones / {len(body.data.polygons)} triangles")


if __name__ == "__main__":
    main()
