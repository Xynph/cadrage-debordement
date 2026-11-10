"""Collision-aware eyelid sweep on a local V5 rig copy."""

import bpy
import math
import sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

output=Path(sys.argv[sys.argv.index("--")+1])
output.mkdir(parents=True,exist_ok=True)
scene=bpy.context.scene
body=bpy.data.objects["SK_Gabi"]
rig=bpy.data.objects["Gabi_Rig"]

eyes=(
    ("Globe_R", -.0450, -.0719, 1.6627, .0151, .0037, .0027, -.105),
    ("Globe_L", .0373, -.0672, 1.6645, .0141, .0033, .0025, .077),
)

cavity=body.data.materials.find("M_Orbites")
visible=set()
interior=set()
for polygon in body.data.polygons:
    target=interior if polygon.material_index==cavity else visible
    target.update(polygon.vertices)
rim=visible.intersection(interior)
eye_surfaces={}
for name,*_ in eyes:
    globe=bpy.data.objects[name].data
    eye_surfaces[name]=BVHTree.FromPolygons([v.co.copy() for v in globe.vertices],
                                          [tuple(p.vertices) for p in globe.polygons],
                                          all_triangles=True)


def smoothstep(a,b,t):
    u=min(1.0,max(0.0,(t-a)/(b-a)))
    return u*u*(3-2*u)


def eyeball_depth(name,x,z):
    point,_,_,_=eye_surfaces[name].ray_cast(Vector((x,-.24,z)),Vector((0,1,0)))
    return point.y if point is not None else None


def lid_pose(key,basis,fraction):
    count=0
    for vert in body.data.vertices:
        idx=vert.index
        x,y,z=basis.data[idx].co
        if y>-.045 or not 1.64<z<1.688:
            continue
        for name,cx,cy,cz,width,upper,lower,tilt in eyes:
            dx=x-cx
            if abs(dx)>width*1.35:
                continue
            outer=1-smoothstep(width*.85,width*1.35,abs(dx))
            front=1-smoothstep(cy-.007,cy+.007,y)
            if idx not in visible or front<.01 or outer<.01:
                continue
            arc=max(.05,math.sqrt(max(0,1-(dx/width)**2)))**1.16
            axis=cz+dx*tilt
            upper_lid=z>=axis
            start=axis+upper*arc if upper_lid else axis-lower*arc
            # Keep two distinct lips of the lid around the closing crease.
            crease=axis-.00105*arc
            end=crease+(.00032 if upper_lid else -.00031)
            band=.0062 if upper_lid else .0049
            closeness=math.exp(-((z-start)/band)**2)
            influence=front*outer*closeness
            temporal=0.0
            if name=="Globe_L" and not upper_lid:
                temporal=math.exp(-((x-.0466)/.0036)**2-((z-1.6633)/.0028)**2)
            corner_taper=1-.49*temporal*smoothstep(.66,1,fraction)
            delta_z=(end-start)*influence*fraction*corner_taper
            if abs(delta_z)<.000008:
                continue
            new_z=z+delta_z
            y_limit=eyeball_depth(name,x,new_z)
            next_y=y
            if y_limit is not None and (idx in visible or idx in rim):
                protection=smoothstep(.17,.69,closeness*outer)*smoothstep(.21,.61,front)
                # Lid clearance is measured from the real, recessed globe.
                # The leading upper lid stays forward of the lower lid during contact.
                lead=smoothstep(.45,1,fraction)
                clearance=(.00185+(.00142*lead if upper_lid else .00028*lead))
                protection*=1-.65*temporal*smoothstep(.66,1,fraction)
                next_y+=min(0.0,y_limit-clearance-y)*protection
                if name=="Globe_L" and upper_lid:
                    seam=math.exp(-((x-.0465)/.0037)**2-((z-1.668)/.0052)**2)
                    next_y-=(.00225+.0010*smoothstep(.54,1,fraction))*seam*front
            key.data[idx].co=(x,next_y,new_z)
            count+=1
    return count


basis=body.data.shape_keys.key_blocks["Basis"] if body.data.shape_keys else body.shape_key_add(name="Basis",from_mix=False)
mid=body.shape_key_add(name="Paupiere_Mi",from_mix=False)
closed=body.shape_key_add(name="Paupiere_Fermee",from_mix=False)
print("Lid vertices",lid_pose(mid,basis,.54),lid_pose(closed,basis,1))
globe_keys=[]
for eye_name in ("Globe_L","Globe_R"):
    globe=bpy.data.objects[eye_name]
    axis_recess=.0065 if eye_name=="Globe_L" else .0031
    for vert in globe.data.vertices:
        vert.co.y+=axis_recess
    globe_basis=globe.shape_key_add(name="Basis",from_mix=False)
    globe_mid=globe.shape_key_add(name="Paupiere_Mi",from_mix=False)
    globe_closed=globe.shape_key_add(name="Paupiere_Fermee",from_mix=False)
    globe_keys.append((globe_mid,globe_closed))
    # Retract the globe as a rigid body before the closing lid travels.
    mid_retraction=.0027 if eye_name=="Globe_L" else .0013
    full_retraction=.0032 if eye_name=="Globe_L" else .0029
    for vert in globe.data.vertices:
        x,y,z=globe_basis.data[vert.index].co
        temporal=math.exp(-((x-.047)/.0045)**2-((z-1.666)/.0050)**2) if eye_name=="Globe_L" else 0
        globe_mid.data[vert.index].co=(x,y+mid_retraction+.0024*temporal,z)
        globe_closed.data[vert.index].co=(x,y+full_retraction+.0014*temporal,z)

def blink(phase):
    if phase<=.54:
        mid.value=phase/.54
        closed.value=0
    else:
        blend=(phase-.54)/.46
        mid.value=1-blend
        closed.value=blend
    for globe_mid,globe_closed in globe_keys:
        globe_mid.value=mid.value
        globe_closed.value=closed.value

rig.animation_data.action=bpy.data.actions["Repos"]
scene.frame_set(1)
camera=scene.camera
for name,azimuth,phase in [
    ("01-ouvert",0,0),("02-mi-ferme",0,.54),("03-ferme",0,1),
    ("04-trois-quarts-ferme",-43,1),("05-profil-ferme",90,1),
]:
    blink(phase)
    bpy.context.view_layer.update()
    target=Vector((0,0,1.565))
    azimuth=math.radians(azimuth)
    camera.location=target+Vector((3*math.sin(azimuth),-3*math.cos(azimuth),0))
    camera.rotation_euler=(target-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.ortho_scale=.57
    scene.render.filepath=str(output/f"{name}.png")
    bpy.ops.render.render(write_still=True)

blink(0)
bpy.ops.wm.save_as_mainfile(filepath=str(output/"gabi-clignement-v2.blend"))

rig.animation_data.nla_tracks.remove(rig.animation_data.nla_tracks["Controle_Epaules"])
bpy.data.actions.remove(bpy.data.actions["Controle_Epaules"])
bpy.ops.object.select_all(action="DESELECT")
for obj in (body,rig,bpy.data.objects["Globe_L"],bpy.data.objects["Globe_R"]):
    obj.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(output/"gabi.glb"),export_format="GLB",
    export_image_format="JPEG",export_jpeg_quality=92,use_selection=True,
    export_skins=True,export_animation_mode="ACTIONS",export_frame_range=False,
    export_optimize_animation_size=True,export_morph=True,export_morph_normal=True)
