"""R&D SHORT-STRIDE two-step standing approach, true skinned stance feet; no fall.
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
 "rootOffsetsAuthoredNotCMU":True,"lods":[],"errors":[],"interactionVersion":3,"standingGripOnly":True,"footLockVersion":2,"alternatingStance":True,"strideStudy":"TWO_8CM_STEPS_A_ONE_2CM_STEP_B"}
PHASES=[1,22,30,40,60,90]
DENSE_FRAMES=[10,18,24,26,28,32,34,36,38,45,50,70,80]
REGIONS={"chest":{"spine_02","spine_03"},"pelvis":{"pelvis","spine_01"},
"knee_l":{"thigh_l","calf_l"},"knee_r":{"thigh_r","calf_r"},
"foot_l":{"foot_l","ball_l"},"foot_r":{"foot_r","ball_r"}}
# The two original trajectories share a time origin. Differences in XY remain
# deliberate source authored movement, not per-frame snapping to opponent skin.
# Source-authored athletic approach, NOT opponent-relative cosmetic snapping:
# actors arrive with a forward lean into a ~0.7 m torso-to-torso
# interaction range (measured on the true skins; rejected if penetrated).
# Original source roots remain in original_tackle_probe.py.
# Distinct, authored *standing* approach: frame 40 and 60 are holds,
# not an animated fall. No opponent-driven per-frame root snap.
# Two authored short steps, not opponent-driven root snapping.
# A: +0.17 m to transfer support, then +0.17 m on the other leg.\n# Reduced anatomical stride, not a post-hoc skin contact translation.
ROOTS={
 "A":[(-1.50,0,0),(-1.13,0,0),(-1.05,0,0),(-0.97,0,0),(-0.97,0,0),(-1.30,0,0)],
 "B":[(0.80,0,0),(0.80,0,0),(0.78,0,0),(0.76,0,0),(0.76,0,0),(0.80,0,0)]
}

# These rotations are explicitly *hypotheses* awaiting contact validation.
# Keyframes represent phases of a first, strictly UNQUALIFIED choreography.
# No opponent-driven adjustments are made to the authored actor roots.
PHASE_NAMES={1:"approach",22:"left-foot-plant",30:"double-support-transfer",40:"standing-grip-attempt",
             60:"standing-grip-hold",90:"standing-release"}
# Standing torso and feet first; no artificial roll or fall.
POSE={
 "A":{
  "spine_01":[0,.025,0.0400,.055,.055,0],
  "spine_02":[0,.01,0.0225,.035,.035,0],
  "upperarm_l":[0,-.13,-0.2250,-.32,-.32,0],
  "upperarm_r":[0,.13,0.2250,.32,.32,0],
  "lowerarm_l":[0,.15,0.2300,.31,.31,0],
  "lowerarm_r":[0,-.15,-0.2300,-.31,-.31,0],
  "thigh_l":[0,.04,0.0325,.025,.025,0],"thigh_r":[0,-.04,-0.0325,-.025,-.025,0],
  "calf_l":[0,.035,0.0325,.03,.03,0],"calf_r":[0,.035,0.0325,.03,.03,0]
 },
 "B":{
  "spine_01":[0,0,0.0100,.02,.02,0],
  "spine_02":[0,0,0.0050,.01,.01,0],
  "upperarm_l":[0,.04,0.0900,.14,.14,0],
  "upperarm_r":[0,-.04,-0.0900,-.14,-.14,0],
  "thigh_l":[0,0,0.0075,.015,.015,0],"thigh_r":[0,0,-0.0075,-.015,-.015,0]
 }}

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
def coplanar_triangle_overlap(tri_a,tri_b,tol=1e-6):
    """Explicit 2-D coplanar triangle overlap, excluding tangency.
    BVH candidate pairs are tested after strict signed-plane validation.
    """
    a,b,c=tri_a;d,e,f=tri_b
    n=(b-a).cross(c-a); m=(e-d).cross(f-d)
    if n.length<tol or m.length<tol:return False
    n.normalize();m.normalize()
    if abs(abs(n.dot(m))-1)>1e-5:return False
    if any(abs(n.dot(p-a))>tol for p in (d,e,f)):return False
    axis=max(range(3),key=lambda k:abs(n[k]))
    def xy(p):return tuple(p[k] for k in range(3) if k!=axis)
    t1=[xy(v) for v in tri_a];t2=[xy(v) for v in tri_b]
    # SAT strict interior overlap. Border-only tangencies not crossings.
    for tri in (t1,t2):
        for x,y in zip(tri,tri[1:]+tri[:1]):
            normal=(-(y[1]-x[1]),y[0]-x[0])
            p1=[sum(q[k]*normal[k] for k in range(2)) for q in t1]
            p2=[sum(q[k]*normal[k] for k in range(2)) for q in t2]
            if max(p1)<=min(p2)+tol or max(p2)<=min(p1)+tol:return False
    return True

def mesh_regions(meshes):
    result={k:{"minZ":None,"vertices":0,"sumXY":[0.0,0.0]} for k in REGIONS}
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
                        world=ev.matrix_world@vertex.co
                        result[region]["sumXY"][0]+=world.x
                        result[region]["sumXY"][1]+=world.y
        finally:ev.to_mesh_clear()
    for region in result:
        count=result[region]["vertices"]
        result[region]["centroidXY"]=(
            [round(v/count,5) for v in result[region]["sumXY"]]
            if count else None)
        del result[region]["sumXY"]
    return result
def audit(a,b):
    va,fa=evaluated_geometry(a["meshes"]);vb,fb=evaluated_geometry(b["meshes"])
    bva=BVHTree.FromPolygons(va,fa,all_triangles=True)
    bvb=BVHTree.FromPolygons(vb,fb,all_triangles=True)
    pairs=bva.overlap(bvb);proper=0;coplanar=0
    def bounds(points):
        lo=[min(v[k] for v in points) for k in range(3)]
        hi=[max(v[k] for v in points) for k in range(3)]
        return {"minXYZ":[round(v,5) for v in lo],
                "maxXYZ":[round(v,5) for v in hi],
                "centerXYZ":[round((lo[k]+hi[k])/2,5) for k in range(3)]}
    skin_bounds={"A":bounds(va),"B":bounds(vb)}
    root_centers={name:[round(v,5) for v in ob["actor_root"].matrix_world.translation]
        for name,ob in (("A",a),("B",b))}
    bbox_separation_x=max(0.0,skin_bounds["A"]["minXYZ"][0]-skin_bounds["B"]["maxXYZ"][0],
                             skin_bounds["B"]["minXYZ"][0]-skin_bounds["A"]["maxXYZ"][0])
    for i,j in pairs:
        ta=[va[k] for k in fa[i]];tb=[vb[k] for k in fb[j]]
        if cross_triangles(*ta,*tb):proper+=1
        elif coplanar_triangle_overlap(ta,tb):coplanar+=1
    hands={};shoulders={}
    for source,target,tree in [("A",a,bvb),("B",b,bva)]:
        hands[source]={}
        for side in ("l","r"):
            bone=target["rig"].pose.bones.get("hand_"+side)
            if bone is None:raise RuntimeError("Canonical wrist missing")
            p=(target["rig"].matrix_world@bone.matrix).translation
            near=tree.find_nearest(p)
            hands[source][side]={"metersToOpposingTrueSkin":round(near[3],5),
                "worldPosition":[round(x,5) for x in p]}
    # The shoulder-to-torso measure is necessary for a rugby contact;
    # a close wrist alone cannot qualify a tackle.
    for source,target,tree in [("A",a,bvb),("B",b,bva)]:
        shoulders[source]={}
        for side in ("l","r"):
            bone=target["rig"].pose.bones.get("upperarm_"+side)
            if bone is None:raise RuntimeError("Canonical upper-arm bone missing")
            p=(target["rig"].matrix_world @ bone.matrix).translation
            near=tree.find_nearest(p)
            shoulders[source][side]={"metersToOpposingSkin":round(near[3],5)}
    return {"hands":hands,"shoulders":shoulders,"rootWorldCenters":root_centers,
       "skinBoundsWorld":skin_bounds,"skinBoundingBoxGapXMetres":round(bbox_separation_x,5),
       "potentialBVHPairs":len(pairs),
       "properNonCoplanarTriangleCrossings":proper,
       "coplanarTriangleInteriorOverlaps":coplanar,
       "coplanarOrTangentUnresolved":"Coplanar interiors tested; tangencies and volumetric containment unresolved",
       "trueSkinnedTriangleCount":{"A":len(fa),"B":len(fb)},
       "supports":{"A":mesh_regions(a["meshes"]),"B":mesh_regions(b["meshes"])}}
def true_chest_vertex_nearest(meshes,shoulder_world):
    """Select an evaluated actual torso skin vertex, not an invisible proxy.
    Limited to dominant spine groups; no repositioning of either actor root.
    """
    deps=bpy.context.evaluated_depsgraph_get()
    best=None;dist=float("inf");eligible=0
    for obj in meshes:
        ev=obj.evaluated_get(deps);skin=ev.to_mesh()
        try:
            for i,v in enumerate(skin.vertices):
                original=obj.data.vertices[i]
                g=max(original.groups,key=lambda q:q.weight,default=None)
                if g is None or g.weight<.25:continue
                if obj.vertex_groups[g.group].name not in ("spine_01","spine_02","spine_03"):continue
                p=ev.matrix_world@v.co
                d=(p-shoulder_world).length
                eligible+=1
                if d<dist:best=p.copy();dist=d
        finally:ev.to_mesh_clear()
    if best is None:raise RuntimeError("No actual torso skin weighted vertices to target")
    return best,dist,eligible

def prepare_arm_ik(scene,actors):
    """Natural two-bone IK attempt: arms pursue authored timed torso grasp.
    Targets are bound to real opponent torso vertices sampled on the SAME
    keyframe, but no actor root is changed based on the IK error.
    """
    targets={}
    for label in ("A",):
        rig=actors[label]["rig"];targets[label]={}
        for side in ("l","r"):
            forearm=rig.pose.bones.get("lowerarm_"+side)
            upper=rig.pose.bones.get("upperarm_"+side)
            if not forearm or not upper:raise RuntimeError("Missing 53-bone upper/lower arm")
            obj=bpy.data.objects.new(f"IK_{label}_{side}",None)
            scene.collection.objects.link(obj)
            con=forearm.constraints.new("IK")
            con.target=obj;con.chain_count=2;con.use_rotation=False
            con.influence=0
            for frame in PHASES:
                con.influence=(1.0 if frame in (40,60) else 0.0)
                con.keyframe_insert("influence",frame=frame)
            targets[label][side]={"obj":obj,"upper":upper,
                "reachM":upper.bone.length+forearm.bone.length}
    return targets

def author_contact_keyframes(scene,actors,ik):
    samples=[]
    for frame in PHASES:
        scene.frame_set(frame);bpy.context.view_layer.update()
        item={"frame":frame,"actors":{}}
        for label in ("A",):
            other="B"
            record={}
            for side in ("l","r"):
                data=ik[label][side]
                shoulder=(actors[label]["rig"].matrix_world@data["upper"].matrix).translation
                target,d,n=true_chest_vertex_nearest(actors[other]["meshes"],shoulder)
                data["obj"].location=target
                data["obj"].keyframe_insert("location",frame=frame)
                record[side]={"distanceShoulderToSurfaceM":round(d,5),
                     "armBoneLengthM":round(data["reachM"],5),
                     "reachableByLength":bool(d<=data["reachM"]+.02),
                     "eligibleRealSkinVertices":n,
                     "realTorsoTargetWorld":[round(v,5) for v in target]}
            item["actors"][label]=record
        samples.append(item)
    scene.frame_set(PHASES[0]);bpy.context.view_layer.update()
    return samples


def author_alternating_gait(scene,actors):
    """True canonical three-bone stance IK with phase-wise support transfer.
    A left anchors frames 22..30, then A right anchors 30..60.
    B right anchors 22..60. Roots remain unaltered at authored keys.
    """
    constraints=[]
    def lock(lab,side,start,active,off):
        scene.frame_set(start);bpy.context.view_layer.update()
        rig=actors[lab]["rig"]
        ankle=rig.pose.bones.get("foot_"+side)
        shin=rig.pose.bones.get("calf_"+side)
        thigh=rig.pose.bones.get("thigh_"+side)
        if not ankle or not shin or not thigh:
            raise RuntimeError("Canonical leg chain missing")
        target=bpy.data.objects.new(f"STEP_LOCK_{lab}_{side}_{start}",None)
        scene.collection.objects.link(target)
        target.location=(rig.matrix_world@ankle.matrix).translation.copy()
        con=ankle.constraints.new("IK")
        con.target=target;con.chain_count=3;con.use_rotation=False
        # No smoothing via hidden offsets: 5 exact phase keys plus transfer.
        influences={1:0,22:0,30:0,40:0,60:0,90:0}
        for f in active:influences[f]=1
        for frame,val in influences.items():
            con.influence=val;con.keyframe_insert("influence",frame=frame)
        constraints.append({"actor":lab,"side":side,"firstSupportFrame":start,
             "worldAnkleXYZ":[round(v,5) for v in target.location],
             "legChainM":round(ankle.bone.length+shin.bone.length+thigh.bone.length,5),
             "target":target})
    lock("A","l",22,[22,30],40)
    lock("B","r",22,[22,30,40,60],90)
    # The right stance anchor is sampled with the left stance constraint
    # already active. This is a source-authoring transfer, not a correction.
    lock("A","r",30,[30,40,60],90)
    scene.frame_set(1);bpy.context.view_layer.update()
    return constraints

def calibrate_stance_ankle_orientation(scene,actors):
    """Author the actual planted foot's local ankle bend (not root shift).
    Discrete candidate poses are evaluated on REAL armature-deformed shoe/body
    vertices at every support keyframe, including horizontal centroid drift.
    Optimization is independently rejected if no anatomical orientation fits.
    """
    measurements=[]
    # Without explicit pre-contact/rest keys, Blender extrapolates the first
    # authored ankle correction backwards to frame 1. That silently CHANGES
    # the later measured common floor and fakes an approved foot contact.
    foot=actors["A"]["rig"].pose.bones.get("foot_r")
    if foot is None:raise RuntimeError("Canonical right ankle unavailable")
    foot.rotation_mode="XYZ"
    for frame in (1,22,90):
        scene.frame_set(frame)
        foot.rotation_euler=(0.0,0.0,0.0)
        foot.keyframe_insert("rotation_euler",frame=frame)
    scene.frame_set(1);bpy.context.view_layer.update()
    neutral=mesh_regions(actors["A"]["meshes"])
    neutral_floor=min(v["minZ"] for actor in actors.values()
                      for v in mesh_regions(actor["meshes"]).values()
                      if v["minZ"] is not None and v["vertices"]>0
                      and v is not None) if False else None
    baseline_soles=[]
    for actor in actors.values():
        sampled=mesh_regions(actor["meshes"])
        for side in ("foot_l","foot_r"):
            baseline_soles.append(sampled[side]["minZ"])
    floor_z=min(x for x in baseline_soles if x is not None)
    # The stance transfer is the only problematic interval; untouched other
    # bone constraints and original authored roots remain our control.
    for frame in (30,40,60):
        scene.frame_set(frame);bpy.context.view_layer.update()
        side="r"
        rig=actors["A"]["rig"];foot=rig.pose.bones.get("foot_"+side)
        if foot is None:raise RuntimeError("Canonical ankle missing")
        foot.rotation_mode="XYZ"
        original=foot.rotation_euler.copy()
        ref=mesh_regions(actors["A"]["meshes"])[f"foot_{side}"]
        xy_ref=ref["centroidXY"]
        candidates=[]
        for ax in (-.40,-.25,-.10,0,.10,.25,.40):
            for ay in (-.30,-.15,0,.15,.30):
                foot.rotation_euler=(original.x+ax,original.y+ay,original.z)
                bpy.context.view_layer.update()
                m=mesh_regions(actors["A"]["meshes"])[f"foot_{side}"]
                h=m["minZ"]-floor_z
                dx=math.dist(m["centroidXY"],xy_ref)
                # Physical constraints first; graceful ankle range under 0.4 rad.
                admissible=(-.01 <= h <= .03 and dx <= .035)
                score=(abs(h-.005)+.2*dx+.01*(abs(ax)+abs(ay)))
                candidates.append((not admissible,score,ax,ay,h,dx))
        candidates.sort()
        _,score,ax,ay,h,drift=candidates[0]
        foot.rotation_euler=(original.x+ax,original.y+ay,original.z)
        foot.keyframe_insert("rotation_euler",frame=frame)
        bpy.context.view_layer.update()
        measured=mesh_regions(actors["A"]["meshes"])[f"foot_{side}"]
        measurements.append({"frame":frame,"side":side,"rotationCorrectionXYRad":[ax,ay],
            "minSoleAboveMeasuredFloorM":round(measured["minZ"]-floor_z,5),
            "centroidXYDriftVsOriginalPoseM":round(drift,5),
            "selectionAdmissible":bool(-.01<=measured["minZ"]-floor_z<=.03
                  and drift<=.035),
            "testedAnkleRotations":35})
    scene.frame_set(1);bpy.context.view_layer.update()
    return {"baselineFloorZ":round(floor_z,5),"candidateDiagnostics":measurements,
            "allAnkleSelectionsAdmissible":all(m["selectionAdmissible"] for m in measurements)}


def calibrate_true_sole_ik(scene,actors,locks):
    """Optimize stance target Z against evaluated skinned shoe minima, not ankle pivot.
    XY of each target remains fixed; never modify roots or calibrated floor.
    A failed reach/skin test remains a failed qualification, never a snap.
    """
    scene.frame_set(1);bpy.context.view_layer.update()
    floor=min(mesh_regions(a["meshes"])[side]["minZ"]
              for a in actors.values() for side in ("foot_l","foot_r"))
    # Source anchors are held at their authored XY; ensure neutral keys
    # delimit support intervals so Blender never extrapolates into rest.
    result=[]
    for item in locks:
        label,side=item["actor"],item["side"]
        target=item["target"];rig=actors[label]["rig"]
        pb=rig.pose.bones["foot_"+side]
        thigh=rig.pose.bones["thigh_"+side]
        calf=rig.pose.bones["calf_"+side]
        limit=thigh.bone.length+calf.bone.length+pb.bone.length
        z0=target.location.z
        for frame in PHASES:
            target.location.z=z0
            target.keyframe_insert("location",frame=frame)
        active=([22,30] if label=="A" and side=="l"
                else [30,40,60] if label=="A" else [22,30,40,60])
        for frame in active:
            scene.frame_set(frame);bpy.context.view_layer.update()
            original=target.location.copy()
            initial=mesh_regions(actors[label]["meshes"])["foot_"+side]
            xy0=initial["centroidXY"]
            hip=(rig.matrix_world@thigh.matrix).translation
            candidates=[]
            # Real shoe surfaces can move nonlinearly under three-bone IK.
            # Select by measured contact, not by assuming dZ(sole)=dZ(target).
            for delta_mm in range(-30,31,2):
                target.location=original+Vector((0,0,delta_mm/1000.0))
                bpy.context.view_layer.update()
                skin=mesh_regions(actors[label]["meshes"])["foot_"+side]
                height=skin["minZ"]-floor
                drift=math.dist(xy0,skin["centroidXY"])
                reach=(target.location-hip).length
                admissible=(-.0095<=height<=.03 and drift<=.05
                            and reach<=limit+.001)
                penalty=(max(0,-.0095-height)*30+
                         max(0,height-.03)*30+
                         max(0,drift-.05)*20+
                         max(0,reach-limit-.001)*30)
                score=penalty+abs(height-.004)+.15*drift+abs(delta_mm)*.00002
                candidates.append((not admissible,score,delta_mm,height,drift,reach))
            candidates.sort()
            _,_,best_mm,_,_,_=candidates[0]
            target.location=original+Vector((0,0,best_mm/1000.0))
            target.keyframe_insert("location",frame=frame)
            bpy.context.view_layer.update()
            after=mesh_regions(actors[label]["meshes"])["foot_"+side]
            h=after["minZ"]-floor
            d=math.dist(xy0,after["centroidXY"])
            reach=(target.location-hip).length
            result.append({"actor":label,"side":side,"frame":frame,
                "targetDeltaZMetres":best_mm/1000.0,"trueSkinSoleHeightM":round(h,5),
                "centroidDriftAgainstPreCorrectionM":round(d,5),
                "hipToTargetM":round(reach,5),"legChainM":round(limit,5),
                "reachable":reach<=limit+.001,
                "qualified":-.0095<=h<=.03 and d<=.05 and reach<=limit+.001})
    scene.frame_set(1);bpy.context.view_layer.update()
    return {"floorZ":round(floor,5),"samples":result,
            "candidateSpacingMm":2,"qualified":all(x["qualified"] for x in result)}

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
            # Imported glTF can leave the LAST sampled action pose as an
            # evaluated state even after clearing AnimationData. Reset ALL
            # 53 canonical bones to their neutral/rest transform first,
            # symmetrically for both actor copies, before authoring the source.
            for node in added:
                if node.animation_data:
                    node.animation_data_clear()
            for pose_bone in rig.pose.bones:
                pose_bone.matrix_basis.identity()
            bpy.context.view_layer.update()
            # Verify the imported rigs are neutral BEFORE any authored steps.
            assert all(p.matrix_basis.is_identity for p in rig.pose.bones),                 "Imported source GLB pose not neutralized"
            # glTF import can include multiple top-level nodes. Driving only
            # the Armature object leaves non-parented evaluated skin at origin.
            # A dedicated ACTOR root drives ALL imported top-level nodes, while
            # their original rest/world transforms remain unchanged.
            actor_root=bpy.data.objects.new(f"Original_LOD{lod}_{label}_Root",None)
            scene.collection.objects.link(actor_root)
            for node in added:
                if node.parent not in added:
                    original_world=node.matrix_world.copy()
                    node.parent=actor_root
                    node.matrix_world=original_world
            for frame,xyz in zip(PHASES,ROOTS[label]):
                actor_root.location=xyz
                # Fixed source facing, not opponent-facing cosmetic snapping.
                actor_root.rotation_euler.z=(math.pi/2 if label=="A" else -math.pi/2)
                actor_root.keyframe_insert("location",frame=frame)
                actor_root.keyframe_insert("rotation_euler",frame=frame)
            for name,angles in POSE[label].items():
                bone=rig.pose.bones.get(name)
                if bone is None:continue
                bone.rotation_mode="XYZ"
                for frame,angle in zip(PHASES,angles):
                    bone.rotation_euler=(angle,0,0)
                    bone.keyframe_insert("rotation_euler",frame=frame)
            actors[label]={"rig":rig,"meshes":meshes,"actor_root":actor_root}
        gait_locks=author_alternating_gait(scene,actors)
        ankle_calibration=calibrate_stance_ankle_orientation(scene,actors)
        sole_ik=calibrate_true_sole_ik(scene,actors,gait_locks)
        ik=prepare_arm_ik(scene,actors)
        authored_targets=author_contact_keyframes(scene,actors,ik)
        # Baseline sole calibration is measured, NOT an aesthetic shift of one
        # player relative to the other. One global floor for all LOD actors.
        scene.frame_set(1);bpy.context.view_layer.update()
        base={lab:mesh_regions(ob["meshes"]) for lab,ob in actors.items()}
        floor_z=min(base[lab][reg]["minZ"] for lab in ("A","B")
                  for reg in ("foot_l","foot_r")
                  if base[lab][reg]["minZ"] is not None)
        record={"lod":lod,"stanceAnkleCalibration":ankle_calibration,"trueSoleIKCalibration":sole_ik,"gaitStanceIK": [{k:v for k,v in item.items() if k!="target"} for item in gait_locks],"authoredContactTargets":authored_targets,"assets":{lab:sha(ROOT/"baseline/dist/match3d/assets/rugby-v24/lod"/f"base_body_anim-lod{lod}.glb") for lab in actors},
                "floorZMeasuredFromTrueSoles":floor_z,"frames":[]}
        for frame in PHASES:
            scene.frame_set(frame);bpy.context.view_layer.update()
            row=audit(actors["A"],actors["B"]);row["frame"]=frame
            row["phase"]=PHASE_NAMES[frame]
            delta=actors["B"]["actor_root"].location-actors["A"]["actor_root"].location
            row["rootDisplacementXYZ"]=[round(v,5) for v in delta]
            row["footToCalibratedFloor"]={lab:{
                side:(round(row["supports"][lab][side]["minZ"]-floor_z,5)
                if row["supports"][lab][side]["minZ"] is not None else None)
                for side in ("foot_l","foot_r")} for lab in actors}
            # Explicitly reject this cinematic phase if its true skin or
            # feet do not satisfy the physical acceptance preconditions.
            hand_distances=[row["hands"][lab][side]["metersToOpposingTrueSkin"]
                for lab in ("A","B") for side in ("l","r")]
            shoulder_distances=[row["shoulders"][lab][side]["metersToOpposingSkin"]
                for lab in ("A","B") for side in ("l","r")]
            row["quality"]={
                "fourHandsWithin5cm":all(x<=.05 for x in hand_distances)
                    if frame in (40,60) else None,
                "anyShoulderWithin8cm":any(x<=.08 for x in shoulder_distances)
                    if frame in (40,60) else None,
                "properNonCoplanarCrossingsZero":row["properNonCoplanarTriangleCrossings"]==0,
                "coplanarInteriorsZero":row["coplanarTriangleInteriorOverlaps"]==0,
                "floorPenetrationFound":any(
                    row["supports"][lab][reg]["minZ"] is not None
                    and row["supports"][lab][reg]["minZ"]<floor_z-.01
                    for lab in ("A","B") for reg in REGIONS),
                "allFeetWithin3cmOfFloor":all(
                    row["footToCalibratedFloor"][lab][side] is not None
                    and abs(row["footToCalibratedFloor"][lab][side])<=.03
                    for lab in ("A","B") for side in ("foot_l","foot_r")),
                "artisticApproval":"REQUIRES_INDEPENDENT_IMAGE_INSPECTION"
            }
            # Contact is measured against a shared physically calibrated
            # floor, and lack of penetration is NOT positive floor support.
            row["quality"]["groundedRegionsByActor"]={}
            row["quality"]["eachActorHasGroundSupport"]=True
            for lab in ("A","B"):
                grounded=[reg for reg in REGIONS
                    if row["supports"][lab][reg]["minZ"] is not None
                    and abs(row["supports"][lab][reg]["minZ"]-floor_z)<=.05]
                row["quality"]["groundedRegionsByActor"][lab]=grounded
                if not grounded:
                    row["quality"]["eachActorHasGroundSupport"]=False
            row["images"]=[]
            for view,direction in [("front",Vector((0,-1,0))),("profile",Vector((1,0,0))),("threequarter",Vector((1,-1,0)).normalized())]:
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
        # Separate temporal audit: NEVER interpolate already rounded report data.
        # Blender evaluates the true skin and triangle crossings on each added frame.
        record["denseFrames"]=[]
        for frame in DENSE_FRAMES:
            scene.frame_set(frame);bpy.context.view_layer.update()
            sample=audit(actors["A"],actors["B"])
            feet={lab:{side:round(sample["supports"][lab][side]["minZ"]-floor_z,5)
                       for side in ("foot_l","foot_r")} for lab in ("A","B")}
            minimum=min(h for lab in feet.values() for h in lab.values())
            support_side="foot_l" if frame<=30 else "foot_r"
            supporting={"A":feet["A"][support_side],"B":feet["B"]["foot_r"]}
            record["denseFrames"].append({"frame":frame,
                "footToCalibratedFloor":feet,
                "minimumFootSkinHeightM":minimum,
                "stanceSideA":support_side,
                "stanceFootHeightsM":supporting,
                "supportQualified":all(-.01<=h<=.03 for h in supporting.values()),
                "noAnyFootPenetrationOver1cm":minimum>=-.01,
                "properNonCoplanarTriangleCrossings":sample["properNonCoplanarTriangleCrossings"],
                "coplanarTriangleInteriorOverlaps":sample["coplanarTriangleInteriorOverlaps"],
                "footCentroidXY":{lab:{side:sample["supports"][lab][side]["centroidXY"]
                    for side in ("foot_l","foot_r")} for lab in ("A","B")}})
        scene.frame_set(PHASES[0]);bpy.context.view_layer.update()
        # Foot gliding on a planted stance is disqualifying independently of
        # floor height: compare TRUE dominant-weighted skinned foot centroids.
        record["footGlideByPhase"]=[]
        for prev,now in zip(record["frames"],record["frames"][1:]):
            row={"startFrame":prev["frame"],"endFrame":now["frame"],"actors":{}}
            for lab in ("A","B"):
                vals={}
                for side in ("foot_l","foot_r"):
                    p=prev["supports"][lab][side]["centroidXY"]
                    q=now["supports"][lab][side]["centroidXY"]
                    vals[side]=round(math.dist(p,q),5) if p and q else None
                row["actors"][lab]=vals
            row["bothActorsFeetStayWithin5cm"]=all(
                row["actors"][lab][side] is not None
                and row["actors"][lab][side]<=.05
                for lab in ("A","B") for side in ("foot_l","foot_r"))
            record["footGlideByPhase"].append(row)
        # A walker needs at least ONE stance foot planted per step.
        # Requiring both to remain fixed would prohibit locomotion.
        for phase in record["footGlideByPhase"]:
            phase["atLeastOneStanceFootStableByActor"]={}
            for lab in ("A","B"):
                phase["atLeastOneStanceFootStableByActor"][lab]=any(
                    phase["actors"][lab][side] is not None
                    and phase["actors"][lab][side]<=.05
                    for side in ("foot_l","foot_r"))
            phase["stanceFootStableByActor"]={
                "A": phase["actors"]["A"]["foot_"+("l" if phase["startFrame"]==22 else "r")]<=.05,
                "B": phase["actors"]["B"]["foot_r"]<=.05}
        # An anchor with low XY drift can still be 6 cm in the air.
        # Validate the intended stance foot's TRUE evaluated skin relative
        # to the same calibrated floor as all other actors.
        for phase in record["footGlideByPhase"]:
            if (phase["startFrame"],phase["endFrame"]) not in ((22,30),(30,40)):
                continue
            support="foot_l" if phase["startFrame"]==22 else "foot_r"
            phase["sourceStanceSideA"]=support
            phase["stanceSkinHeightsA"]=[
                round(f["supports"]["A"][support]["minZ"]-floor_z,5)
                for f in record["frames"]
                if f["frame"] in (phase["startFrame"],phase["endFrame"])
            ]
            phase["stanceGroundedA"]=all(
                -.01 <= h <= .03 for h in phase["stanceSkinHeightsA"])
            # At least one supporting skinned foot per actor within 3cm,
            # plus neither supporting foot penetrating > 1cm.
            phase["stanceGroundedB"]=all(
                any(f["footToCalibratedFloor"]["B"][s] is not None
                    and -.01<=f["footToCalibratedFloor"]["B"][s]<=.03
                    for s in ("foot_l","foot_r"))
                for f in record["frames"]
                if f["frame"] in (phase["startFrame"],phase["endFrame"]))
            # Reject >1 cm floor penetration even when XY lock is excellent.
            phase["standingStance3DQualified"]=(
                phase["stanceGroundedA"]
                and phase["stanceGroundedB"]
                and all(phase["stanceFootStableByActor"].values()))
        REPORT["lods"].append(record)
        for item in gait_locks:
            bpy.data.objects.remove(item["target"],do_unlink=True)
        for lab in ik:
            for side in ik[lab]:
                bpy.data.objects.remove(ik[lab][side]["obj"],do_unlink=True)
        for lab in actors:
            for mesh in actors[lab]["meshes"]:bpy.data.objects.remove(mesh,do_unlink=True)
            bpy.data.objects.remove(actors[lab]["rig"],do_unlink=True)
            bpy.data.objects.remove(actors[lab]["actor_root"],do_unlink=True)
    REPORT["contactStageQualified"]=all(
        all(f["hands"]["A"][side]["metersToOpposingTrueSkin"]<=.05 for side in ("l","r")) and
        any(f["shoulders"]["A"][side]["metersToOpposingSkin"]<=.08 for side in ("l","r")) and
        f["quality"]["properNonCoplanarCrossingsZero"] and f["quality"]["coplanarInteriorsZero"]
        for lod in REPORT["lods"] for f in lod["frames"] if f["frame"] in (40,60))
    REPORT["authoredArmTargetsReachable"]=all(
        sample["actors"][lab][side]["reachableByLength"]
        for lod in REPORT["lods"] for sample in lod["authoredContactTargets"]
        if sample["frame"] in (40,60) for lab in ("A",) for side in ("l","r"))
    REPORT["standingFootSlipQualified"]=all(
        all(phase["atLeastOneStanceFootStableByActor"].values()) and
        all(phase["stanceFootStableByActor"].values())
        for lod in REPORT["lods"] for phase in lod["footGlideByPhase"]
        if phase["startFrame"] in (22,30) and phase["endFrame"] in (30,40))
    REPORT["calibrationFloorConsistent"]=all(
        abs(lod["stanceAnkleCalibration"]["baselineFloorZ"]-
            lod["floorZMeasuredFromTrueSoles"])<=.001
        for lod in REPORT["lods"])
    REPORT["stanceAnkleOrientationQualified"]=all(
        lod["stanceAnkleCalibration"]["allAnkleSelectionsAdmissible"]
        for lod in REPORT["lods"])
    REPORT["trueSoleIKCandidateQualified"]=all(lod["trueSoleIKCalibration"]["qualified"] for lod in REPORT["lods"])
    REPORT["stanceContact3DQualified"]=all(
        phase.get("standingStance3DQualified",False)
        for lod in REPORT["lods"] for phase in lod["footGlideByPhase"]
        if (phase["startFrame"],phase["endFrame"]) in ((22,30),(30,40)))
    REPORT["floorStageQualified"]=all(
        not f["quality"]["floorPenetrationFound"]
        and f["quality"]["eachActorHasGroundSupport"]
        for lod in REPORT["lods"] for f in lod["frames"])
    REPORT["denseTemporalFloorQualified"]=all(
        sample["supportQualified"] and sample["noAnyFootPenetrationOver1cm"]
        for lod in REPORT["lods"] for sample in lod["denseFrames"])
    REPORT["denseFramesPerLOD"]=len(DENSE_FRAMES)
    REPORT["cameraViews"]=["front","profile","threequarter"]
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
