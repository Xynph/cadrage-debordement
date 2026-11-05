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
    visuals={}
    for lod in range(3):
        visuals[lod]={}
        entry={"lod":lod,"actors":[],"status":"FAIL"}
        for label,source,action in source_actors:
            before=set(bpy.data.objects)
            asset=ROOT/"baseline"/"dist"/"match3d"/"assets"/"rugby-v24"/"lod"/f"base_body_anim-lod{lod}.glb"
            bpy.ops.import_scene.gltf(filepath=str(asset))
            added=[o for o in bpy.data.objects if o not in before]
            targets=[o for o in added if o.type=="ARMATURE"]
            assert len(targets)==1 and len(targets[0].data.bones)==53,(lod,label)
            target=targets[0];target.name=f"CD_LOD{lod}_{label}"
            visuals[lod][label]={"armature":target,"meshes":[o for o in added if o.type=="MESH"]}
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
    # Use the actual evaluated deforming vertices of BOTH canonical characters.
    # Six support regions are classified by their original skin weights,
    # not by proxy physics rigid-body centers. This is RETARGET CLIP skin
    # geometry, not yet Godot post-impact skinning.
    from mathutils import Vector
    region_bones={
        "chest":{"spine_02","spine_03"},
        "pelvis":{"pelvis","spine_01"},
        "knee_l":{"thigh_l","calf_l"},
        "knee_r":{"thigh_r","calf_r"},
        "foot_l":{"foot_l","ball_l"},
        "foot_r":{"foot_r","ball_r"},
    }
    def true_skin_regions(meshes):
        deps=bpy.context.evaluated_depsgraph_get()
        minimum={k:float("inf") for k in region_bones}
        observed={k:0 for k in region_bones}
        total=0
        for obj in meshes:
            ev=obj.evaluated_get(deps)
            mesh=ev.to_mesh()
            try:
                if not mesh.vertices:continue
                stride=max(1,len(mesh.vertices)//1500)
                for index in range(0,len(mesh.vertices),stride):
                    vertex=mesh.vertices[index]
                    # Evaluated Armature modifier preserves glTF vertex
                    # ordering and vertex group assignments.
                    source=obj.data.vertices[index]
                    dominant=max(source.groups,key=lambda g:g.weight,default=None)
                    if dominant is None:continue
                    name=obj.vertex_groups[dominant.group].name
                    for region,names in region_bones.items():
                        if name in names and dominant.weight>=.2:
                            point=ev.matrix_world@vertex.co
                            minimum[region]=min(minimum[region],point.z)
                            observed[region]+=1
                    total+=1
            finally:ev.to_mesh_clear()
        return {"minSkinnedZMetres":{k:(round(v,5) if math.isfinite(v) else None) for k,v in minimum.items()},
                "sampleCounts":observed,"sampledSkinVertices":total,
                "status":"BLENDER_EVALUATED_REAL_SKIN_WEIGHTS_DIAGNOSTIC"}
    scene=bpy.context.scene
    scene.render.engine="CYCLES"
    scene.cycles.device="CPU"
    scene.cycles.samples=3
    scene.render.resolution_x=440
    scene.render.resolution_y=360
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG"
    if scene.world is None:scene.world=bpy.data.worlds.new("CD_RD_CMU_World")
    scene.world.use_nodes=True
    bg=scene.world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value=(.78,.85,.9,1)
    bg.inputs["Strength"].default_value=1.1
    lamp_data=bpy.data.lights.new("CD_RD_Key","AREA")
    lamp=bpy.data.objects.new("CD_RD_Key",lamp_data)
    scene.collection.objects.link(lamp)
    lamp.location=(1,-3,4);lamp_data.energy=450;lamp_data.shape="DISK";lamp_data.size=4
    scene.render.film_transparent=False
    all_meshes=[x for x in bpy.data.objects if x.type=="MESH"]
    report["visualPairs"]=[]
    for lod in range(3):
        actors=visuals[lod]
        targets=[actors[name]["armature"] for name in ("A","B")]
        meshes=actors["A"]["meshes"]+actors["B"]["meshes"]
        if len(meshes)<2:raise RuntimeError("Canonical skin geometry absent")
        # Source motion remains synchronized. The BVH world-root trajectory
        # is restored only as a preview offset; no movement is invented.
        for frame in [1,45,90]:
            scene.frame_set(frame);bpy.context.view_layer.update()
            src_roots=[]
            for label,source,action in source_actors:
                pelvis=source.pose.bones.get("Hips")
                src_roots.append((source.matrix_world@pelvis.matrix).translation.copy())
            center=(src_roots[0]+src_roots[1])/2
            for idx,target in enumerate(targets):
                offset=src_roots[idx]-center
                target.location.x=offset.x
                target.location.y=offset.y
            bpy.context.view_layer.update()
            supports={label:true_skin_regions(actors[label]["meshes"]) for label in ("A","B")}
            pair={"lod":lod,"frame":frame,"supports":supports,"images":[],
                  "sourceRootSeparationXYMetres":round(math.dist(
                      src_roots[0][:2],src_roots[1][:2]),5)}
            for view in ("front","profile"):
                direction=Vector((0,-1,0)) if view=="front" else Vector((1,0,0))
                camd=bpy.data.cameras.new(f"CD_RD_LOD{lod}_{frame}_{view}")
                cam=bpy.data.objects.new(camd.name,camd);scene.collection.objects.link(cam)
                camd.type="ORTHO";camd.ortho_scale=2.75
                cam.location=direction*5+Vector((0,0,0.9))
                cam.rotation_euler=(Vector((0,0,0.9))-cam.location).to_track_quat("-Z","Y").to_euler()
                scene.camera=cam
                for obj in all_meshes:obj.hide_render=obj not in meshes
                path=OUT/f"lod{lod}-duo-{frame:03d}-{view}.png"
                scene.render.filepath=str(path)
                bpy.ops.render.render(write_still=True)
                if not path.exists() or path.stat().st_size<2000:
                    raise RuntimeError(f"No real retarget skin render: {path}")
                pair["images"].append({"file":path.name,"bytes":path.stat().st_size})
                bpy.data.objects.remove(cam,do_unlink=True)
            report["visualPairs"].append(pair)
        for target in targets:target.location=(0,0,0)
    assert len(report["visualPairs"])==9
    report["skinSupportsAreFromRagdollPhysics"]=False
    report["visualApproved"]=False
    report["status"]="TRANSFERRED_2_REAL_CLIPS_TO_3_CANONICAL_LODS_NOT_ART_APPROVED"
except Exception as exc:
    report["errors"].append(str(exc));report["traceback"]=traceback.format_exc()
finally:
    (OUT/"retarget-report.json").write_text(json.dumps(report,indent=2,default=str)+"\n")
print(json.dumps({"status":report["status"],"lodCount":len(report["lods"]),"errors":report["errors"]}))
if report["status"]=="FAIL":raise SystemExit(1)
