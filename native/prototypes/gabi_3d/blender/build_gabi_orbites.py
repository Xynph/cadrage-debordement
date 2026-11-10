"""Enlarge each internal eye pocket to the swept globe, without cutting the face."""

import bpy,bmesh
import math,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

out=Path(sys.argv[sys.argv.index("--")+1])
out.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
body=bpy.data.objects["SK_Gabi"]
cavity=body.data.materials["M_Orbites"]
rig=bpy.data.objects["Gabi_Rig"]
axis_recess={"Globe_L":.0065,"Globe_R":.0031}
rig.animation_data.action=bpy.data.actions["Repos"]
scene.frame_set(1)


def bvh_for_surface():
    return BVHTree.FromPolygons([v.co.copy() for v in body.data.vertices],
                                [tuple(p.vertices) for p in body.data.polygons if p.material_index==0],
                                all_triangles=True)


original=bvh_for_surface()
probes=[]
for x_start in (-.065,.017):
    for j in range(30):
        z=1.648+j*.0008
        for i in range(47):
            x=x_start+i*.0009
            origin=Vector((x,-.4,z))
            hit,_,_,_=original.ray_cast(origin,Vector((0,1,0)))
            if hit and hit.y<-.045:
                probes.append((origin,hit.y))


def cavity_cutter(eye_name):
    globe=bpy.data.objects[eye_name].data
    axis_x,axis_z=(.0373,1.6645) if eye_name=="Globe_L" else (-.0450,1.6627)
    offset=axis_recess[eye_name]
    mid=.0027 if eye_name=="Globe_L" else .0013
    closed=.0032 if eye_name=="Globe_L" else .0029
    points=[]
    for vert in globe.vertices:
        x,y,z=vert.co
        temporal=math.exp(-((x-.047)/.0045)**2-((z-1.666)/.0050)**2) if eye_name=="Globe_L" else 0
        # The globe's x/z lattice remains constant during the blink. Its
        # projected triangles bound all intermediate depths pointwise.
        front=vert.index==0 or (vert.index-1)//32 < 12
        retreat=-.00052 if front else max(mid+.0024*temporal,closed+.0014*temporal)+.0007
        x=axis_x+(x-axis_x)*1.026
        z=axis_z+(z-axis_z)*1.026
        points.append((x,y+offset+retreat,z))
    mesh=bpy.data.meshes.new(f"Volume_{eye_name}")
    mesh.from_pydata(points,[],[tuple(p.vertices) for p in globe.polygons])
    mesh.update()
    obj=bpy.data.objects.new(mesh.name,mesh)
    scene.collection.objects.link(obj)
    obj.data.materials.append(cavity)
    return obj


def rear_pocket():
    eye=bpy.data.objects["Globe_L"].data
    edit=bmesh.new()
    center_x,center_z=.0373,1.6645
    points=[]
    for vert in eye.vertices:
        x,y,z=vert.co
        temporal=math.exp(-((x-.047)/.0045)**2-((z-1.666)/.0050)**2)
        for retreat in (.0027+.0024*temporal,.0032+.0014*temporal):
            depth=y+axis_recess["Globe_L"]+retreat
            if depth>-.056:
                points.append(edit.verts.new((center_x+(x-center_x)*1.065,depth+.0012,
                                              center_z+(z-center_z)*1.065)))
    bmesh.ops.convex_hull(edit,input=points,use_existing_faces=False)
    bmesh.ops.delete(edit,geom=[v for v in edit.verts if not v.link_edges],context="VERTS")
    bmesh.ops.recalc_face_normals(edit,faces=edit.faces[:])
    mesh=bpy.data.meshes.new("Volume_Arriere_Globe_L")
    edit.to_mesh(mesh)
    edit.free()
    cutter=bpy.data.objects.new(mesh.name,mesh)
    scene.collection.objects.link(cutter)
    cutter.data.materials.append(cavity)
    return cutter


def subtract(cutter):
    bpy.context.view_layer.objects.active=body
    boolean=body.modifiers.new("Profondeur de l’orbite","BOOLEAN")
    boolean.operation="DIFFERENCE"
    boolean.solver="EXACT"
    boolean.material_mode="TRANSFER"
    boolean.object=cutter
    bpy.ops.object.modifier_move_up(modifier=boolean.name)
    bpy.ops.object.modifier_apply(modifier=boolean.name)
    bpy.data.objects.remove(cutter,do_unlink=True)


for name in axis_recess:
    subtract(cavity_cutter(name))
subtract(rear_pocket())

edit=bmesh.new()
edit.from_mesh(body.data)
bmesh.ops.remove_doubles(edit,verts=edit.verts[:],dist=.000037)
bmesh.ops.dissolve_degenerate(edit,edges=edit.edges[:],dist=.000027)
bmesh.ops.triangulate(edit,faces=edit.faces[:])
bmesh.ops.recalc_face_normals(edit,faces=edit.faces[:])
edit.to_mesh(body.data)
edit.free()
interior=body.data.materials.find(cavity.name)
uv=body.data.uv_layers.active.data
for poly in body.data.polygons:
    if poly.material_index==interior:
        for loop_id in poly.loop_indices:
            v=body.data.vertices[body.data.loops[loop_id].vertex_index].co
            uv[loop_id].uv=(.20+1.7*v.x+.26*v.y,.17+1.4*(v.z-1.65)+.44*v.y)
head=body.vertex_groups["Head"]
for vert in body.data.vertices:
    if vert.co.z>1.625:
        for group in list(vert.groups):
            if group.group!=head.index:
                body.vertex_groups[group.group].remove([vert.index])
        head.add([vert.index],1,"REPLACE")

updated=bvh_for_surface()
changes=[]
for origin,depth in probes:
    hit,_,_,_=updated.ray_cast(origin,Vector((0,1,0)))
    delta=hit.y-depth if hit else .2
    if abs(delta)>.0002:
        changes.append((tuple(origin),depth,delta))
print("Visible-depth probes",len(probes),"changed",len(changes),"largest",max([abs(v[2]) for v in changes],default=0))
if changes:
    raise RuntimeError(f"The eye pockets reach the visible face at {len(changes)} probes")
bpy.ops.wm.save_as_mainfile(filepath=str(out/"gabi-orbites.blend"))
