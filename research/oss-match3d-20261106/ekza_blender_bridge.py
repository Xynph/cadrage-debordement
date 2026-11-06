"""Real upstream Ekza quaternion outputs -> copied Blender 53-joint skinned armatures.
STRICT R&D: world mapping and anatomical skin checks fail closed. No production edits.
Usage: blender -b --python this.py -- rest.json solver.json output_dir
"""
import bpy,sys,json,math,hashlib,traceback
from pathlib import Path
from mathutils import Vector,Quaternion,Matrix

args=sys.argv[sys.argv.index("--")+1:]
REST=Path(args[0]); SOL=Path(args[1]); OUT=Path(args[2]); OUT.mkdir(parents=True,exist_ok=True)
root=Path.cwd()
data=json.loads(REST.read_text());sol=json.loads(SOL.read_text())
REPORT={"schema":"cd-blender-ekza-real-basis-v1","status":"FAILED","source":"REAL_UPSTREAM_EKZA_QUATERNIONS","lods":[],"errors":[],"visualApproved":False}
FRAMES=["front","profile","threequarter"]

def v(x):return Vector(x)
def xf(d):
    q=d["q"];return Matrix.LocRotScale(v(d["t"]),Quaternion((q[3],q[0],q[1],q[2])),v(d["s"]))
def world_chain(side):
    matrix=Matrix.Identity(4)
    for n in side["ancestors"]: matrix=matrix@xf(n)
    upper=matrix@xf(side["upper"])
    mid=upper@xf(side["mid"])
    end=mid@xf(side["end"])
    return {"thigh":upper,"calf":mid,"foot":end}
def solved_chain(side,out):
    matrix=Matrix.Identity(4)
    for n in side["ancestors"]:matrix=matrix@xf(n)
    nodes={}
    for name,tag in [("upper","thigh"),("mid","calf"),("end","foot")]:
        obj=dict(side[name])
        q=out["localQuaternions"][tag]
        obj["q"]=q
        matrix=matrix@xf(obj)
        nodes[tag]=matrix.copy()
    return nodes
def sha(p):
    return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def triad(a,b,c):
    x=(b-a).normalized()
    proj=c-a
    y=proj-x*proj.dot(x)
    assert y.length>1e-5,"collinear rest anchors"
    y.normalize()
    z=x.cross(y).normalized()
    return Matrix(((x.x,y.x,z.x),(x.y,y.y,z.y),(x.z,y.z,z.z)))
def world_conversion(gl,bl):
    ga,gb,gc=[gl[x] for x in ("hip_l","hip_r","foot_l")]
    ba,bb,bc=[bl[x] for x in ("hip_l","hip_r","foot_l")]
    rot=triad(ba,bb,bc)@triad(ga,gb,gc).transposed()
    C=Matrix.Translation(ba)@rot.to_4x4()@Matrix.Translation(-ga)
    return C
def skin_stats(objects,side):
    pts=[]
    for obj in objects:
        ids={g.index for g in obj.vertex_groups if g.name in ("foot_"+side,"ball_"+side)}
        if not ids:continue
        ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
        try:
            assert len(mesh.vertices)==len(obj.data.vertices),"topology changed; cannot map foot weights"
            for i,vertex in enumerate(obj.data.vertices):
                if any(g.group in ids and g.weight>=.5 for g in vertex.groups):
                    pts.append(ev.matrix_world@mesh.vertices[i].co)
        finally:ev.to_mesh_clear()
    assert len(pts)>10,f"not enough true skinned foot vertices {side}"
    center=sum(pts,Vector((0,0,0)))/len(pts)
    return {"vertices":len(pts),"minZ":min(p.z for p in pts),"centroid":[float(t) for t in center]}
def render(scene,meshes,lod,label):
    for ob in bpy.data.objects:
        if ob.type=="MESH":ob.hide_render=ob not in meshes
    for name,dir in [("front",Vector((0,-1,0))),("profile",Vector((1,0,0))),
                     ("threequarter",Vector((1,-1,0)).normalized())]:
        scene.camera.location=Vector((0,0,1.0))+dir*5
        target=Vector((0,0,1.0))
        scene.camera.rotation_euler=(target-scene.camera.location).to_track_quat("-Z","Y").to_euler()
        p=OUT/f"lod{lod}-{label}-{name}.png"
        scene.render.filepath=str(p);bpy.ops.render.render(write_still=True)
        assert p.exists() and p.stat().st_size>1500
def load(lod):
    p=root/"baseline/dist/match3d/assets/rugby-v24/lod"/f"base_body_anim-lod{lod}.glb"
    assert p.exists() and sha(p)==next(x["originalGlbSha256"] for x in data["lods"] if x["lod"]==lod)
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(p))
    added=[x for x in bpy.data.objects if x not in before]
    rigs=[x for x in added if x.type=="ARMATURE"]
    assert len(rigs)==1 and len(rigs[0].data.bones)==53
    rig=rigs[0]
    for obj in added:
        if obj.animation_data:obj.animation_data_clear()
    for bone in rig.pose.bones:bone.matrix_basis.identity()
    bpy.context.view_layer.update()
    meshes=[]
    for o in added:
        if o.type!="MESH":continue
        technical=(o.name.startswith("Icosphere") and len(o.data.vertices)==42 and
            len(o.data.polygons)==80 and len(o.vertex_groups)==0 and len(o.data.materials)==0 and
            not any(m.type=="ARMATURE" for m in o.modifiers))
        if technical:continue
        assert any(m.type=="ARMATURE" for m in o.modifiers),"unskinned anatomical mesh"
        meshes.append(o)
    assert meshes
    return rig,meshes
try:
    assert len(data["lods"])==3 and len(sol["results"])==6
    assert sol["sourceExecutedDirectly"] and sol["upstreamPinnedSha"]=="b7e3e92f25d2656caace50c0869aeef0d562dbf3"
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.device="CPU";scene.cycles.samples=2
    scene.render.resolution_x=480;scene.render.resolution_y=360;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    world=bpy.data.worlds.new("OSS-white");world.use_nodes=True
    world.node_tree.nodes["Background"].inputs["Color"].default_value=(.80,.86,.94,1)
    scene.world=world
    lamp=bpy.data.objects.new("area",bpy.data.lights.new("area","AREA"));scene.collection.objects.link(lamp)
    lamp.location=(0,-3,5);lamp.data.energy=650;lamp.data.size=5
    cam=bpy.data.objects.new("cam",bpy.data.cameras.new("cam"));scene.collection.objects.link(cam)
    cam.data.type="ORTHO";cam.data.ortho_scale=3.5;scene.camera=cam
    for lod in range(3):
        source=next(x for x in data["lods"] if x["lod"]==lod)
        rig,meshes=load(lod)
        rest={side:world_chain(source["sides"][side]) for side in ("l","r")}
        gl={"hip_l":rest["l"]["thigh"].translation,"hip_r":rest["r"]["thigh"].translation,
            "foot_l":rest["l"]["foot"].translation}
        bl={}
        for side in ("l","r"):
            for kind,key in [("thigh","hip"),("calf","knee"),("foot","foot")]:
                pb=rig.pose.bones[kind+"_"+side]
                bl[key+"_"+side]=(rig.matrix_world@pb.matrix).translation.copy()
        C=world_conversion(gl,bl)
        fit=max(((C@rest[side][kind]).translation-bl[key+"_"+side]).length
                for side in ("l","r") for kind,key in [("thigh","hip"),("calf","knee"),("foot","foot")])
        assert fit<.02,f"LOD{lod} glTF→Blender rest frame mismatch: {fit*100:.2f}cm"
        before={side:skin_stats(meshes,side) for side in ("l","r")}
        render(scene,meshes,lod,"baseline")
        details={}
        for side in ("l","r"):
            result=next(x for x in sol["results"] if x["lod"]==lod and x["side"]==side)
            assert result["glbSha256"]==source["originalGlbSha256"] and result["reached"]
            goal=solved_chain(source["sides"][side],result)
            for kind in ("thigh","calf","foot"):
                pb=rig.pose.bones[kind+"_"+side]
                original=rest[side][kind]
                delta=goal[kind]@original.inverted()
                old_world=rig.matrix_world@pb.bone.matrix_local
                desired=C@delta@C.inverted()@old_world
                pb.matrix=rig.matrix_world.inverted()@desired
                bpy.context.view_layer.update()
            actual=(rig.matrix_world@rig.pose.bones["foot_"+side].matrix).translation
            target=C@v(result["target"])
            error=(actual-target).length
            details[side]={"footTargetErrorCm":round(error*100,4),
                "restToBlenderFitCm":round(fit*100,4),
                "targetXYZ":list(target),"actualXYZ":list(actual)}
            assert error<.02,f"LOD{lod} side {side} world foot target mismatch: {error*100:.3f}cm"
        after={side:skin_stats(meshes,side) for side in ("l","r")}
        for side in ("l","r"):
            a=v(before[side]["centroid"]);b=v(after[side]["centroid"])
            details[side]["trueSkinnedFootCentroidShiftCm"]=round((b-a).length*100,5)
            details[side]["trueSkinnedFootVertices"]=after[side]["vertices"]
            assert (b-a).length>.001,"no true skinned deformation from applied Ekza rotations"
        render(scene,meshes,lod,"ekza-native")
        REPORT["lods"].append({"lod":lod,"sourceGlbSha256":source["originalGlbSha256"],
            "restFrameFitCm":round(fit*100,4),"details":details,
            "baselineSkinnedFoot":before,"candidateSkinnedFoot":after})
        for mesh in meshes:bpy.data.objects.remove(mesh,do_unlink=True)
        bpy.data.objects.remove(rig,do_unlink=True)
    REPORT["status"]="REAL_EKZA_TO_BLENDER_STATIC_POSE_NOT_ANIMATION_QUALIFIED"
except Exception as exc:
    REPORT["errors"].append(str(exc));REPORT["traceback"]=traceback.format_exc()
finally:
    REPORT["renderCount"]=len(list(OUT.glob("*.png")))
    (OUT/"bridge-report.json").write_text(json.dumps(REPORT,indent=2)+"\n")
print(json.dumps({"status":REPORT["status"],"lods":len(REPORT["lods"]),
                  "images":REPORT["renderCount"],"errors":REPORT["errors"]}),flush=True)
if REPORT["status"]=="FAILED":sys.exit(1)
