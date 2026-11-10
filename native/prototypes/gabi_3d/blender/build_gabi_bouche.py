"""Local proof of feasibility for a real mouth cavity versus a continuous morph."""

import argparse
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("out",type=Path)
parser.add_argument("--mode",choices=("morph","retopo"),required=True)
args=parser.parse_args(sys.argv[sys.argv.index("--")+1:])
args.out.mkdir(parents=True,exist_ok=True)

scene=bpy.context.scene
body=bpy.data.objects["SK_Gabi"]
rig=bpy.data.objects["Gabi_Rig"]
eyes=(bpy.data.objects["Globe_L"],bpy.data.objects["Globe_R"])
skin=body.data.materials[0]
patch_width=.061
top_height=.018
bottom_height=.025
samples=40


def lip_axis(x):
    u=x/.054
    return 1.5962-.0061*u*u+.0017*u


def rim(angle,width_scale=1,height_scale=1):
    x=patch_width*math.cos(angle)*width_scale
    sine=math.sin(angle)
    height=top_height if sine>=0 else bottom_height
    return x,lip_axis(x)+height*sine*height_scale


def smoothstep(a,b,t):
    u=min(1,max(0,(t-a)/(b-a)))
    return u*u*(3-2*u)


def material(name,color,roughness):
    mat=bpy.data.materials.new(name)
    mat.diffuse_color=(*color,1)
    shader=next(node for node in mat.node_tree.nodes if node.type=="BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value=(*color,1)
    shader.inputs["Roughness"].default_value=roughness
    return mat


def uv_and_depth(bvh,source,x,z):
    point,_,face_id,_=bvh.ray_cast(Vector((x,-.35,z)),Vector((0,1,0)))
    if point is None:
        raise RuntimeError(f"missing skin under lip patch {x},{z}")
    poly=source.polygons[face_id]
    coordinates=[source.vertices[index].co for index in poly.vertices]
    uvs=[source.uv_layers.active.data[loop_id].uv.to_3d() for loop_id in poly.loop_indices]
    texel=barycentric_transform(point,*coordinates,*uvs)
    return point.y,texel.x,texel.y


PATCH_U0=-.072
PATCH_U1=.072
PATCH_V0=1.558
PATCH_V1=1.626


def patch_uv(x,z):
    return ((x-PATCH_U0)/(PATCH_U1-PATCH_U0),(z-PATCH_V0)/(PATCH_V1-PATCH_V0))


def projected_patch_material(source,bvh):
    src_shader=next(node for node in skin.node_tree.nodes if node.type=="BSDF_PRINCIPLED")
    image=src_shader.inputs["Base Color"].links[0].from_node.image
    width,height=image.size
    pixels=np.empty(width*height*4,dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels=pixels.reshape((height,width,4))
    patch_w,patch_h=512,256
    lookup=np.empty((patch_h,patch_w,2),dtype=np.float32)
    for row in range(patch_h):
        z=PATCH_V0+(row+.5)*(PATCH_V1-PATCH_V0)/patch_h
        for column in range(patch_w):
            x=PATCH_U0+(column+.5)*(PATCH_U1-PATCH_U0)/patch_w
            _,u,v=uv_and_depth(bvh,source,x,z)
            lookup[row,column]=(u*width-.5,v*height-.5)
    floor=np.floor(lookup).astype(np.int32)
    delta=lookup-floor
    x0=np.clip(floor[:,:,0],0,width-1)
    y0=np.clip(floor[:,:,1],0,height-1)
    x1=np.clip(x0+1,0,width-1)
    y1=np.clip(y0+1,0,height-1)
    u=delta[:,:,0,None]
    v=delta[:,:,1,None]
    albedo=(1-v)*((1-u)*pixels[y0,x0]+u*pixels[y0,x1])+v*((1-u)*pixels[y1,x0]+u*pixels[y1,x1])
    texture=bpy.data.images.new("Gabi_LipPatch",width=patch_w,height=patch_h,alpha=False)
    texture.colorspace_settings.name="sRGB"
    texture.pixels.foreach_set(albedo.astype(np.float32).ravel())
    texture.filepath_raw=str(args.out/"bouche-albedo.png")
    texture.file_format="PNG"
    texture.save()
    texture.pack()
    patch=material("M_Gabi_LipPatch",(.31,.12,.08),.79)
    graph=patch.node_tree
    shader=next(node for node in graph.nodes if node.type=="BSDF_PRINCIPLED")
    node=graph.nodes.new("ShaderNodeTexImage")
    node.image=texture
    graph.links.new(node.outputs["Color"],shader.inputs["Base Color"])
    return patch


def make_cutter(cavity):
    outline=[rim(math.tau*i/samples) for i in range(samples)]
    points=[(x,y,z) for y in (-.21,-.034) for x,z in outline]
    faces=[tuple(reversed(range(samples))),tuple(range(samples,2*samples))]
    for i in range(samples):
        j=(i+1)%samples
        faces.append((i,j,samples+j,samples+i))
    mesh=bpy.data.meshes.new("Cavite_Cutter")
    mesh.from_pydata(points,[],faces)
    mesh.update()
    cutter=bpy.data.objects.new("Cavite_Cutter",mesh)
    scene.collection.objects.link(cutter)
    cutter.data.materials.append(cavity)
    edit=bmesh.new()
    edit.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(edit,faces=edit.faces[:])
    edit.to_mesh(mesh)
    edit.free()
    return cutter


def exact_contour(cavity):
    cutter=make_cutter(cavity)
    bpy.context.view_layer.objects.active=body
    mod=body.modifiers.new("Ouverture anatomique","BOOLEAN")
    mod.operation="DIFFERENCE"
    mod.solver="EXACT"
    mod.material_mode="TRANSFER"
    mod.object=cutter
    bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
    edit=bmesh.new()
    edit.from_mesh(body.data)
    bmesh.ops.remove_doubles(edit,verts=edit.verts[:],dist=.000035)
    bmesh.ops.dissolve_degenerate(edit,edges=edit.edges[:],dist=.000028)
    interior_id=body.data.materials.find(cavity.name)
    interior=[face for face in edit.faces if face.material_index==interior_id]
    if not interior:
        raise RuntimeError("Boolean did not cut the mouth cavity")
    bmesh.ops.delete(edit,geom=interior,context="FACES")
    adjacency=defaultdict(list)
    for edge in edit.edges:
        if edge.is_boundary:
            a,b=edge.verts
            adjacency[a].append(b)
            adjacency[b].append(a)
    assert all(len(neighbors)==2 for neighbors in adjacency.values()), "Contour forks"
    first=max(adjacency,key=lambda vert:vert.co.x)
    loop=[first]
    current,previous=adjacency[first][0],first
    while current!=first:
        loop.append(current)
        a,b=adjacency[current]
        current,previous=(a if b==previous else b),current
        if len(loop)>len(adjacency):
            raise RuntimeError("Invalid contour traversal")
    assert len(loop)==len(adjacency),f"Multiple contour loops: {len(loop)} of {len(adjacency)} vertices"
    return edit,loop,interior_id


def retopo_mouth():
    source=body.data.copy()
    bvh=BVHTree.FromPolygons([v.co.copy() for v in source.vertices],
                             [tuple(poly.vertices) for poly in source.polygons],all_triangles=True)
    cavity=material("M_Cavite_Bouche",(.044,.011,.008),.92)
    patch=projected_patch_material(source,bvh)
    body.data.materials.append(patch)
    edit,outer,interior_id=exact_contour(cavity)
    lip_id=body.data.materials.find(patch.name)
    uv_layer=edit.loops.layers.uv.verify()
    deform=edit.verts.layers.deform.verify()
    head=body.vertex_groups["Head"].index
    angles=[math.atan2((vert.co.z-lip_axis(vert.co.x))/(top_height if vert.co.z>=lip_axis(vert.co.x) else bottom_height),
                        vert.co.x/patch_width) for vert in outer]
    def carry_weights(vertex, x, z):
        hit, _, face_id, _ = bvh.ray_cast(Vector((x,-.35,z)), Vector((0,1,0)))
        polygon = source.polygons[face_id]
        verts = [source.vertices[index] for index in polygon.vertices]
        blend = barycentric_transform(hit, *(item.co for item in verts),
                                      Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)))
        totals=defaultdict(float)
        for item, factor in zip(verts, blend):
            for group in item.groups:
                totals[group.group]+=max(0.0,factor)*group.weight
        weights=sorted(totals.items(),key=lambda entry:entry[1],reverse=True)[:4]
        norm=sum(weight for _,weight in weights)
        if norm<.00001:
            vertex[deform][head]=1.0
        else:
            for group,weight in weights:
                if weight>.00001:
                    vertex[deform][group]=weight/norm

    for vertex in outer:
        carry_weights(vertex,vertex.co.x,vertex.co.z)
    surface=[outer]
    for width_scale,height_scale in ((.94,.82),(.87,.62),(.79,.40),(.75,.22),(.72,.026)):
        ring=[]
        for angle in angles:
            x,z=rim(angle,width_scale,height_scale)
            y,_,_=uv_and_depth(bvh,source,x,z)
            vert=edit.verts.new((x,y,z))
            carry_weights(vert,x,z)
            ring.append(vert)
        surface.append(ring)

    def bridge(row_a,row_b,mat_index,uv_fn):
        for i in range(len(row_a)):
            j=(i+1)%len(row_a)
            face=edit.faces.new((row_a[i],row_a[j],row_b[j],row_b[i]))
            face.material_index=mat_index
            face.smooth=True
            for corner in face.loops:
                corner[uv_layer].uv=uv_fn(corner.vert)

    for row_a,row_b in zip(surface,surface[1:]):
        bridge(row_a,row_b,lip_id,lambda vert:patch_uv(vert.co.x,vert.co.z))

    interior=[surface[-1]]
    for inset,shrink,arc_height in ((.004,.99,.0015),(.016,.93,.0045),(.031,.84,.0054)):
        ring=[]
        for vert,angle in zip(surface[-1],angles):
            x=vert.co.x*shrink
            z=lip_axis(x)+math.sin(angle)*arc_height
            new=edit.verts.new((x,vert.co.y+inset,z))
            new[deform][head]=1.0
            ring.append(new)
        interior.append(ring)

    def inside_uv(vert):
        # A separate chart for the dark cavity, kept inside the UV square.
        return (.52+4.2*vert.co.x+1.6*(vert.co.y+.09),.49+7.2*(vert.co.z-1.59)+2.8*(vert.co.y+.09))

    for row_a,row_b in zip(interior,interior[1:]):
        bridge(row_a,row_b,interior_id,inside_uv)
    back=edit.verts.new((0,-.038,1.594))
    back[deform][head]=1.0
    for i in range(len(outer)):
        face=edit.faces.new((interior[-1][i],interior[-1][(i+1)%len(outer)],back))
        face.material_index=interior_id
        face.smooth=True
        for corner in face.loops:
            corner[uv_layer].uv=inside_uv(corner.vert)
    bmesh.ops.triangulate(edit,faces=edit.faces[:])
    bmesh.ops.recalc_face_normals(edit,faces=edit.faces[:])
    edit.to_mesh(body.data)
    edit.free()
    bpy.data.meshes.remove(source)
    print("Mouth contour",len(outer),"vertices and 6 external / 3 internal rings")


if args.mode=="retopo":
    retopo_mouth()

basis=body.shape_key_add(name="Basis",from_mix=False)
jaw=body.shape_key_add(name="Machoire",from_mix=False)
for vert in body.data.vertices:
    x,y,z=basis.data[vert.index].co
    if abs(x)>.091 or y>-.024 or z<1.510 or z>1.61:
        continue
    axis=lip_axis(x)
    corner=1-smoothstep(.030,.062,abs(x))
    cheek=1-smoothstep(.048,.085,abs(x))
    lip=1-smoothstep(axis-.00052,axis+.00018,z)
    jaw_area=smoothstep(1.514,1.550,z)
    # Pull the lower lip and leave the moustache/upper lip anchored.
    lateral=corner if z>1.575 else cheek
    front=1-smoothstep(-.063,-.027,y)
    weight=lip*jaw_area*lateral*front
    angle=.083*weight
    hinge_y,hinge_z=.003,1.609
    local_y,local_z=y-hinge_y,z-hinge_z
    # Ease the generated lip shelf inward during the hinge motion. The neutral stays exact.
    lip_retract=.0037*weight*math.exp(-((z-axis)/.0057)**2)
    jaw.data[vert.index].co=(x,hinge_y+local_y*math.cos(angle)-local_z*math.sin(angle)+lip_retract,
                            hinge_z+local_y*math.sin(angle)+local_z*math.cos(angle))

rig.animation_data.action=bpy.data.actions["Repos"]
scene.frame_set(1)
camera=scene.camera
for view,azimuth in (("face",0),("trois-quarts",-38),("profil",90)):
    target=Vector((0,0,1.565))
    azimuth=math.radians(azimuth)
    camera.location=target+Vector((3*math.sin(azimuth),-3*math.cos(azimuth),0))
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.ortho_scale=.57
    for pose,value in (("fermee",0),("mi-ouverte",.52),("ouverte",1)):
        jaw.value=value
        bpy.context.view_layer.update()
        scene.render.filepath=str(args.out/f"{view}-{pose}.png")
        bpy.ops.render.render(write_still=True)

jaw.value=0
bpy.ops.wm.save_as_mainfile(filepath=str(args.out/f"gabi-bouche-{args.mode}.blend"))
print(json.dumps({"mode":args.mode,"vertices":len(body.data.vertices),"triangles":len(body.data.polygons)}))
