"""Experimental Ara canonical retarget and Rigger real-rugbyman fitting on disposable Blender copies.
All outputs are diagnostics: never modify baseline GLBs or game sources.
"""
import bpy, json, math, traceback
from pathlib import Path
from mathutils import Vector

root=Path.cwd()
out=root/'rd-report'
out.mkdir(exist_ok=True)
report={'schema':1,'tool':'Ara+Rigger','baselineReadOnly':True,'ara':{},'rigger':{},'qualification':{'araRetarget':False,'riggerFitting':False,'riggerWeights':False}}
def record_error(section,e):
    report[section]['error']=str(e)
    report[section]['traceback']=traceback.format_exc()
def objects_import(path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [o for o in bpy.data.objects if o.type=='ARMATURE'],[o for o in bpy.data.objects if o.type=='MESH']
def snapshot_weights(meshes):
    data={}
    for obj in meshes:
        group_names={g.index:g.name for g in obj.vertex_groups}
        sums=[];positive=0;largest=0
        for v in obj.data.vertices:
            w=[g.weight for g in v.groups if g.weight>1e-8]
            sums.append(sum(w))
            positive+=int(bool(w))
            largest=max(largest,len(w))
        data[obj.name]={'vertices':len(obj.data.vertices),'weighted':positive,'unweighted':len(sums)-positive,
            'maxInfluences':largest,'maxSumError':max((abs(x-1) for x in sums if x>0),default=0),
            'groups':len(group_names)}
    return data

canon=root/'baseline/dist/match3d/assets/rugby-v24/lod/base_body_anim-lod0.glb'
try:
    rigs,meshes=objects_import(canon)
    if len(rigs)!=1:raise ValueError('Canonical body must have one armature')
    rig=rigs[0]
    report['canonical']={'bones':len(rig.data.bones),'names':[b.name for b in rig.data.bones],
        'meshes':len(meshes),'weights':snapshot_weights(meshes)}
except Exception as e:
    record_error('rigger',e)

try:
    # Import Ara's actually exported artifact, not an imagined source character.
    ara_files=sorted((root/'rd-work/ara-export').rglob('*.glb'))
    if not ara_files:raise FileNotFoundError('Ara Athletic_man.glb not generated')
    ara_path=max(ara_files,key=lambda p:p.stat().st_size)
    ara_rigs,ara_meshes=objects_import(ara_path)
    report['ara']={'file':str(ara_path.relative_to(root)),'bytes':ara_path.stat().st_size,
        'armatures':len(ara_rigs),'bones':[b.name for a in ara_rigs for b in a.data.bones],
        'meshes':len(ara_meshes),'weights':snapshot_weights(ara_meshes),
        'actions':[(a.name,len(a.fcurves) if hasattr(a,'fcurves') else None) for a in bpy.data.actions]}
    # Semantic mapping uses Rigger's real upstream classifier. A matching name is NOT a completed retarget.
    import sys
    sys.path.insert(0,str(root/'rd-work/rigger'))
    from rigger.retarget import classify_armature
    if len(ara_rigs)!=1:raise ValueError('Ara GLB has no unique armature to retarget')
    ara_roles=classify_armature(ara_rigs[0])
    canonical_rigs,_=objects_import(canon)
    canonical_roles=classify_armature(canonical_rigs[0])
    matches=[]
    for role,source_names in ara_roles.items():
        target_names=canonical_roles.get(role,[])
        if len(source_names)==1 and len(target_names)==1:
            matches.append({'role':str(role),'ara':source_names[0],'canonical':target_names[0]})
    report['ara']['semanticMatches']=matches
    report['ara']['semanticMatchCount']=len(matches)
    report['ara']['unmappedCanonicalBoneCount']=53-len(set(m['canonical'] for m in matches))
    # No automatic retarget pass unless actual animations and a pose transfer are evaluated.
    report['ara']['status']='MAPPING_ONLY_NOT_RETARGETED'
except Exception as e:
    record_error('ara',e)

try:
    rigs,meshes=objects_import(canon)
    import sys
    sys.path.insert(0,str(root/'rd-work/rigger'))
    import rigger
    from rigger.quick_rig import guess_limbs
    from rigger import markers,skin
    rigger.register()
    rig=rigs[0]
    inferred=guess_limbs(rig)
    report['rigger']['guessedLimbs']=[{'kind':x[0],'side':x[1],'bones':x[3]} for x in inferred]
    report['rigger']['inferredCount']=len(inferred)
    # Real-body marker placement: derive landmark centres from the actual canonical armature.
    from rigger.retarget import classify_armature
    roles=classify_armature(rig)
    semantic={'chin':('head',''),'neck':('neck',''),'shoulder':('upper_arm','L'),
        'wrist':('hand','L'),'pelvis':('hips',''),'ankle':('foot','L')}
    chosen={}
    for marker,(role,side) in semantic.items():
        names=roles.get((role,side,None),[])
        if len(names)!=1:continue
        bone=rig.data.bones[names[0]]
        point=rig.matrix_world @ bone.head_local
        markers.set_marker(bpy.context,marker,point)
        chosen[marker]={'bone':names[0],'world':[float(c) for c in point]}
    report['rigger']['markers']=chosen
    if len(chosen)!=6:raise ValueError('Not all 6 Rigger markers inferred from canonical skeleton')
    # A separate copy of the real imported mesh, not a synthetic Rigger test.
    selected=[o for o in meshes if len(o.data.vertices)>100]
    for o in bpy.context.selected_objects:o.select_set(False)
    for o in selected:o.select_set(True)
    bpy.context.view_layer.objects.active=selected[0]
    result=bpy.ops.rigger.fit_markers(fingers=False,face=False)
    reference=bpy.context.object
    if result!={'FINISHED'} or reference.type!='ARMATURE':raise RuntimeError('Rigger fitting operator did not produce armature')
    report['rigger']['fitResult']=list(result)
    report['rigger']['referenceBones']=len(reference.data.bones)
    # Measure fitted elbow/knee vs actual original-joint landmarks (same world coordinate system).
    comparison={}
    for side in ('L','R'):
        for fitted,role in [('forearm','forearm'),('shin','shin')]:
            b=reference.data.bones.get(fitted+'.'+side)
            source=roles.get((role,side,None),[])
            if b and len(source)==1:
                pos=reference.matrix_world @ b.head_local
                actual=rig.matrix_world @ rig.data.bones[source[0]].head_local
                comparison[fitted+'.'+side]=(pos-actual).length
    report['rigger']['jointDistancesMeters']=comparison
    report['qualification']['riggerFitting']=bool(comparison and all(math.isfinite(v) for v in comparison.values()))
    # Test actual Rigger proximity weights on a DUPLICATE of a real mesh, with a separate rig.
    source=max(selected,key=lambda o:len(o.data.vertices))
    clone=source.copy();clone.data=source.data.copy()
    bpy.context.scene.collection.objects.link(clone)
    clone.name='RD_Rigger_Weight_Copy'
    clone.parent=None
    clone.matrix_world=source.matrix_world.copy()
    for modifier in list(clone.modifiers):clone.modifiers.remove(modifier)
    for vg in list(clone.vertex_groups):clone.vertex_groups.remove(vg)
    affected=skin.apply_proximity(clone,reference,influences=4)
    after=snapshot_weights([clone])[clone.name]
    report['rigger']['weightCopy']={'source':source.name,'affected':affected,**after}
    report['qualification']['riggerWeights']=bool(affected==len(clone.data.vertices) and after['unweighted']==0 and after['maxSumError']<.02)
    # Export strictly separate GLB for visual offline inspection.
    for o in bpy.context.selected_objects:o.select_set(False)
    clone.select_set(True);reference.select_set(True)
    bpy.context.view_layer.objects.active=reference
    target=out/'copies/rigger-real-body-proximity.glb'
    target.parent.mkdir(exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',use_selection=True)
    report['rigger']['copyExport']=str(target.relative_to(out))
    report['rigger']['copyBytes']=target.stat().st_size
except Exception as e:
    record_error('rigger',e)

(out/'ara-rigger-real-body.json').write_text(json.dumps(report,indent=2,default=str)+'\n')
print(json.dumps({'ara':report['ara'].get('status',report['ara'].get('error')),
   'riggerFit':report['qualification']['riggerFitting'],
   'riggerWeights':report['qualification']['riggerWeights'],
   'report':'ara-rigger-real-body.json'}))
# Diagnostic success is not artistic approval: failures remain explicit in report.
