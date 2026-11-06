"""Ara -> 53-bone canonical retarget probe, controlled source action, no artistic claim."""
import bpy,sys,json,math,traceback
from pathlib import Path
from mathutils import Quaternion
native_run='--native-run' in sys.argv
root=Path.cwd();out=root/'rd-report';out.mkdir(exist_ok=True)
report={'schema':1,'target':'canonical LOD0 53 joints','artisticApproval':False,'status':'NOT_TESTED','probeMode':'ara-native-run' if native_run else 'controlled'}
try:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sys.path.insert(0,str(root/'rd-work/rigger'))
    import rigger
    from rigger import retarget,utils
    rigger.register()
    assets=list((root/'rd-work/ara-export').rglob('*.glb'))
    if not assets:raise FileNotFoundError('Ara exported GLB unavailable')
    srcfile=max(assets,key=lambda f:f.stat().st_size)
    bpy.ops.import_scene.gltf(filepath=str(srcfile))
    sources=[o for o in bpy.data.objects if o.type=='ARMATURE']
    if len(sources)!=1:raise ValueError('Ara source armature count != 1')
    source=sources[0];report['araSourceBones']=len(source.data.bones)
    report['araOriginalActions']=[a.name for a in bpy.data.actions]
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(root/'baseline/dist/match3d/assets/rugby-v24/lod/base_body_anim-lod0.glb'))
    new=[o for o in bpy.data.objects if o not in before]
    targets=[o for o in new if o.type=='ARMATURE'];meshes=[o for o in new if o.type=='MESH']
    if len(targets)!=1 or len(targets[0].data.bones)!=53:raise ValueError('Canonical 53 joints unavailable')
    target=targets[0];settings=bpy.context.scene.rigger_remap
    settings.source=source;settings.target=target
    settings.multiple=False;settings.frame_start=1;settings.frame_end=13
    settings.root_motion=False;settings.in_place=False;settings.action_name='RD_Ara_Native_Run_to_Canonical53' if native_run else 'RD_Ara_Controlled_to_Canonical53'
    count=retarget.auto_map(settings)
    report['mappedBoneCount']=count
    report['mappedPairs']=[{'source':i.source,'target':i.target} for i in settings.items]
    if count<10:raise ValueError('Under 10 semantic pairs; no retarget')
    arms=[i for i in settings.items if retarget.classify(i.source) and retarget.classify(i.source)[0]=='upper_arm']
    if not arms:raise ValueError('No upper arm mapped')
    pair=arms[0];pb=source.pose.bones[pair.source]
    if native_run:
        action=bpy.data.actions.get('Run')
        if action is None:raise ValueError('Ara native Run action unavailable')
        utils.assign_action(source,action)
        report['motionSource']='ARA_NATIVE_RUN_GLTF_ACTION'
        report['sourceAction']=action.name
        report['sourceFrameRange']=[float(v) for v in action.frame_range]
        if action.frame_range[1]-action.frame_range[0]<12:
            raise ValueError('Ara Run shorter than required 13 sample frames')
        source_world=[]
        for frame in (1,7,13):
            bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
            source_world.append((source.matrix_world @ pb.matrix).copy())
        report['sourceArmMatrixDelta']=max(abs(source_world[0][i][j]-source_world[1][i][j]) for i in range(4) for j in range(4))
        if report['sourceArmMatrixDelta']<0.001:raise ValueError('Native Run does not animate mapped left arm')
    else:
        pb.rotation_mode='QUATERNION'
        # Deterministic calibration, never presented as a native Ara clip.
        for frame,angle in ((1,0),(7,35),(13,0)):
            pb.rotation_quaternion=Quaternion((0,0,1),math.radians(angle))
            pb.keyframe_insert(data_path='rotation_quaternion',frame=frame)
        report['motionSource']='CONTROLLED_KEYFRAMES_ON_ARA_RIG_NOT_ORIGINAL_ARA_CLIP'
    report['drivenBone']=pair.source;report['targetBone']=pair.target
    baked=retarget.Retargeter(bpy.context,settings).run()
    report['bakedAction']=baked.name
    snapshots=[]
    for frame in (1,4,7,10,13):
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
        bm=target.matrix_world @ target.pose.bones[pair.target].matrix
        deps=bpy.context.evaluated_depsgraph_get()
        vertices=[]
        for obj in meshes[:2]:
            ev=obj.evaluated_get(deps);me=ev.to_mesh()
            try:
                for k in (0,len(me.vertices)//2,len(me.vertices)-1):
                    if me.vertices:vertices.append(list(obj.matrix_world @ me.vertices[k].co))
            finally:ev.to_mesh_clear()
        snapshots.append({'frame':frame,'worldBoneMatrix':[float(x) for row in bm for x in row],
                          'skinnedWorldVertices':vertices})
    report['samples']=snapshots
    # Actual Blender workbench captures (not mockups), reproducible orthographic views.
    from mathutils import Vector
    def render_pose(label,subjects,frame,view):
        scene=bpy.context.scene
        scene.frame_set(frame)
        # Cycles CPU avoids EGL/Workbench GPU dependencies on ubuntu-24.04 runners.
        scene.render.engine='CYCLES'
        scene.cycles.device='CPU'
        scene.cycles.samples=4
        scene.render.resolution_x=360;scene.render.resolution_y=360
        scene.render.resolution_percentage=100
        scene.render.image_settings.file_format='PNG'
        scene.render.film_transparent=False
        if scene.world is None:scene.world=bpy.data.worlds.new('RD_CPU_world')
        scene.world.use_nodes=True
        background=scene.world.node_tree.nodes.get('Background')
        if background is not None:
            background.inputs['Color'].default_value=(0.8,0.8,0.8,1)
            background.inputs['Strength'].default_value=1.0
        all_meshes=[o for o in bpy.data.objects if o.type=='MESH']
        active=set(subjects)
        initial={o:o.hide_render for o in all_meshes}
        try:
            for o in all_meshes:o.hide_render=o not in active
            points=[o.matrix_world @ Vector(corner) for o in subjects for corner in o.bound_box]
            center=sum(points,Vector())/len(points)
            span=max(max(v[i] for v in points)-min(v[i] for v in points) for i in range(3))
            camdata=bpy.data.cameras.new('RD_camera_'+label+'_'+view)
            camera=bpy.data.objects.new(camdata.name,camdata)
            scene.collection.objects.link(camera)
            camdata.type='ORTHO';camdata.ortho_scale=max(0.5,span*1.25)
            direction=Vector((0,-1,0)) if view=='front' else Vector((1,0,0))
            camera.location=center+direction*max(2.0,span*2.5)
            camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
            scene.camera=camera
            path=out/'captures'/('ara-'+('native-run-' if native_run else '')+label+'-frame'+str(frame)+'-'+view+'.png')
            path.parent.mkdir(exist_ok=True)
            scene.render.filepath=str(path)
            bpy.ops.render.render(write_still=True)
            return {'file':str(path.relative_to(out)),'bytes':path.stat().st_size}
        finally:
            for o,v in initial.items():o.hide_render=v
    report['captures']=[]
    for frame in (1,7,13):
        for view in ('front','profile'):
            report['captures'].append(render_pose('source', [o for o in bpy.data.objects if o.type=='MESH' and o not in meshes],frame,view))
            report['captures'].append(render_pose('target',meshes,frame,view))
    report['maxBoneMatrixComponentMotion']=max(abs(x-y) for x,y in zip(snapshots[0]['worldBoneMatrix'],snapshots[2]['worldBoneMatrix']))
    report['maxWorldVertexMotionMeters']=max((math.dist(a,b) for a,b in zip(snapshots[0]['skinnedWorldVertices'],snapshots[2]['skinnedWorldVertices'])),default=0)
    if report['maxBoneMatrixComponentMotion']<1e-5:raise AssertionError('Target did not move')
    copy=out/'copies'/('ara-native-run-retarget-canonical-lod0.glb' if native_run else 'ara-controlled-retarget-canonical-lod0.glb');copy.parent.mkdir(exist_ok=True)
    for o in bpy.context.selected_objects:o.select_set(False)
    target.select_set(True)
    for o in meshes:o.select_set(True)
    bpy.context.view_layer.objects.active=target
    bpy.ops.export_scene.gltf(filepath=str(copy),export_format='GLB',use_selection=True,export_animations=True)
    report['copyBytes']=copy.stat().st_size
    report['copyExport']=str(copy.relative_to(out))
    report['status']='ARA_NATIVE_RUN_TRANSFERRED_NOT_ART_APPROVED' if native_run else 'CONTROLLED_SOURCE_POSE_RETARGETED_NOT_ART_APPROVED'
    report['actualAraClipRetargetQualified']=bool(native_run and report['maxBoneMatrixComponentMotion']>1e-5)
except Exception as e:
    report['status']='FAIL';report['error']=str(e);report['traceback']=traceback.format_exc()
finally:
    (out/('ara-retarget-native-run.json' if native_run else 'ara-retarget-controlled.json')).write_text(json.dumps(report,indent=2,default=str)+'\n')
print(json.dumps({'status':report['status'],'mapped':report.get('mappedBoneCount')}))
if report['status']=='FAIL':raise SystemExit(1)
