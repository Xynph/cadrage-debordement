"""Original authored rugby tackle feasibility study on copied canonical GLBs.
No CMU/third-party motion, no physics joints, no game assets rewritten.
A geometric probe is not artistic approval.
"""
import bpy, json, math, hashlib, traceback
from pathlib import Path
from mathutils import Vector, Quaternion, Euler
from mathutils.bvhtree import BVHTree

ROOT=Path.cwd(); OUT=ROOT/"rd-report"/"original-tackle"; OUT.mkdir(parents=True,exist_ok=True)
REPORT={"schema":1,"origin":"ORIGINAL_PROCEDURAL_KEYFRAMES_NO_EXTERNAL_MOCAP",
 "status":"FAILED","visualApproval":False,"physicsComparisonExecuted":False,
 "rootOffsetsAuthoredNotCMU":True,"lods":[],"errors":[]}
PHASES=[1,22,40,60,90]
REGIONS={"chest":{"spine_02","spine_03"},"pelvis":{"pelvis","spine_01"},
"knee_l":{"thigh_l","calf_l"},"knee_r":{"thigh_r","calf_r"},
"foot_l":{"foot_l","ball_l"},"foot_r":{"foot_r","ball_r"}}
# The two original trajectories share a time origin. Differences in XY remain
# deliberate source authored movement, not per-frame snapping to opponent skin.
ROOTS={
 "A":[(-1.50,0,0),(-0.97,0,0),(-0.56,0,0),(-0.24,0,0),(-0.37,0,0)],
 "B":[(0.80,0,0),(0.80,0,0),(0.92,0,0),(1.02,0,0),(1.06,0,0)]
}
# These rotations are explicitly *hypotheses* awaiting contact validation.
POSE={
"A":{"upperarm_l":[0,-.15,-.45,-.65,-.1],"upperarm_r":[0,-.15,.45,.65,.1],
"lowerarm_l":[0,.25,.65,.85,.1],"lowerarm_r":[0,-.25,-.65,-.85,-.1],
"spine_01":[0,.05,.12,.26,.07],"spine_02":[0,.04,.12,.20,.03],
"thigh_l":[0,.12,.12,.52,.25],"thigh_r":[0,-.09,-.13,.23,-.05]},
"B":{"upperarm_l":[0,.04,.15,.34,.05],"upperarm_r":[0,-.04,-.15,-.34,-.05],
"spine_01":[0,0,-.07,-.42,-.16],"spine_02":[0,0,-.09,-.38,-.10],
"thigh_l":[0,0,.05,.49,.12],"thigh_r":[0,0,-.05,.35,.16]}}
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def evaluated_geometry(meshes):
    deps=bpy.context.evaluated_depsgraph_get(); verts=[]; faces=[]
    for obj in meshes:
        ev=obj.evaluated_get(deps); mesh=ev.to_mesh()
        try:
            mesh.calc_loop_triangles(); offset=len(verts)
            verts.extend([ev.matrix_world@v.co for v in mesh.vertices])
            faces.extend([tuple(offset+i for i in tri.vertices) for tri in t.vertices] if False else
                         tuple(offset+i for i in t.vertices) for t in mesh.loop_triangles)
        finally:ev.to_mesh_clear()
    return verts,faces
def cross_triangles(v1,v2,v3,w1,w2,w3,eps=1e-7):
    # Exact segment-triangle test after BVH broad-phase; coplanar contacts
    # deliberately reported as "unresolved", not mislabelled as penetration.
    def seg_hit(p,q,a,b,c):
        d=q-p; ab=b-a; ac=c-a; h=d.cross(ac); det=ab.dot(h)
        if abs(det)<eps:return False
        inv=1.0/det; s=p-a; u=inv*s.dot(h)
        if u<eps or u>1-eps:return False
        j=s.cross(ab); v=inv*d.dot(j)
        if v<eps or u+v>1-eps:return False
        t=inv*ac.dot(j)
        return eps<t<1-eps
    for a,b in [(v1,v2),(v2,v3),(v3,v1)]:
        if seg_hit(a,b,w1,w2,w3):return True
    for a,b in [(w1,w2),(w2,w3),(w3,w1)]:
        if seg_hit(a,b,v1,v2,v3):return True
    return False
def mesh_regions(meshes):
    result={k:{"minZ":None,"vertices":0} for k in REGIONS}
    deps=bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        ev=obj.evaluated_get(deps); mesh=ev.to_mesh()
        try:
            for idx,vertex in enumerate(mesh.vertices):
                group=max(obj.data.vertices[idx].groups,key=lambda x:x.weight,default=None)
                if group is None or group.weight<.2:continue
                name=obj.vertex_groups[group.group].name
                for region,bones in REGIONS.items():
                    if name in bones:
                        z=(ev.matrix_world@vertex.co).z
                        cur=result[region]["minZ"]
                        result[region]["minZ"]=round(min(z,cur) if cur is not None else z,5)
                        result[region]["vertices"]+=1
        finally:ev.to_mesh_clear()
    return result
def audit(a,b):
    va,fa=evaluated_geometry(a["meshes"]);vb,fb=evaluated_geometry(b["meshes"])
    bva=BVHTree.FromPolygons(va,fa,all_triangles=True)
    bvb=BVHTree.FromPolygons(vb,fb,all_triangles=True)
    pairs=bva.overlap(bvb);proper=0
    for i,j in pairs:
        if cross_triangles(*[va[k] for k in fa[i]],*[vb[k] for k in fb[j]]):proper+=1
    hands={}
    for source,target,tree in [("A",a,bvb),("B",b,bva)]:
        hands[source]={}
        for side in ("l","r"):
            bone=target["rig"].pose.bones.get("hand_"+side)
            if bone is None:raise RuntimeError("Canonical wrist missing")
            p=(target["rig"].matrix_world@bone.matrix).translation
            near=tree.find_nearest(p)
            hands[source][side]={"metersToOpposingTrueSkin":round(near[3],5),
                "worldPosition":[round(x,5) for x in p]}
    return {"hands":hands,"potentialBVHPairs":len(pairs),
       "properNonCoplanarTriangleCrossings":proper,
       "coplanarOrTangentUnresolved":True,
       "trueSkinnedTriangleCount":{"A":len(fa),"B":len(fb)},
       "supports":{"A":mesh_regions(a["meshes"]),"B":mesh_regions(b["meshes"])}}
try:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.device="CPU"
    scene.cycles.samples=3;scene.render.resolution_x=480;scene.render.resolution_y=360
    scene.render.image_settings.file_format="PNG"
    scene.world=bpy.data.worlds.new("Original_Tackle_Test_World");scene.world.use_nodes=True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value=(.72,.80,.88,1)
    lamp_data=bpy.data.lights.new("Key","AREA");lamp=bpy.data.objects.new("Key",lamp_data)
    scene.collection.objects.link(lamp);lamp.location=(1,-3,5);lamp_data.energy=550;lamp_data.size=5
    for lod in range(3):
        actors={}
        for label in ["A","B"]:
            before=set(bpy.data.objects)
            file=ROOT/"baseline/dist/match3d/assets/rugby-v24/lod"/f"base_body_anim-lod{lod}.glb"
            assert file.exists(),str(file)
            bpy.ops.import_scene.gltf(filepath=str(file))
            added=[x for x in bpy.data.objects if x not in before]
            rigs=[x for x in added if x.type=="ARMATURE"]
            assert len(rigs)==1 and len(rigs[0].data.bones)==53
            rig=rigs[0];rig.name=f"OriginalTackle_LOD{lod}_{label}"
            meshes=[x for x in added if x.type=="MESH"]
            assert meshes
            if rig.animation_data:rig.animation_data_clear()
            for frame,(xyz) in zip(PHASES,ROOTS[label]):
                rig.location=xyz
                # Facing along the shared X-axis, no frame-dependent correction.
                rig.rotation_euler.z=(math.pi/2 if label=="A" else -math.pi/2)
                rig.keyframe_insert("location",frame=frame)
                rig.keyframe_insert("rotation_euler",frame=frame)
            for name,angles in POSE[label].items():
                bone=rig.pose.bones.get(name)
                if bone is None:continue
                bone.rotation_mode="XYZ"
                for frame,angle in zip(PHASES,angles):
                    bone.rotation_euler=(angle,0,0)
                    bone.keyframe_insert("rotation_euler",frame=frame)
            actors[label]={"rig":rig,"meshes":meshes}
        # Baseline sole calibration is measured, NOT an aesthetic shift of one
        # player relative to the other. One global floor for all LOD actors.
        scene.frame_set(1);bpy.context.view_layer.update()
        base={lab:mesh_regions(ob["meshes"]) for lab,ob in actors.items()}
        floor_z=min(base[lab][reg]["minZ"] for lab in ("A","B")
                  for reg in ("foot_l","foot_r")
                  if base[lab][reg]["minZ"] is not None)
        record={"lod":lod,"assets":{lab:sha(ROOT/"baseline/dist/match3d/assets/rugby-v24/lod"/f"base_body_anim-lod{lod}.glb") for lab in actors},
                "floorZMeasuredFromTrueSoles":floor_z,"frames":[]}
        for frame in PHASES:
            scene.frame_set(frame);bpy.context.view_layer.update()
            row=audit(actors["A"],actors["B"]);row["frame"]=frame
            delta=actors["B"]["rig"].location-actors["A"]["rig"].location
            row["rootDisplacementXYZ"]=[round(v,5) for v in delta]
            row["footToCalibratedFloor"]={lab:{
                side:(round(row["supports"][lab][side]["minZ"]-floor_z,5)
                if row["supports"][lab][side]["minZ"] is not None else None)
                for side in ("foot_l","foot_r")} for lab in actors}
            row["images"]=[]
            for view,direction in [("front",Vector((0,-1,0))),("profile",Vector((1,0,0)))]:
                cd=bpy.data.cameras.new("camera");cam=bpy.data.objects.new("camera",cd)
                scene.collection.objects.link(cam);cd.type="ORTHO";cd.ortho_scale=4.2
                center=Vector((0,0,1.0));cam.location=center+direction*6
                cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler()
                scene.camera=cam
                for obj in bpy.data.objects:
                    if obj.type=="MESH":obj.hide_render=obj not in (actors["A"]["meshes"]+actors["B"]["meshes"])
                path=OUT/f"original-lod{lod}-{frame:03d}-{view}.png"
                scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
                assert path.stat().st_size>2000
                row["images"].append({"file":path.name,"sha256":sha(path),"bytes":path.stat().st_size})
                bpy.data.objects.remove(cam,do_unlink=True)
            record["frames"].append(row)
        REPORT["lods"].append(record)
        for lab in actors:
            for mesh in actors[lab]["meshes"]:bpy.data.objects.remove(mesh,do_unlink=True)
            bpy.data.objects.remove(actors[lab]["rig"],do_unlink=True)
    REPORT["status"]="AUTHORED_AND_MEASURED_NOT_VISUALLY_APPROVED"
    REPORT["imagesProduced"]=sum(len(f["images"]) for l in REPORT["lods"] for f in l["frames"])
    # No automatic acceptance without independent image inspection.
    REPORT["visualApproval"]=False
except Exception as exc:
    REPORT["errors"].append(str(exc));REPORT["traceback"]=traceback.format_exc()
finally:
    out=OUT/"original-tackle-report.json"
    out.write_text(json.dumps(REPORT,indent=2)+"\n")
print(json.dumps({"status":REPORT["status"],"lods":len(REPORT["lods"]),"errors":REPORT["errors"]}))
if REPORT["status"]=="FAILED":raise SystemExit(1)
