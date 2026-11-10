"""Feasibility study: held carnet as a rigid Blender bone attachment."""

import bmesh
import bpy
import math
import sys
from pathlib import Path
from mathutils import Euler, Matrix, Vector

output = Path(sys.argv[sys.argv.index("--") + 1])
output.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
rig = bpy.data.objects["Gabi_Rig"]
body = bpy.data.objects["SK_Gabi"]
idle = bpy.data.actions["Repos"]
rig.animation_data.action = idle
scene.frame_set(1)
bpy.context.view_layer.update()


def aim_bone(name, target):
    bone = rig.pose.bones[name]
    direction = (Vector(target) - bone.head).normalized()
    delta = bone.y_axis.rotation_difference(direction)
    rotation = delta @ bone.matrix.to_quaternion()
    bone.matrix = Matrix.LocRotScale(bone.head, rotation, (1, 1, 1))
    bpy.context.view_layer.update()
    return bone.rotation_quaternion.copy()


hold = {
    "UpperArm.L": aim_bone("UpperArm.L", (.258, -.066, 1.146)),
    "Forearm.L": aim_bone("Forearm.L", (.104, -.232, 1.229)),
    "Hand.L": aim_bone("Hand.L", (-.045, -.269, 1.239)),
}
for name in hold:
    bone = rig.pose.bones[name]
    print(name, "head", tuple(round(v, 3) for v in bone.head), "tail", tuple(round(v, 3) for v in bone.tail))


def material(name, color, roughness, metallic=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    shader = next(node for node in mat.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return mat


def cuboid(name, dimensions, center, mats, radius):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    part = bpy.context.object
    part.name = name
    part.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for mat in mats:
        part.data.materials.append(mat)
    if len(mats) > 1:
        for face in part.data.polygons:
            face.material_index = 1 if abs(face.normal.y) < .5 and face.normal.x > -.5 else 0
    bevel = part.modifiers.new("Reliure arrondie", "BEVEL")
    bevel.width = radius
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    edit = bmesh.new()
    edit.from_mesh(part.data)
    bmesh.ops.triangulate(edit, faces=edit.faces[:])
    edit.to_mesh(part.data)
    edit.free()
    return part



def bake_leather(parts, leather, output):
    """Bake a small grain map to the cover's shared cube UV layout."""
    cover = next(part for part in parts if part.name == "Carnet_Couverture")
    graph = leather.node_tree
    nodes, links = graph.nodes, graph.links
    shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    surface = next(node for node in nodes if node.type == "OUTPUT_MATERIAL").inputs["Surface"]
    coordinates = nodes.new("ShaderNodeTexCoord")
    grain = nodes.new("ShaderNodeTexNoise")
    grain.inputs["Scale"].default_value = 87
    grain.inputs["Detail"].default_value = 2.8
    links.new(coordinates.outputs["Generated"], grain.inputs["Vector"])
    body_wear = nodes.new("ShaderNodeTexNoise")
    body_wear.inputs["Scale"].default_value = 5.8
    body_wear.inputs["Detail"].default_value = 5.0
    links.new(coordinates.outputs["Generated"], body_wear.inputs["Vector"])
    combined = nodes.new("ShaderNodeMixRGB")
    combined.inputs[0].default_value = .67
    links.new(grain.outputs["Fac"], combined.inputs[1])
    links.new(body_wear.outputs["Fac"], combined.inputs[2])
    tones = nodes.new("ShaderNodeValToRGB")
    tones.color_ramp.elements[0].position = .15
    tones.color_ramp.elements[0].color = (.019, .008, .003, 1)
    tones.color_ramp.elements[1].position = .84
    tones.color_ramp.elements[1].color = (.19, .084, .026, 1)
    tones.color_ramp.elements.new(.50).color = (.069, .025, .010, 1)
    links.new(combined.outputs[0], tones.inputs[0])
    emission = nodes.new("ShaderNodeEmission")
    links.new(tones.outputs[0], emission.inputs[0])
    links.new(emission.outputs[0], surface)
    baked = nodes.new("ShaderNodeTexImage")
    baked.image = bpy.data.images.new("Carnet_Cuir", width=512, height=512, alpha=False)
    baked.image.colorspace_settings.name = "sRGB"
    nodes.active = baked
    bpy.ops.object.select_all(action="DESELECT")
    cover.select_set(True)
    bpy.context.view_layer.objects.active = cover
    old_engine = scene.render.engine
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.cycles.device = "CPU"
    bpy.ops.object.bake(type="EMIT", margin=5, use_clear=True)
    scene.render.engine = old_engine
    baked.image.filepath_raw = str(output / "carnet-cuir.png")
    baked.image.file_format = "PNG"
    baked.image.save()
    baked.image.pack()
    links.new(baked.outputs["Color"], shader.inputs["Base Color"])
    links.new(shader.outputs[0], surface)
    for node in [coordinates, grain, body_wear, combined, tones, emission]:
        nodes.remove(node)


leather = material("M_Carnet_Cuir", (.045, .021, .012), .79)
pages = material("M_Carnet_Papier", (.61, .48, .33), .93)
band = material("M_Carnet_Sangle", (.024, .012, .007), .88)
paper_tabs = material("M_Carnet_MarquePages", (.49, .36, .21), .88)

# Author the grip in the neutral review pose, then attach the parts to the hand.
# The top of the book follows the incline of the sweater and leaves the collar free.
center = Vector((.035, -.204, 1.278))
book_pose = Matrix.Translation(center) @ Euler(tuple(map(math.radians, (-22, -11, 3)))).to_matrix().to_4x4()
parts = [
    cuboid("Carnet_Corps", (.180, .022, .223), (0, 0, 0), (leather, pages), .003),
    cuboid("Carnet_Couverture", (.186, .0045, .228), (0, -.0121, 0), (leather,), .002),
    cuboid("Carnet_Dos", (.186, .0045, .228), (0, .0121, 0), (leather,), .002),
    cuboid("Carnet_Sangle", (.188, .0038, .012), (0, -.0147, -.024), (band,), .001),
    cuboid("Carnet_Onglet", (.036, .0009, .027), (.042, -.002, .116), (paper_tabs,), .0004),
    cuboid("Carnet_Onglet_Second", (.031, .0009, .024), (-.020, .002, .117), (paper_tabs,), .0004),
]
bake_leather(parts, leather, output)
for part in parts:
    matrix = book_pose @ part.matrix_world
    part.parent = rig
    part.parent_type = "BONE"
    part.parent_bone = "Hand.L"
    part.matrix_world = matrix
    bpy.context.view_layer.update()

for clip in ("Repos", "Approbation", "Parole"):
    action = bpy.data.actions[clip]
    rig.animation_data.action = action
    frames = sorted({round(point.co.x) for layer in action.layers for strip in layer.strips
                     for bag in strip.channelbags for curve in bag.fcurves
                     for point in curve.keyframe_points})
    for frame in frames:
        scene.frame_set(frame)
        for name, quaternion in hold.items():
            bone = rig.pose.bones[name]
            bone.rotation_quaternion = quaternion
            bone.keyframe_insert("rotation_quaternion", frame=frame, group=name)

camera = scene.camera
camera.data.type = "ORTHO"
poses = [
    ("01-carnet-repos", "Repos", 1, 0, 1.26, 1.18),
    ("02-carnet-trois-quarts", "Repos", 1, 30, 1.26, 1.18),
    ("03-carnet-profil", "Repos", 1, 80, 1.25, 1.16),
    ("04-carnet-appui", "Repos", 60, -35, 1.24, 1.23),
    ("05-carnet-approbation", "Approbation", 25, -22, 1.25, 1.21),
    ("06-carnet-parole", "Parole", 23, -19, 1.25, 1.21),
]
for name, clip, frame, angle, height, scale in poses:
    rig.animation_data.action = bpy.data.actions[clip]
    scene.frame_set(frame)
    target = Vector((0, 0, height))
    azimuth = math.radians(angle)
    camera.location = target + Vector((3 * math.sin(azimuth), -3 * math.cos(azimuth), 0))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.ortho_scale = scale
    scene.render.filepath = str(output / f"{name}.png")
    bpy.ops.render.render(write_still=True)

rig.animation_data.action = idle
scene.frame_set(1)
bpy.ops.wm.save_as_mainfile(filepath=str(output / "gabi-carnet.blend"))
rig.animation_data.nla_tracks.remove(rig.animation_data.nla_tracks["Controle_Epaules"])
bpy.data.actions.remove(bpy.data.actions["Controle_Epaules"])
bpy.ops.object.select_all(action="DESELECT")
for obj in [body, rig, *parts]:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=str(output / "gabi.glb"),
    export_format="GLB",
    export_image_format="JPEG",
    export_jpeg_quality=92,
    use_selection=True,
    export_skins=True,
    export_animation_mode="ACTIONS",
    export_frame_range=False,
    export_optimize_animation_size=True,
)
