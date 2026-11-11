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
  package=self.root/'official-build/OvalLegacy27-PrototypeGodot-Windows-x64.zip'
  self.put('evidence/windows-report.json',json.dumps({'passed':True,'package':{'path':str(package)}}))
  actual=self.root/'evidence/Relocated QA with spaces/OvalLegacy27-PrototypeGodot/OvalLegacy27.exe'
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
unittest.main()
`;
 const r=spawnSync(process.env.PYTHON||(process.platform==='win32'?'python':'python3'),['-c',script],{cwd:path.resolve(__dirname,'..'),encoding:'utf8',timeout:30000});
 assert.equal(r.status,0,(r.stdout||'')+(r.stderr||''));
});
