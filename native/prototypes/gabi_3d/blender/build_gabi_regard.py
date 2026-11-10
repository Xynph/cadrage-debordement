"""Study true eyelid openings and geometric eyes on the v3 body rig."""

import argparse
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("output", type=Path)
args = parser.parse_args(sys.argv[sys.argv.index("--")+1:])
args.output.mkdir(parents=True, exist_ok=True)

scene = bpy.context.scene
body = bpy.data.objects["SK_Gabi"]
rig = bpy.data.objects["Gabi_Rig"]
skin = body.data.materials[0]
deps = bpy.context.evaluated_depsgraph_get()
samples = 32
TAU = math.tau

# Deliberate asymmetry: the reference's squint is slightly stronger on his left.
eyes = (
    {"side": "R", "center": (-.0450, -.0719, 1.6627), "aperture": (.0151, .0037, .0027), "globe": (.0178, .0116, .0118), "tilt": -.105},
    {"side": "L", "center": (.0373, -.0672, 1.6645), "aperture": (.0141, .0033, .0025), "globe": (.0171, .0110, .0115), "tilt": .077},
)


def smoothstep(low, high, value):
    t = np.clip((value - low) / (high - low), 0, 1)
    return t*t*(3-2*t)


def facial_forms():
    vertices = np.array([vert.co[:] for vert in body.data.vertices])
    x, y, z = vertices.T
    front = 1 - smoothstep(-.08, -.026, y)
    center = 1 - smoothstep(.018, .064, np.abs(x))
    nose = np.exp(-((z-1.638)/.024)**2)
    chin = np.exp(-((z-1.548)/.024)**2)
    jaw = (1 - smoothstep(.068, .096, np.abs(x))) * chin
    # Move the nose tip and beard silhouette a few millimeters toward the sketch.
    vertices[:,1] += front * (.0048*nose*center + .004*jaw)
    smile = np.exp(-((z-1.592)/.017)**2) * np.exp(-((np.abs(x)-.042)/.020)**2)
    vertices[:,2] += front * smile * np.where(x<0,.0058,.0034)
    for eye in eyes:
        cx, cy, cz = eye["center"]
        radius = np.sqrt(((x-cx)/.025)**2 + ((z-cz)/.016)**2)
        well = (1-smoothstep(.34, 1, radius))*front
        existing_bulge = np.minimum(0, y-(cy-.0065))
        vertices[:,1] -= .72*well*existing_bulge
    body.data.vertices.foreach_set("co", vertices.astype(np.float32).ravel())
    body.data.update()


facial_forms()

# Keep original topological landmarks for sampling the texture around the new rim.
source = body.data.copy()
polygons = [tuple(poly.vertices) for poly in source.polygons]
vertices = [vert.co.copy() for vert in source.vertices]
source_bvh = BVHTree.FromPolygons(vertices, polygons, all_triangles=True)
source_uv = source.uv_layers.active.data


def ray_sample(x, z):
    hit, _, poly_id, _ = source_bvh.ray_cast(Vector((x,-.4,z)), Vector((0,1,0)))
    if hit is None:
        raise RuntimeError(f"Eye UV misses the skin at {x:.4f}, {z:.4f}")
    poly = source.polygons[poly_id]
    points = [vertices[index] for index in poly.vertices]
    uvs = [source_uv[index].uv.to_3d() for index in poly.loop_indices]
    uv = barycentric_transform(hit, *points, *uvs)
    return hit.y, tuple(uv[:2])


def material(name, color, roughness):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color,1)
    shader = next(node for node in mat.node_tree.nodes if node.type=="BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color,1)
    shader.inputs["Roughness"].default_value = roughness
    return mat


def mesh_object(name, points, faces, materials, uv_coordinates=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(points, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    for mat in materials:
        mesh.materials.append(mat)
    if uv_coordinates:
        uv_layer = mesh.uv_layers.new(name="Surface")
        for loop in mesh.loops:
            uv_layer.data[loop.index].uv = uv_coordinates[loop.vertex_index]
    return obj


def finalize_topology(obj, smooth=True):
    edit = bmesh.new()
    edit.from_mesh(obj.data)
    bmesh.ops.triangulate(edit, faces=edit.faces[:])
    bmesh.ops.recalc_face_normals(edit, faces=edit.faces[:])
    for face in edit.faces:
        face.smooth = smooth
    edit.to_mesh(obj.data)
    edit.free()
    obj.data.update()


def follow_head(obj):
    obj.parent = rig
    group = obj.vertex_groups.new(name="Head")
    group.add(list(range(len(obj.data.vertices))), 1, "REPLACE")
    mod = obj.modifiers.new("Skin", "ARMATURE")
    mod.object = rig


def point(eye, t, scale=1):
    cx, _, cz = eye["center"]
    width, upper, lower = eye["aperture"]
    cosine, sine = math.cos(t), math.sin(t)
    height = upper if sine >= 0 else lower
    x = width*cosine
    z = height*math.copysign(abs(sine)**1.16,sine) + x*eye["tilt"]
    return cx+scale*x, cz+scale*z


def sphere_front(eye,x,z):
    cx,cy,cz=eye["center"]
    rx,ry,rz=eye["globe"]
    return cy-ry*math.sqrt(max(.002, 1-((x-cx)/rx)**2-((z-cz)/rz)**2))


def cut_socket(eye, cavity):
    # Cutter is larger than the visible aperture. A shaped lid later spans its rim.
    outline=[point(eye,TAU*i/samples,1.0) for i in range(samples)]
    cy=eye["center"][1]
    points=[(x,y,z) for y in (-.16,cy+.017) for x,z in outline]
    faces=[tuple(reversed(range(samples))),tuple(range(samples,2*samples))]
    for i in range(samples):
        j=(i+1)%samples
        faces.append((i,j,samples+j,samples+i))
    cutter=mesh_object("Cut_Eye_"+eye["side"],points,faces,[cavity])
    finalize_topology(cutter,False)
    bpy.context.view_layer.objects.active=body
    cut=body.modifiers.new(cutter.name,"BOOLEAN")
    cut.operation="DIFFERENCE"
    cut.solver="EXACT"
    cut.object=cutter
    cut.material_mode="TRANSFER"
    bpy.ops.object.modifier_move_up(modifier=cut.name)
    bpy.ops.object.modifier_apply(modifier=cut.name)
    bpy.data.objects.remove(cutter,do_unlink=True)


def make_globe(eye, materials):
    """Build an actual globe with material-defined iris and pupil rings."""
    cx,cy,cz=eye["center"]
    rx,ry,rz=eye["globe"]
    azimuth=.025 if eye["side"]=="L" else .010
    pitch=.144
    polar_steps=[.105,.157,.208,.305,.347,.395,.51,.66,.83,1.02,1.24,1.46,
                 1.69,1.90,2.10,2.31,2.52,2.71,2.87,3.01]
    ring_sizes=[math.sin(polar) for polar in polar_steps]
    points=[(cx+rx*azimuth,cy-ry,cz+rz*pitch)]
    uvs=[(.5,.5)]
    for polar,sine in zip(polar_steps,ring_sizes):
        radius=.47*polar/math.pi
        for i in range(samples):
            t=TAU*i/samples
            x=math.cos(t)*sine
            z=math.sin(t)*sine
            front=math.cos(polar)
            points.append((cx+rx*(x+azimuth*front),cy-ry*front,cz+rz*(z+pitch*front)))
            uvs.append((.5+radius*math.cos(t),.5+radius*math.sin(t)))
    points.append((cx-rx*azimuth,cy+ry,cz-rz*pitch))
    uvs.append((.5,.5))
    faces=[]
    material_slots=[]
    for i in range(samples):
        j=(i+1)%samples
        faces.append((0,1+i,1+j))
        material_slots.append(0)
    for r in range(len(polar_steps)-1):
        color=0 if r<1 else 1 if r<4 else 2 if r<5 else 3
        for i in range(samples):
            j=(i+1)%samples
            faces.append((1+r*samples+i,1+(r+1)*samples+i,1+(r+1)*samples+j,1+r*samples+j))
            if color==3:
                height=sum(points[index][2] for index in faces[-1])/4
                color_slot=4 if height<cz-.0007 else 3
                material_slots.append(color_slot)
            else:
                material_slots.append(color)
    for i in range(samples):
        j=(i+1)%samples
        faces.append((len(points)-1,1+(len(polar_steps)-1)*samples+j,1+(len(polar_steps)-1)*samples+i))
        material_slots.append(3)
    hidden_points=[]
    width, upper, lower=eye["aperture"]
    for x,y,z in points:
        dx=x-cx
        dz=z-cz-dx*eye["tilt"]
        height=upper if dz>=0 else lower
        radius=((dx/width)**2+abs(dz/height)**(2/1.16))**.5
        occluded=smoothstep(.79,1.18,radius)
        surface_y,_=ray_sample(x,z)
        displacement=occluded*max(0.0,surface_y+.0033-sphere_front(eye,x,z))
        if eye["side"]=="L":
            # Clear a tiny contact behind the outer upper lid.
            recess=math.exp(-((x-.049)/.004)**2-((z-1.671)/.0035)**2)
            displacement += .0026*recess*occluded
        hidden_points.append((x,y+displacement,z))
    globe=mesh_object("Globe_"+eye["side"],hidden_points,faces,materials,uvs)
    for polygon, slot in zip(globe.data.polygons,material_slots):
        polygon.material_index=slot
    finalize_topology(globe)
    uv_layer=globe.data.uv_layers.active.data
    south=len(points)-1
    for poly in globe.data.polygons:
        regular=[(index-1)%samples for index in poly.vertices if index not in (0,south)]
        seam=0 in regular and samples-1 in regular
        pole_u=sum((samples if seam and slot==0 else slot)/samples for slot in regular)/len(regular)
        for loop_id in poly.loop_indices:
            index=globe.data.loops[loop_id].vertex_index
            if index==0 or index==south:
                uv_layer[loop_id].uv=(pole_u,0 if index==0 else 1)
                continue
            ring, slot=divmod(index-1,samples)
            u=(samples if seam and slot==0 else slot)/samples
            uv_layer[loop_id].uv=(u,polar_steps[ring]/math.pi)
    follow_head(globe)
    return globe


cavity=material("M_Orbites",(.055,.019,.013),.84)
iris_materials=[
    material("M_Pupille",(.003,.0018,.0011),.52),
    material("M_Iris_Noisette",(.048,.023,.008),.64),
    material("M_Limbe",(.018,.009,.003),.66),
    material("M_Sclerotique",(.165,.127,.095),.80),
    material("M_Sclerotique_Ombre",(.095,.065,.045),.85),
]
for mat in iris_materials:
    shader=next(node for node in mat.node_tree.nodes if node.type=="BSDF_PRINCIPLED")
    shader.inputs["Specular IOR Level"].default_value=.12
for eye in eyes:
    cut_socket(eye,cavity)
    make_globe(eye,iris_materials)
def soften_socket_edges():
    edit=bmesh.new()
    edit.from_mesh(body.data)
    bmesh.ops.remove_doubles(edit, verts=edit.verts[:], dist=.000035)
    bmesh.ops.dissolve_degenerate(edit, edges=edit.edges[:], dist=.000030)
    boundary = {vert for edge in edit.edges if len(edge.link_faces)==2
                and edge.link_faces[0].material_index != edge.link_faces[1].material_index
                for vert in edge.verts}
    if boundary:
        bmesh.ops.smooth_vert(edit, verts=list(boundary), factor=.11,
                              use_axis_x=True, use_axis_y=True, use_axis_z=True)
    edit.to_mesh(body.data)
    edit.free()
soften_socket_edges()
finalize_topology(body)
# Boolean transfer keeps source UVs on the visible skin. Place the dark internal
# cavity polygons on a separate planar chart so no cut loop has zero UV area.
uv=body.data.uv_layers.active.data
for poly in body.data.polygons:
    if body.data.materials[poly.material_index] == cavity:
        for loop_id in poly.loop_indices:
            point3=body.data.vertices[body.data.loops[loop_id].vertex_index].co
            uv[loop_id].uv=(.20+1.7*point3.x+.24*point3.y, .17+1.4*(point3.z-1.65)+.44*point3.y)
# Guarantee that new Boolean vertices blend rigidly with the forehead.
head=body.vertex_groups["Head"]
for vert in body.data.vertices:
    if vert.co.z>1.628:
        for group in list(vert.groups):
            if group.group!=head.index:
                body.vertex_groups[group.group].remove([vert.index])
        head.add([vert.index],1,"REPLACE")

bpy.data.meshes.remove(source)
rig.animation_data.action=bpy.data.actions["Repos"]
scene.frame_set(1)
camera=scene.camera
for name,angle,height,scale in [
    ("visage",0,1.565,.57),("profil",90,1.565,.57),("visage_trois_quarts",-35,1.565,.57),
    ("bras_bas_trois_quarts",-40,1.25,1.19),("bras_bas",0,.9,1.94),
]:
    target=Vector((0,0,height))
    angle=math.radians(angle)
    camera.location=target+Vector((3*math.sin(angle),-3*math.cos(angle),0))
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.ortho_scale=scale
    scene.render.filepath=str(args.output/f"{name}.png")
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(args.output/"gabi-v5.blend"))
print("V5 facial mesh",len(body.data.vertices),"vertices",len(body.data.polygons),"triangles")

rig.animation_data.nla_tracks.remove(rig.animation_data.nla_tracks["Controle_Epaules"])
bpy.data.actions.remove(bpy.data.actions["Controle_Epaules"])
bpy.ops.object.select_all(action="DESELECT")
for obj in (body, rig, bpy.data.objects["Globe_L"], bpy.data.objects["Globe_R"]):
    obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(
    filepath=str(args.output/"gabi.glb"),
    export_format="GLB",
    export_image_format="JPEG",
    export_jpeg_quality=92,
    use_selection=True,
    export_skins=True,
    export_animation_mode="ACTIONS",
    export_frame_range=False,
    export_optimize_animation_size=True,
)
