"""Exploratory REAL dual-CMU-BVH -> canonical 53 bones via Blender/Rigger.
No hand-authored tackle poses. Operates only on copies, source motions are
not redistributed as standalone data. Outputs metrics, not artistic approval.
"""
import bpy,json,sys,traceback,math
from pathlib import Path
ROOT=Path.cwd();OUT=ROOT/"rd-report"/"cmu-duo";OUT.mkdir(parents=True,exist_ok=True)
report={"schema":1,"status":"FAIL","source":"CMU 18_03 / 19_03, synchronized 593 frames",
        "samplesAreFromTrueBvh":True,"sourceMotion":"A pulls B / B resists",
        "isRugbyTackle":False,"artisticApproval":False,"lods":[],"errors":[]}
try:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sys.path.insert(0,str(ROOT/"rd-work"/"rigger"))
    from rigger import retarget,utils
    import rigger
    rigger.register()
    source_actors=[]
    for label,relative in [("A","18_03.bvh"),("B","19_03.bvh")]:
        before=set(bpy.data.objects)
        path=ROOT/"rd-work"/"cmu-duo"/relative
        assert path.exists(),str(path)
        assert hasattr(bpy.ops.import_anim,"bvh"),"Official Blender BVH import operator missing"
        bpy.ops.import_anim.bvh(filepath=str(path),global_scale=0.01,
            axis_forward="-Z",axis_up="Y")
        newcomers=[o for o in bpy.data.objects if o not in before]
        arms=[o for o in newcomers if o.type=="ARMATURE"]
        assert len(arms)==1,(label,len(arms))
        arm=arms[0];arm.name="CMU_"+label+"_Source"
        action=arm.animation_data.action if arm.animation_data else None
        assert action is not None,(label,"no true BVH Action")
        source_actors.append((label,arm,action))
    report["sourceActors"]=[{"actor":label,"boneCount":len(arm.data.bones),
        "action":action.name,"frameRange":list(map(float,action.frame_range))}
        for label,arm,action in source_actors]
    # First prove actual paired motion can be transferred to each LOD,
    # then test artistic contact separately. The same source frame interval
    # is used for both actors, without synthetic motion insertion.
    for lod in range(3):
        entry={"lod":lod,"actors":[],"status":"FAIL"}
        for label,source,action in source_actors:
            before=set(bpy.data.objects)
            asset=ROOT/"baseline"/"dist"/"match3d"/"assets"/"rugby-v24"/"lod"/f"base_body_anim-lod{lod}.glb"
            bpy.ops.import_scene.gltf(filepath=str(asset))
            added=[o for o in bpy.data.objects if o not in before]
            targets=[o for o in added if o.type=="ARMATURE"]
            assert len(targets)==1 and len(targets[0].data.bones)==53,(lod,label)
            target=targets[0];target.name=f"CD_LOD{lod}_{label}"
            settings=bpy.context.scene.rigger_remap
            settings.source=source;settings.target=target
            settings.multiple=False
            settings.frame_start=1;settings.frame_end=90
            settings.root_motion=False
            settings.in_place=False
            settings.action_name=f"CMU_{label}_RealToCD_LOD{lod}_90frames"
            count=retarget.auto_map(settings)
            pairs=[{"source":x.source,"target":x.target} for x in settings.items]
            if count<10:raise RuntimeError(f"Too few retarget bones {count} for {label} LOD{lod}")
            utils.assign_action(source,action)
            baked=retarget.Retargeter(bpy.context,settings).run()
            assert baked is not None
            captures=[]
            for frame in [1,30,60,90]:
                bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
                pose={}
                for key in ["pelvis","spine_03","hand_l","hand_r","foot_l","foot_r"]:
                    bone=target.pose.bones.get(key)
                    if bone is not None:
                        pos=target.matrix_world@bone.matrix
                        pose[key]=[round(v,5) for v in pos.translation]
                captures.append({"frame":frame,"bones":pose})
            entry["actors"].append({"actor":label,"mappedBoneCount":count,
                "mappedPairs":pairs,"bakedAction":baked.name,
                "sourceAction":action.name,"sourceFramesUsed":[1,90],
                "targetBoneCount":len(target.data.bones),"poses":captures})
        assert len(entry["actors"])==2
        for actor in entry["actors"]:
            hands=[q["bones"].get("hand_r") for q in actor["poses"]]
            assert all(p is not None for p in hands)
            delta=math.dist(hands[0],hands[-1])
            actor["rightHandTravelM"]=delta
            assert delta>0.001,(lod,actor["actor"],"no real right hand motion")
        entry["status"]="PASS_BVH_TRANSFER_NUMERIC_ONLY"
        report["lods"].append(entry)
    report["status"]="TRANSFERRED_2_REAL_CLIPS_TO_3_CANONICAL_LODS_NOT_ART_APPROVED"
except Exception as exc:
    report["errors"].append(str(exc));report["traceback"]=traceback.format_exc()
finally:
    (OUT/"retarget-report.json").write_text(json.dumps(report,indent=2,default=str)+"\n")
print(json.dumps({"status":report["status"],"lodCount":len(report["lods"]),"errors":report["errors"]}))
if report["status"]=="FAIL":raise SystemExit(1)
