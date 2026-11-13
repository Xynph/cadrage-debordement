'use strict';
// Real small proof archives and mocked GitHub transport. Never native Windows proof.
const {test}=require('node:test'), assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process'), path=require('node:path');
test('draft publication excludes profiles and refuses an unreceived game ZIP',()=>{
 const script=String.raw`
import importlib.util,json,pathlib,tempfile,unittest,zipfile
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('publish',pathlib.Path('ci/publish-windows-release.py'))
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
class Publication(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=pathlib.Path(self.tmp.name)
  self.source='a'*40
 def put(self,name,data):
  dest=self.root/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(data);return dest
 def complete_evidence(self):
  # Small transport fixtures only; the native verifier is exercised separately.
  capture=self.root/'evidence/resume/01-reception.png'
  fresh={'passed':True,'mode':'fresh'}
  resume={'passed':True,'mode':'resume','graphics':{'captures':[{'path':str(capture)}]}}
  process={'fresh':{'pid':10},'resume':{'pid':20}}
  report={'passed':True,'fresh':fresh,'resume':resume,'process':process}
  required=('controller-unit.log','prepare.log','build.log','official-build/build/import.log',
   'official-build/build/export.log','evidence/archive.json','evidence/mesa-qa.json',
   'evidence/qa-extras.json','evidence/manifest-before.json','evidence/manifest-after.json',
   'official-build/RugbyLegacy27-PrototypeGodot/manifest-build.json','tools/toolchain-receipt.json',
   'tools/mesa/mesa-receipt.json','tools/mesa/notices/Mesa.txt')
  for name in required:self.put(name,'{}')
  self.put('tools/mesa/mesa-receipt.json',json.dumps({'licenses':[{'path':'notices/Mesa.txt'}]}))
  self.put('evidence/windows-report.json',json.dumps(report))
  for mode,qa in [('fresh',fresh),('resume',resume)]:
   self.put('evidence/'+mode+'/report.json',json.dumps(qa))
   self.put('evidence/'+mode+'/process.json',json.dumps(process[mode]))
   self.put('evidence/'+mode+'/loaded-modules.json','{"modules":[],"error":null}')
   self.put('evidence/'+mode+'/stdout.log','actual captured output')
   self.put('evidence/'+mode+'/stderr.log','')
  self.put('evidence/resume/01-reception.png','unit capture bytes, not native Windows proof')
  return report
 def test_actual_bundle_keeps_logs_and_excludes_profiles_runtime_and_tokens(self):
  self.put('prepare.log','preparation failed explicitly')
  self.put('evidence/resume/report.json','{"passed":false}')
  self.put('evidence/private-profiles/PrototypeGodot/donnees.json','PRIVATE CAREER')
  self.put('evidence/Relocated QA with spaces/game/runtime/node.exe','DO NOT PUBLISH QA COPY')
  self.put('tools/downloads/node.exe','DO NOT PUBLISH SDK')
  self.put('credentials','DO NOT PUBLISH TOKEN')
  bundle=self.root/'proofs.zip';p.create_bundle(self.root,bundle,{'passed':False})
  with zipfile.ZipFile(bundle) as archive:
   self.assertEqual(set(archive.namelist()),{'delivery.json','prepare.log','resume/report.json'})
   self.assertNotIn(b'PRIVATE',b''.join(archive.read(n) for n in archive.namelist()))
 def test_symlink_cannot_smuggle_a_file_into_proofs(self):
  external=self.root.parent/(self.root.name+'-external');external.write_text('PRIVATE')
  self.addCleanup(external.unlink)
  try:(self.root/'prepare.log').symlink_to(external)
  except OSError:self.skipTest('Host does not permit symlink creation')
  with self.assertRaises(ValueError):p.evidence_files(self.root)
 def test_empty_or_existing_bundle_refused(self):
  with self.assertRaises(ValueError):p.create_bundle(self.root,self.root/'out.zip',{})
  self.put('prepare.log','actual log');dest=self.put('out.zip','previous proof')
  with self.assertRaises(ValueError):p.create_bundle(self.root,dest,{})
  self.assertEqual(dest.read_text(),'previous proof')
 def test_failed_receipt_never_publishes_received_zip(self):
  self.put('evidence/windows-report.json','{"passed":false}')
  with self.assertRaises(ValueError):p.received_report(self.root,self.source)
 def test_publication_revalidates_the_extracted_exe_that_actually_ran(self):
  package=self.root/'official-build/RugbyLegacy27-PrototypeGodot-Windows-x64.zip'
  self.put('evidence/windows-report.json',json.dumps({'passed':True,'package':{'path':str(package)}}))
  actual=self.root/'evidence/Relocated QA with spaces/RugbyLegacy27-PrototypeGodot/RugbyLegacy27.exe'
  module=p.verifier()
  with patch.object(module,'validate_windows_report') as validate,patch.object(p,'verifier',return_value=module):
   p.received_report(self.root,self.source)
   validate.assert_called_once()
   self.assertEqual(pathlib.Path(validate.call_args.args[2]),actual)
 def test_diagnostic_draft_uploads_proofs_without_game_zip(self):
  self.put('prepare.log','actual failure log');calls=[]
  def github(*args):
   calls.append(args)
   if args[:2]==('release','view'):
    return json.dumps({'url':'https://github.com/unit/test/releases/draft','isDraft':True,'assets':[{'name':n} for n in ['windows-diagnostic-'+self.source[:12]+'-123-1-proofs.zip','delivery.json','SHA256SUMS.txt']]})
   return ''
  with patch.object(p.subprocess,'check_output',return_value=self.source),patch.object(p,'gh',side_effect=github):
   result=p.publish(self.root,self.source,'unit/test','123','1',True)
  create,upload,view=calls
  self.assertIn('--draft',create);self.assertIn('--target',create);self.assertIn(self.source,create)
  self.assertFalse(result['passed']);self.assertFalse(any('Windows-x64.zip' in value for value in upload))
  with zipfile.ZipFile(next(self.root.glob('*proofs.zip'))) as archive:
   self.assertFalse(json.loads(archive.read('delivery.json'))['passed'])
 def test_wrong_checkout_or_invalid_source_refused_before_github_mutation(self):
  self.put('prepare.log','actual failure log')
  with patch.object(p.subprocess,'check_output',return_value='b'*40),patch.object(p,'gh') as github:
   with self.assertRaises(ValueError):p.publish(self.root,self.source,'unit/test','123','1',True)
   github.assert_not_called()
 def test_bundle_preserves_each_explicit_graphics_mode_without_private_files(self):
  expected={'delivery.json'}
  for mode in ('fresh','resume','angle-clean','mesa-native','mesa-local'):
   for name in ('report.json','process.json','loaded-modules.json','graphics-progress.json','driver-ack.json','stdout.log','stderr.log'):
    self.put('evidence/'+mode+'/'+name,'{}');expected.add(mode+'/'+name)
   self.put('evidence/'+mode+'/capture.png','rendered bytes');expected.add(mode+'/captures/capture.png')
   for name in ('private-profiles/donnees.json','runtime/node.exe','sdk/tool.exe','secret','nested/private.png'):
    self.put('evidence/'+mode+'/'+name,'PRIVATE')
  self.put('evidence/unapproved/report.json','PRIVATE')
  bundle=self.root/'proofs.zip';p.create_bundle(self.root,bundle,{'passed':False})
  with zipfile.ZipFile(bundle) as archive:
   self.assertEqual(set(archive.namelist()),expected)
   self.assertNotIn(b'PRIVATE',b''.join(archive.read(n) for n in archive.namelist()))
 def test_received_bundle_refuses_each_missing_critical_report_log_or_notice(self):
  self.complete_evidence()
  missing=('controller-unit.log','prepare.log','build.log','official-build/build/import.log',
   'official-build/build/export.log','evidence/windows-report.json','evidence/archive.json',
   'evidence/mesa-qa.json','evidence/qa-extras.json','evidence/manifest-before.json',
   'evidence/manifest-after.json','official-build/RugbyLegacy27-PrototypeGodot/manifest-build.json',
   'tools/toolchain-receipt.json','tools/mesa/mesa-receipt.json','tools/mesa/notices/Mesa.txt',
   'evidence/fresh/report.json','evidence/fresh/process.json','evidence/fresh/loaded-modules.json',
   'evidence/fresh/stdout.log','evidence/fresh/stderr.log','evidence/resume/report.json',
   'evidence/resume/process.json','evidence/resume/loaded-modules.json','evidence/resume/stdout.log',
   'evidence/resume/stderr.log')
  for index,name in enumerate(missing):
   with self.subTest(missing=name):
    file=self.root/name;content=file.read_bytes();file.unlink()
    try:
     with self.assertRaisesRegex(ValueError,'Missing received evidence'):
      p.create_bundle(self.root,self.root/('missing-'+str(index)+'.zip'),{'passed':True})
    finally:file.write_bytes(content)
 def test_received_bundle_requires_the_declared_capture_in_its_mode_directory(self):
  report=self.complete_evidence();capture=self.root/'evidence/resume/01-reception.png'
  capture.unlink()
  self.put('evidence/resume/unrelated.png','other rendered bytes')
  with self.subTest(capture='missing'):
   with self.assertRaisesRegex(ValueError,'capture'):
    p.create_bundle(self.root,self.root/'missing-capture.zip',{'passed':True})
  outside=self.put('evidence/private-profiles/01-reception.png','PRIVATE')
  report['resume']['graphics']['captures'][0]['path']=str(outside)
  self.put('evidence/windows-report.json',json.dumps(report))
  self.put('evidence/resume/report.json',json.dumps(report['resume']))
  with self.subTest(capture='private profile'):
   with self.assertRaisesRegex(ValueError,'capture'):
    p.create_bundle(self.root,self.root/'private-capture.zip',{'passed':True})
 def test_received_bundle_keeps_complete_evidence_and_empty_stderr(self):
  self.complete_evidence();bundle=self.root/'received.zip'
  p.create_bundle(self.root,bundle,{'passed':True})
  with zipfile.ZipFile(bundle) as archive:
   self.assertEqual(archive.read('resume/stderr.log'),b'')
   self.assertEqual(archive.read('resume/captures/01-reception.png'),b'unit capture bytes, not native Windows proof')
   self.assertIn('tools/mesa-notices/notices/Mesa.txt',archive.namelist())
 def test_received_bundle_refuses_detached_or_changed_mode_proofs(self):
  self.complete_evidence()
  for index,name in enumerate(('evidence/fresh/report.json','evidence/resume/report.json',
   'evidence/fresh/process.json','evidence/resume/process.json')):
   with self.subTest(changed=name):
    file=self.root/name;content=file.read_bytes();file.write_text('{"different":true}')
    try:
     with self.assertRaisesRegex(ValueError,'differs from receipt'):
      p.create_bundle(self.root,self.root/('changed-'+str(index)+'.zip'),{'passed':True})
    finally:file.write_bytes(content)
 def test_graphics_smoke_or_failed_report_cannot_create_a_received_bundle(self):
  report=self.complete_evidence()
  for index,change in enumerate(({'scope':'graphics-smoke-only'},{'passed':False})):
   with self.subTest(report=change):
    candidate={**report,**change};self.put('evidence/windows-report.json',json.dumps(candidate))
    with self.assertRaisesRegex(ValueError,'full Windows receipt'):
     p.create_bundle(self.root,self.root/('scope-'+str(index)+'.zip'),{'passed':True})
 def test_partial_graphics_progress_is_preserved_without_a_received_verdict(self):
  events=[{'stage':'scene.load.begin','frames_drawn':0,'process_frames':0}]
  self.put('evidence/angle-clean/graphics-progress.json',json.dumps(events))
  ack={'mode':'graphics-smoke','script_path':'res://qa.gd','pid':10,'executable':'unit.exe','data_dir':'external'}
  self.put('evidence/angle-clean/driver-ack.json',json.dumps(ack))
  bundle=self.root/'progress-diagnostic.zip';p.create_bundle(self.root,bundle,{'passed':False})
  with zipfile.ZipFile(bundle) as archive:
   self.assertEqual(set(archive.namelist()),{'delivery.json','angle-clean/graphics-progress.json','angle-clean/driver-ack.json'})
   self.assertEqual(json.loads(archive.read('angle-clean/graphics-progress.json')),events)
   self.assertEqual(json.loads(archive.read('angle-clean/driver-ack.json')),ack)
   self.assertFalse(json.loads(archive.read('delivery.json'))['passed'])
  with self.assertRaisesRegex(ValueError,'Missing received evidence'):
   p.create_bundle(self.root,self.root/'progress-received.zip',{'passed':True})
 def test_clean_angle_keeps_preparation_notices_without_inventing_mesa_staging(self):
  report=self.complete_evidence();(self.root/'evidence/mesa-qa.json').unlink()
  report['selectedGraphicsDriver']='opengl3_angle'
  report['qaExtras']={'override.cfg':{'source':'QA launch configuration'}}
  self.put('evidence/windows-report.json',json.dumps(report))
  bundle=self.root/'angle-received.zip';p.create_bundle(self.root,bundle,{'passed':True})
  with zipfile.ZipFile(bundle) as archive:
   self.assertNotIn('mesa-qa.json',archive.namelist())
   self.assertNotIn('mesa',json.loads(archive.read('windows-report.json')))
   self.assertIn('tools/mesa-receipt.json',archive.namelist())
   self.assertIn('tools/mesa-notices/notices/Mesa.txt',archive.namelist())
 def test_angle_with_declared_mesa_staging_still_requires_its_actual_receipt(self):
  report=self.complete_evidence();(self.root/'evidence/mesa-qa.json').unlink()
  report['selectedGraphicsDriver']='opengl3_angle'
  for index,staging in enumerate(({'mesa':{'receipt':{'qaOnly':True}}},
   {'qaExtras':{'opengl32.dll':{'source':'x64/opengl32.dll'}}})):
   with self.subTest(staging=staging):
    self.put('evidence/windows-report.json',json.dumps({**report,**staging}))
    with self.assertRaisesRegex(ValueError,'Missing received evidence: mesa-qa.json'):
     p.create_bundle(self.root,self.root/('staged-angle-'+str(index)+'.zip'),{'passed':True})
 def test_declared_driver_ack_requires_its_exact_durable_copy(self):
  report=self.complete_evidence()
  ack={'schema':'oval-windows-driver-v1','mode':'resume','script_chain':['res://windows_qa/windows-resume.gd'],
   'entry_scene':'res://windows_qa/entry.tscn','pid':20,'executable':'unit.exe','data_dir':'external','exported':True}
  report['resume']['driver_ack']=ack;report['process']['resume']['driverAck']=ack
  self.put('evidence/windows-report.json',json.dumps(report))
  self.put('evidence/resume/report.json',json.dumps(report['resume']))
  self.put('evidence/resume/process.json',json.dumps(report['process']['resume']))
  with self.subTest(ack='missing'):
   with self.assertRaisesRegex(ValueError,'Missing received evidence: resume/driver-ack.json'):
    p.create_bundle(self.root,self.root/'missing-ack.zip',{'passed':True})
  self.put('evidence/resume/driver-ack.json',json.dumps({**ack,'pid':99}))
  with self.subTest(ack='changed'):
   with self.assertRaisesRegex(ValueError,'driver-ack.json differs from receipt'):
    p.create_bundle(self.root,self.root/'changed-ack.zip',{'passed':True})
  self.put('evidence/resume/driver-ack.json',json.dumps(ack))
  bundle=self.root/'matching-ack.zip';p.create_bundle(self.root,bundle,{'passed':True})
  with zipfile.ZipFile(bundle) as archive:
   self.assertEqual(json.loads(archive.read('resume/driver-ack.json')),ack)
 def test_received_publication_uploads_original_report_and_verified_png_bytes_with_sums(self):
  report=self.complete_evidence();module=p.verifier()
  package=self.put('official-build/RugbyLegacy27-PrototypeGodot-Windows-x64.zip','unit game ZIP')
  report.update({'sourceTree':'b'*40,'package':{'path':str(package)}})
  captures=[];originals={}
  for index,name in enumerate(('01 Reception.png','01-Reception.png')):
   capture=self.put('evidence/resume/'+name,'unit PNG bytes '+str(index))
   captures.append({'path':str(capture),'sha256':module.digest(capture)})
   originals['windows-resume-'+str(index+1).zfill(2)+'-01-Reception.png']=capture.read_bytes()
  report['resume']['graphics']['captures']=captures
  source_report=self.put('evidence/windows-report.json',json.dumps(report))
  self.put('evidence/resume/report.json',json.dumps(report['resume']))
  originals['windows-report.json']=source_report.read_bytes();uploaded={}
  def github(*args):
   if args[:2]==('release','upload'):
    for argument in args[3:args.index('--repo')]:
     asset=pathlib.Path(argument);uploaded[asset.name]=asset.read_bytes()
   if args[:2]==('release','view'):
    return json.dumps({'url':'https://github.com/unit/test/releases/draft','isDraft':True,'assets':[{'name':n} for n in uploaded]})
   return ''
  with patch.object(p.subprocess,'check_output',return_value=self.source),patch.object(p,'gh',side_effect=github),patch.object(module,'validate_windows_report'),patch.object(p,'verifier',return_value=module):
   result=p.publish(self.root,self.source,'unit/test','456','1')
  expected={'RugbyLegacy27-PrototypeGodot-Windows-x64.zip','windows-received-aaaaaaaaaaaa-456-1-proofs.zip',
   'delivery.json','SHA256SUMS.txt','windows-report.json','windows-resume-01-01-Reception.png','windows-resume-02-01-Reception.png'}
  self.assertEqual(set(result['assets']),expected);self.assertEqual(set(uploaded),expected)
  for name,content in originals.items():self.assertEqual(uploaded[name],content)
  sums=dict(line.split('  ',1)[::-1] for line in uploaded['SHA256SUMS.txt'].decode('ascii').splitlines())
  self.assertEqual(set(sums),expected-{'SHA256SUMS.txt'})
  import hashlib
  for name,sha in sums.items():self.assertEqual(hashlib.sha256(uploaded[name]).hexdigest(),sha)
  direct={row['name']:row for row in json.loads(uploaded['delivery.json'])['receiptAssets']}
  self.assertEqual(set(direct),set(originals))
  for name,content in originals.items():
   self.assertEqual(direct[name]['sha256'],hashlib.sha256(content).hexdigest())
   self.assertEqual(direct[name]['bytes'],len(content))
 def test_direct_assets_refuse_unselected_outside_or_changed_captures(self):
  report=self.complete_evidence();module=p.verifier()
  source=self.root/'evidence/resume/01-reception.png'
  report['resume']['graphics']['captures'][0]['sha256']=module.digest(source)
  outside=self.put('evidence/private-profiles/hidden.png','PRIVATE')
  external_tmp=tempfile.TemporaryDirectory();self.addCleanup(external_tmp.cleanup)
  external=pathlib.Path(external_tmp.name)/'hidden.png';external.write_bytes(b'PRIVATE EXTERNAL')
  for name,path,sha in (('private profile',outside,module.digest(outside)),
   ('outside root',external,module.digest(external)),
   ('changed',source,'0'*64)):
   with self.subTest(capture=name):
    report['resume']['graphics']['captures']=[{'path':str(path),'sha256':sha}]
    self.put('evidence/windows-report.json',json.dumps(report))
    self.put('evidence/resume/report.json',json.dumps(report['resume']))
    with self.assertRaisesRegex(ValueError,'capture'):
     p.direct_receipt_assets(self.root,report)
  self.assertFalse((self.root/'public-assets').exists())
unittest.main()
`;
 const r=spawnSync(process.env.PYTHON||(process.platform==='win32'?'python':'python3'),['-c',script],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:30000});
 assert.equal(r.status,0,(r.stdout||'')+(r.stderr||''));
});
