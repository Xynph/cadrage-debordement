"""Run inside Blender; original baseline is read-only, exports go to report/copies."""
import bpy,sys,json,traceback
from pathlib import Path
root=Path.cwd();out=root/'rd-report';out.mkdir(exist_ok=True)
result={'blender':bpy.app.version_string,'background':bpy.app.background,'roundtrips':[]}
try:
    sys.path.insert(0,str(root/'rd-work/rigger'))
    import rigger
    rigger.register();result['riggerRegistration']='PASS'
except Exception:
    result['riggerRegistration']='FAIL';result['riggerError']=traceback.format_exc()
for lod in range(3):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    file=root/f'baseline/dist/match3d/assets/rugby-v24/lod/base_body_anim-lod{lod}.glb'
    bpy.ops.import_scene.gltf(filepath=str(file))
    rigs=[o for o in bpy.data.objects if o.type=='ARMATURE']
    before={'joints':[b.name for b in rigs[0].data.bones],'meshes':sum(o.type=='MESH' for o in bpy.data.objects)}
    target=out/f'copies/body-lod{lod}-blender.glb';target.parent.mkdir(exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(target))
    after=[o for o in bpy.data.objects if o.type=='ARMATURE']
    entry={'lod':lod,'source':str(file),'export':str(target),'before':before,'afterJoints':[b.name for b in after[0].data.bones]}
    entry['sameJointNames']=set(entry['afterJoints'])==set(before['joints'])
    result['roundtrips'].append(entry)
(out/'blender.json').write_text(json.dumps(result,indent=2)+'\n')
assert all(len(x['before']['joints'])==53 and x['sameJointNames'] for x in result['roundtrips'])
