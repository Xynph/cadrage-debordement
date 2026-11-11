'use strict';
// These synthetic fixtures exercise validation only. They are never Windows proof.
const test=require('node:test'),assert=require('node:assert/strict'),path=require('node:path');
const {spawnSync}=require('node:child_process');
const python=process.env.PYTHON||(process.platform==='win32'?'python':'python3');
const prelude=String.raw`
import importlib.util, pathlib, tempfile, zipfile, json, hashlib, stat, copy, atexit, shutil
spec=importlib.util.spec_from_file_location('windows_package', ${JSON.stringify(path.resolve(__dirname,'../ci/windows-package.py'))})
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
tmp=pathlib.Path(tempfile.mkdtemp(prefix='windows-package-unit-'))
atexit.register(shutil.rmtree,tmp,ignore_errors=True)
commit='a'*40; tree='b'*40; prefix='OvalLegacy27-PrototypeGodot'
files={'OvalLegacy27.exe':b'MZ-unit-fixture-not-an-executable','runtime/node.exe':b'unit-runtime', 'engine/worker.cjs':b'unit-worker','Licences/notice.txt':b'unit-notice'}
manifest={'sourceCommit':commit,'sourceTree':tree,'files':{p:{'sha256':hashlib.sha256(v).hexdigest(),'bytes':len(v)} for p,v in files.items()}}
def archive(entries=None, doc=None):
    dest=tmp/'fixture.zip'
    with zipfile.ZipFile(dest,'w') as z:
        for name,data in (entries or [(prefix+'/'+p,v) for p,v in files.items()]):z.writestr(name,data)
        z.writestr(prefix+'/manifest-build.json',json.dumps(doc or manifest))
    return dest
def refused(fn, reason=None):
    try:fn()
    except (ValueError, OSError, KeyError) as error:
        if reason:assert reason.lower() in str(error).lower(),str(error)
    else:raise AssertionError('Hostile or partial fixture was accepted')
exe='C:/QA Relocated/game/OvalLegacy27.exe'
qa={'passed':True,'mode':'fresh','checks':50,'failures':[],'native_display':'headless','executable':exe,'data_dir':'C:/QA Evidence/private/PrototypeGodot','season':2,'pid':10,'engine_pid':11,'coach':{'starts':0,'ends':0,'voice_available':False,'player_present':False},'layout':[]}
literal={'id':'unit-question','season':1,'week':1,'club':29,'answerId':'r4','questionText':'Exact unit question?','answerText':'Exact selected unit reply.','journalist':{'id':'unit-journalist','name':'Unit Reporter','outlet':'Unit Paper'}}
qa['coach']['observation']='From QA startup through coach destruction'
qa.update(journey={'day_advances':210,'matches_started':30,'matches_finished':30,'weeks_closed':30,'meeting_commands':20,'interseason_reached':True,'season_two_reached':True},systems={'passed':True},native06={'passed':True},press_literals=[{'expected':copy.deepcopy(literal),'archived':copy.deepcopy(literal)} for _ in range(2)])
def driver_ack(mode):
 chain=['res://windows_qa/windows-resume.gd']
 if mode=='graphics-smoke':chain.insert(0,'res://windows_qa/windows-graphics-smoke.gd')
 return {'schema':'oval-windows-driver-v1','mode':mode,'script_chain':chain,'entry_scene':'res://windows_qa/entry.tscn','pid':10,'executable':exe,'data_dir':qa['data_dir'],'exported':True}
`;
function check(name,body){test(name,()=>{const r=spawnSync(python,['-c',prelude+'\n'+body],{encoding:'utf8',timeout:15000});assert.equal(r.status,0,(r.stdout||'')+(r.stderr||''));});}
check('official manifest maps every archived file and source commit',`r=m.verify_archive(archive(),commit);assert r['manifest']['sourceTree']==tree;assert r['files']==len(files)`);
check('archive refuses QA override even when listed honestly in the manifest',`data=b'[application]\\nrun/main_loop_type="WindowsGraphicsSmoke"\\n';files['override.cfg']=data;manifest['files']['override.cfg']={'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data)};refused(lambda:m.verify_archive(archive(),commit),'override')`);
for(const bad of ['../escape','/absolute','C:/drive','runtime/../escape','runtime\\node.exe','runtime/NUL.txt','runtime/node.exe.','runtime/node.exe:ads']){
 check('archive refuses Windows path '+bad,`refused(lambda:m.verify_archive(archive([(prefix+'/good',b'x'),(${JSON.stringify(bad)},b'x')]),commit))`);
}
check('archive refuses casefold duplicates',`entries=[(prefix+'/'+p,v) for p,v in files.items()]+[(prefix+'/RUNTIME/Node.exe',b'x')];refused(lambda:m.verify_archive(archive(entries),commit),'duplicate')`);
check('archive refuses symbolic links',`z=archive();
with zipfile.ZipFile(z,'a') as out:
 i=zipfile.ZipInfo(prefix+'/link');i.create_system=3;i.external_attr=(stat.S_IFLNK|0o777)<<16;out.writestr(i,'runtime/node.exe')
refused(lambda:m.verify_archive(z,commit),'link')`);
check('archive refuses omitted, extra and SHA-forged files',`for kind in ['missing','extra','sha']:
 entries=[(prefix+'/'+p,v) for p,v in files.items()]
 if kind=='missing':entries.pop()
 if kind=='extra':entries.append((prefix+'/unexpected.dll',b'x'))
 if kind=='sha':entries[0]=(entries[0][0],b'forged')
 refused(lambda:m.verify_archive(archive(entries),commit))`);
check('archive refuses wrong or missing source provenance',`for field in ['sourceCommit','sourceTree']:
 doc=copy.deepcopy(manifest);doc[field]='invalid';refused(lambda:m.verify_archive(archive(doc=doc),commit))
refused(lambda:m.verify_archive(archive(),'c'*40),'source')`);
check('safe extraction and exact tree verification reject modified files',`z=archive();receipt=m.verify_archive(z,commit);root=m.extract_archive(z,tmp/'extracted',commit);m.verify_tree(root,receipt['manifest'],{});(root/'runtime/node.exe').write_bytes(b'changed');refused(lambda:m.verify_tree(root,receipt['manifest'],{}),'sha')`);
check('QA extras require explicit digest and cannot overwrite a manifest file',`r=m.verify_archive(archive(),commit);root=m.extract_archive(tmp/'fixture.zip',tmp/'game',commit);extra=root/'opengl32.dll';extra.write_bytes(b'QA-only');refused(lambda:m.verify_tree(root,r['manifest'],{}));allowed={'opengl32.dll':{'bytes':7,'sha256':hashlib.sha256(b'QA-only').hexdigest()}};m.verify_tree(root,r['manifest'],allowed);refused(lambda:m.verify_tree(root,r['manifest'],{'runtime/node.exe':allowed['opengl32.dll']}),'overwrite')`);
check('fresh QA requires correct executable, successful checks and season two',`m.validate_qa_report(qa,exe,'fresh')
for key,value in [('executable','C:/wrong.exe'),('passed',False),('season',1),('failures',['failed']),('checks',0),('mode','resume')]:
 bad=copy.deepcopy(qa);bad[key]=value;refused(lambda:m.validate_qa_report(bad,exe,'fresh'))`);
check('fresh receipt refuses early season-two success without actual season and literal quote evidence',`for key in ['journey','press_literals','systems','native06']:
 bad=copy.deepcopy(qa);bad.pop(key,None);refused(lambda:m.validate_qa_report(bad,exe,'fresh'))`);
check('literal quote receipt rejects missing words, changed reply and truncated season',`for kind in ['empty','different','count']:
 bad=copy.deepcopy(qa)
 if kind=='empty':bad['press_literals'][0]['expected']['answerText']='';bad['press_literals'][0]['archived']['answerText']=''
 if kind=='different':bad['press_literals'][0]['archived']['answerText']='Catalogue reconstruction'
 if kind=='count':bad['journey']['matches_finished']=1
 refused(lambda:m.validate_qa_report(bad,exe,'fresh'))`);
check('resume cannot substitute fresh or headless for graphical proof',`refused(lambda:m.validate_qa_report(qa,exe,'resume'))
bad=copy.deepcopy(qa);bad['mode']='resume';refused(lambda:m.validate_qa_report(bad,exe,'resume'),'graphics')`);
check('guide audio activity or an allocated voice player invalidates QA',`for key,value in [('starts',1),('ends',1),('voice_available',True),('player_present',True)]:
 bad=copy.deepcopy(qa);bad['coach'][key]=value;refused(lambda:m.validate_qa_report(bad,exe,'fresh'),'audio')`);
check('an early voice snapshot cannot substitute full-lifetime observation',`bad=copy.deepcopy(qa);bad['coach'].pop('observation',None);refused(lambda:m.validate_qa_report(bad,exe,'fresh'),'observation')`);
check('process proof requires the packaged node, hash, parent and clean shutdown',`node='C:/QA Relocated/game/runtime/node.exe';sha='d'*64;p={'executable':exe,'pid':10,'nodeExecutable':node,'nodePid':11,'nodeParentPid':10,'nodeSha256':sha,'exitCode':0,'shutdown':True};m.validate_process(p,exe,node,sha)
for key,value in [('executable','C:/editor.exe'),('nodeExecutable','C:/host/node.exe'),('nodeSha256','e'*64),('nodeParentPid',9),('shutdown',False),('exitCode',1)]:
 bad=copy.deepcopy(p);bad[key]=value;refused(lambda:m.validate_process(bad,exe,node,sha))`);
check('synthetic diagnostics can never be promoted to native Windows receipt',`refused(lambda:m.validate_windows_report({'passed':True,'proof':'diagnostic'},commit,exe,require_native=True))`);
check('Mesa QA copy requires notices, hashes and no game overwrite',`r=m.verify_archive(archive(),commit);root=m.extract_archive(tmp/'fixture.zip',tmp/'game',commit);mesa=tmp/'mesa';(mesa/'x64').mkdir(parents=True);(mesa/'x64/opengl32.dll').write_bytes(b'unit-dll');(mesa/'license.txt').write_bytes(b'unit-notice');rec={'version':'26.2.6','qaOnly':True,'source':{'sha256':'f'*64},'requiredDlls':['x64/opengl32.dll'],'files':{'x64/opengl32.dll':{'sha256':hashlib.sha256(b'unit-dll').hexdigest(),'bytes':8}},'licenses':[{'path':'license.txt','sha256':hashlib.sha256(b'unit-notice').hexdigest(),'bytes':11}]};(mesa/'mesa-receipt.json').write_text(json.dumps(rec));installed=m.install_mesa(mesa,root,r['manifest']);m.verify_tree(root,r['manifest'],installed['extras']);refused(lambda:m.install_mesa(mesa,root,r['manifest']),'overwrite');(root/'opengl32.dll').unlink();rec['licenses']=[];(mesa/'mesa-receipt.json').write_text(json.dumps(rec));refused(lambda:m.install_mesa(mesa,root,r['manifest']),'notices')`);
check('native PNG validation checks actual pixels and dimensions',String.raw`import zlib, struct
def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
def png(width,height,detail):
 rows=b''.join(b'\0'+bytes([(y%255 if detail else 0),40,100])*width for y in range(height))
 return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(rows))+chunk(b'IEND',b'')
p=tmp/'capture.png';p.write_bytes(png(2560,1440,True));assert m.png_proof(p)['variance']>2
p.write_bytes(png(2560,1440,False));refused(lambda:m.png_proof(p),'uniform')
p.write_bytes(png(1280,720,True));refused(lambda:m.png_proof(p),'2560')`);
check('manifest rejects duplicate JSON keys rather than accepting the last value',`z=tmp/'duplicate-json.zip'
with zipfile.ZipFile(z,'w') as out:
 for name,data in files.items():out.writestr(prefix+'/'+name,data)
 raw='{"sourceCommit":"'+'c'*40+'","sourceCommit":"'+commit+'","sourceTree":"'+tree+'","files":'+json.dumps(manifest['files'])+'}'
 out.writestr(prefix+'/manifest-build.json',raw)
refused(lambda:m.verify_archive(z,commit),'duplicate')`);
check('resume distinguishes pure loading from the explicitly declared RNG save probe',`r=copy.deepcopy(qa);r.update(mode='resume',driver_ack=driver_ack('resume'),native_display='Windows',platform='Windows',audio_driver='Dummy',runtime_info={'adapter':'unit-fixture'},graphics={'passed':True,'window':[2560,1440],'captures':[{'path':'diagnostic-only'}]*4},before={'state_matches':True,'citations_match':True,'profile_bytes_match':True,'rng_file_unchanged':True,'press_literals_match':True,'seed_loaded':123},save_probe={'state_matches':True,'rng_matches_loaded':True,'seed_saved':123},first_mutations=[{'command':'save'}]);m.validate_qa_report(r,exe,'resume')
for change in ['seed','undeclared','initial']:
 bad=copy.deepcopy(r)
 if change=='seed':bad['save_probe']['seed_saved']=124
 if change=='undeclared':bad['first_mutations']=[]
 if change=='initial':bad['before']['profile_bytes_match']=False
 refused(lambda:m.validate_qa_report(bad,exe,'resume'))`);
check('short graphics cannot masquerade as full Windows receipt',`refused(lambda:m.validate_windows_report({'passed':True,'scope':'graphics-smoke-only'},commit,exe),'not a full')`);
check('embedded driver ACK binds mode, script inheritance and exact process before acceptance',`ack=driver_ack('resume');m.validate_driver_ack(ack,exe,'resume',10,qa['data_dir'])
for key,value in [('schema','other'),('mode','graphics-smoke'),('script_chain',['C:/external.gd']),('entry_scene','res://main.tscn'),('pid',12),('executable','C:/editor.exe'),('data_dir','C:/wrong'),('exported',False)]:
 bad=copy.deepcopy(ack);bad[key]=value;refused(lambda:m.validate_driver_ack(bad,exe,'resume',10,qa['data_dir']),'ACK')
refused(lambda:m.validate_driver_ack({},exe,'resume',10,qa['data_dir']),'ACK')`);
check('graphics scope requires actual driver, modules and PNG proof without promoting unit fixtures',`from unittest.mock import patch
node='C:/QA Relocated/game/runtime/node.exe';sha=manifest['files']['runtime/node.exe']['sha256'];image={'path':'unit-image','sha256':'e'*64}
r={'mode':'graphics-smoke','scope':'graphics-smoke-only','driver_ack':driver_ack('graphics-smoke'),'data_dir':qa['data_dir'],'passed':True,'exported':True,'checks':10,'failures':[],'platform':'Windows','native_display':'Windows','audio_driver':'Dummy','executable':exe,'pid':10,'engine_pid':11,'coach':{'starts':0,'ends':0,'player_present':False},'runtime_info':{'renderer':'gl_compatibility','adapter':'ANGLE unit adapter','api_version':'OpenGL ES ANGLE unit'},'graphics':{'passed':True,'window':[2560,1440],'captures':[image,image]}}
p={'executable':exe,'pid':10,'driverAck':driver_ack('graphics-smoke'),'nodeExecutable':node,'nodePid':11,'nodeParentPid':10,'nodeSha256':sha,'exeSha256':manifest['files']['OvalLegacy27.exe']['sha256'],'exitCode':0,'shutdown':True,'argv':['--rendering-driver','opengl3_angle'],'loadedModules':[{'name':'d3d11.dll','path':'C:/Windows/System32/d3d11.dll','sha256':'f'*64}]}
with patch.object(m,'png_proof',return_value=image):
 result=m.validate_graphics_probe(copy.deepcopy(r),p,manifest,exe,'opengl3_angle',require_native=False);assert result['proof']=='diagnostic' and result['passed'] is False
 for change in ['headless','driver','modules','pixels','unexpected-angle-fallback','ack']:
  bad=copy.deepcopy(r);proc=copy.deepcopy(p)
  if change=='headless':bad['native_display']='headless'
  if change=='driver':proc['argv']=[]
  if change=='modules':proc['loadedModules']=[]
  if change=='pixels':bad['graphics']['captures'][0]={'path':'changed','sha256':'0'*64}
  if change=='unexpected-angle-fallback':proc['argv']=['--rendering-driver','opengl3']
  if change=='ack':proc['driverAck']['pid']=15
  requested='opengl3' if change=='unexpected-angle-fallback' else 'opengl3_angle'
  refused(lambda:m.validate_graphics_probe(bad,proc,manifest,exe,requested,require_native=False))`);
