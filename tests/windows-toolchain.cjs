'use strict';
// Fast unit fixtures only: no Windows binary is downloaded or executed here.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {spawnSync}=require('node:child_process'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
test('Windows toolchain rejects altered downloads, hostile archives and false build provenance',()=>{
 assert.ok(fs.existsSync(path.join(root,'ci/prepare-windows-toolchain.py')),'Verified Windows toolchain bootstrap must exist');
 const script=String.raw`
import hashlib, importlib.util, io, json, os, pathlib, stat, subprocess, sys, tempfile, unittest, zipfile
from unittest.mock import patch
ROOT=pathlib.Path(sys.argv[1])
def module(name,file):
 spec=importlib.util.spec_from_file_location(name,ROOT/file); m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
p=module('prepare','ci/prepare-windows-toolchain.py')
b=module('builder','scripts/build-godot-prototype.py')
class Toolchain(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=pathlib.Path(self.temp.name)
 def specification(self,data):
  return {'url':'https://example.invalid/pinned','bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
 def zip(self,entries):
  archive=self.root/'input.zip'
  with zipfile.ZipFile(archive,'w') as out:
   for name,data in entries:
    out.writestr(name,data)
  return archive
 def test_verified_download_is_published_only_after_length_and_hash_match(self):
  data=b'unit fixture, not an executable';spec=self.specification(data);target=self.root/'tool'
  p.download_verified(spec,target,opener=lambda *a,**k:io.BytesIO(data))
  self.assertEqual(target.read_bytes(),data)
  for bad in [{**spec,'sha256':'0'*64},{**spec,'bytes':len(data)-1},{**spec,'sha512':'0'*128}]:
   other=self.root/'refused'
   with self.assertRaises(ValueError):p.download_verified(bad,other,opener=lambda *a,**k:io.BytesIO(data))
   self.assertFalse(other.exists());self.assertFalse(list(self.root.glob('*.part')))
 def test_failed_download_does_not_delete_an_existing_partial_file(self):
  data=b'unit fixture';partial=self.root/'tool.part';partial.write_bytes(b'previous operator data')
  spec={**self.specification(data),'sha256':'0'*64}
  with self.assertRaises(ValueError):p.download_verified(spec,self.root/'tool',opener=lambda *a,**k:io.BytesIO(data))
  self.assertEqual(partial.read_bytes(),b'previous operator data')
 def test_zip_extracts_only_the_requested_members(self):
  archive=self.zip([('templates/windows_release_x86_64.exe',b'fixture'),('templates/unused.exe',b'not selected')])
  dest=self.root/'sdk';p.extract_zip_members(archive,dest,{'templates/windows_release_x86_64.exe':'release.exe'})
  self.assertEqual((dest/'release.exe').read_bytes(),b'fixture');self.assertEqual(list(dest.iterdir()),[dest/'release.exe'])
 def test_zip_rejects_unsafe_unselected_entries_before_any_extraction(self):
  for name in ['../escape','C:/escape','/escape','folder/../escape','folder\\..\\escape','CON.txt','a:b','trailing.']:
   archive=self.zip([('good.exe',b'fixture'),(name,b'hostile')]);dest=self.root/'refused'
   with self.subTest(name=name),self.assertRaises(ValueError):p.extract_zip_members(archive,dest,{'good.exe':'good.exe'})
   self.assertFalse(dest.exists())
 def test_zip_rejects_windows_duplicate_names_links_and_missing_members(self):
  archive=self.zip([('a.exe',b'a'),('A.EXE',b'b')])
  with self.assertRaises(ValueError):p.extract_zip_members(archive,self.root/'dupes',{'a.exe':'a.exe'})
  symlink=zipfile.ZipInfo('link');symlink.create_system=3;symlink.external_attr=(stat.S_IFLNK|0o777)<<16
  archive=self.zip([(symlink,b'outside')])
  with self.assertRaises(ValueError):p.extract_zip_members(archive,self.root/'links',{})
  archive=self.zip([('different',b'fixture')])
  with self.assertRaises(ValueError):p.extract_zip_members(archive,self.root/'missing',{'wanted':'wanted'})
 def test_7zip_listing_rejects_links_and_windows_aliases(self):
  text='Path = x64/opengl32.dll\nSize = 12\nAttributes = A\n\nPath = licenses/Mesa.txt\nSize = 300\nAttributes = A\n'
  self.assertEqual([r['path'] for r in p.parse_sevenzip_listing(text)],['x64/opengl32.dll','licenses/Mesa.txt'])
  for bad in [text+'\nPath = X64/OPENGL32.DLL\nSize = 1\n',text+'\nPath = ../escape\nSize = 1\n',text+'\nPath = link\nSize = 1\nSymbolic Link = outside\n',text+'\nPath = link\nSize = 1\nMode = lrwxrwxrwx\n',text+'\nPath = removed\nSize = 0\nAnti = +\n']:
   with self.assertRaises(ValueError):p.parse_sevenzip_listing(bad)
 def test_node_notices_must_match_the_pinned_runtime_and_version(self):
  notices=self.root/'notices';notices.mkdir();runtime_sha='a'*64
  (notices/'Node-v22.23.4-LICENSE.txt').write_text('Official fixture notice')
  sums=notices/'Node-v22.23.4-SHASUMS256.txt';sums.write_text(runtime_sha+'  win-x64/node.exe\n')
  p.verify_node_notice_set(notices,'22.23.4',runtime_sha)
  sums.write_text('b'*64+'  win-x64/node.exe\n')
  with self.assertRaises(ValueError):p.verify_node_notice_set(notices,'22.23.4',runtime_sha)
  with self.assertRaises(ValueError):p.verify_node_notice_set(notices,'22.99.0',runtime_sha)
 def test_mesa_requires_component_notices_not_only_the_packager_license(self):
  mesa=self.root/'mesa';mesa.mkdir();(mesa/'LICENSE.txt').write_text('MIT License Copyright pal1000 Permission is hereby granted '+('wrapper '*30))
  with self.assertRaises(ValueError):p.inspect_mesa_notices(mesa)
  (mesa/'Mesa-COPYING.txt').write_text('Mesa 3-D graphics library\nPermission is hereby granted '+('license '*30))
  (mesa/'LLVM-LICENSE.txt').write_text('LLVM Apache License v2.0 with LLVM Exceptions\n'+('license '*30))
  rows=p.inspect_mesa_notices(mesa);self.assertTrue(any('Mesa' in r['path'] for r in rows));self.assertTrue(all(len(r['sha256'])==64 for r in rows))
 def test_mesa_receipt_declares_only_verified_x64_dlls_and_component_notices(self):
  mesa=self.root/'mesa';(mesa/'x64').mkdir(parents=True)
  (mesa/'x64/opengl32.dll').write_bytes(b'unit OpenGL fixture');(mesa/'x64/libgallium_wgl.dll').write_bytes(b'unit gallium fixture')
  (mesa/'x64/readme.txt').write_text('not a DLL');(mesa/'Mesa-COPYING.txt').write_text('Mesa 3-D graphics library Permission is hereby granted '+('license '*30));(mesa/'LLVM-LICENSE.txt').write_text('LLVM Apache License with LLVM Exceptions '+('license '*30))
  report=p.write_mesa_receipt(mesa,'26.2.6',{'url':'https://example.invalid/mesa.7z','sha256':'c'*64,'bytes':100})
  self.assertEqual(set(report['files']),{'x64/opengl32.dll','x64/libgallium_wgl.dll'});self.assertTrue(report['qaOnly']);self.assertEqual(len(report['licenses']),2)
  self.assertEqual(json.loads((mesa/'mesa-receipt.json').read_text()),report)
  (mesa/'x64/libgallium_wgl.dll').unlink()
  with self.assertRaises(ValueError):p.write_mesa_receipt(mesa,'26.2.6',{'url':'https://example.invalid/mesa.7z','sha256':'c'*64,'bytes':100})
 def test_prepare_assembles_verified_tools_and_mesa_receipts_without_external_network(self):
  payloads={}
  def pin(label,data):
   spec={**self.specification(data),'url':'https://example.invalid/'+label};payloads[spec['url']]=data;return spec
  def zipped(entries):
   value=io.BytesIO()
   with zipfile.ZipFile(value,'w') as archive:
    for name,data in entries:archive.writestr(name,data)
   return value.getvalue()
  editor=pin('editor.zip',zipped([('Godot_v4.7.2-stable_win64.exe',b'unit editor'),('Godot_v4.7.2-stable_win64_console.exe',b'unit wrapper')]))
  templates=pin('templates.tpz',zipped([('templates/windows_release_x86_64.exe',b'unit template'),('templates/other.exe',b'not extracted')]))
  for spec in [editor,templates]:spec['sha512']=hashlib.sha512(payloads[spec['url']]).hexdigest()
  official=''.join(spec['sha512']+'  '+spec['url'].split('/')[-1]+'\n' for spec in [editor,templates]).encode()
  runtime=pin('node.exe',b'unit runtime fixture')
  def notice(label,data,destination):return {**pin(label,data),'destination':destination}
  config={'schemaVersion':1,'godot':{'version':'4.7.2-stable','editor':editor,'templates':templates,'checksumManifest':notice('sums.txt',official,'licenses/Godot-SUMS.txt'),'notices':[notice('godot-license',b'unit MIT notice','licenses/Godot-LICENSE.txt')]},'node':{'version':'22.23.4','runtime':runtime,'notices':[notice('node-license',b'unit Node notice','licenses/Node-v22.23.4-LICENSE.txt'),notice('node-sums',(runtime['sha256']+'  win-x64/node.exe\n').encode(),'licenses/Node-v22.23.4-SHASUMS256.txt')]},'mesaQaOnly':{'version':'26.2.6','archive':pin('mesa.7z',b'unit sevenzip transport fixture'),'notices':[],'documentation':notice('mesa-readme',b'unit readme','qa-notices/readme.md')}}
  config_path=self.root/'config.json';config_path.write_text(json.dumps(config));tools=self.root/'tools'
  def extraction(archive,destination,executable):
   (destination/'x64').mkdir(parents=True)
   for name in ['opengl32.dll','libgallium_wgl.dll']:(destination/'x64'/name).write_bytes(b'unit DLL fixture')
   (destination/'Mesa-COPYING.txt').write_text('Mesa Permission is hereby granted '+('license '*30));(destination/'LLVM-LICENSE.txt').write_text('LLVM Apache License with LLVM Exceptions '+('license '*30))
  with patch.object(p,'find_sevenzip',return_value=pathlib.Path(sys.executable)),patch.object(p,'extract_sevenzip',side_effect=extraction):
   report=p.prepare(tools,config_path,opener=lambda request,**kwargs:io.BytesIO(payloads[request.full_url]))
  self.assertEqual(report['sdkRoot'],str(tools/'sdk'));self.assertEqual(report['nodeExe'],str(tools/'runtime/node.exe'));self.assertEqual(report['nodeNotices'],str(tools/'sdk/licenses'));self.assertEqual(report['mesaRoot'],str(tools/'mesa'))
  self.assertEqual((tools/'sdk/templates/4.7.2-stable/windows_release_x86_64.exe').read_bytes(),b'unit template');self.assertFalse(list((tools/'sdk').rglob('other.exe')))
  self.assertEqual(json.loads((tools/'toolchain-receipt.json').read_text()),report);self.assertTrue((tools/'mesa/mesa-receipt.json').is_file());self.assertTrue(report['notices'])
  with self.assertRaises(ValueError):p.prepare(tools,config_path)
 def test_wrong_source_commit_or_dirty_tree_is_refused(self):
  with patch.object(b.subprocess,'check_output',side_effect=['a'*40+'\n','b'*40+'\n','','']):
   self.assertEqual(b.source_provenance('a'*40,self.root),{'sourceCommit':'a'*40,'sourceTree':'b'*40})
  for requested,answers in [('c'*40,['a'*40+'\n','b'*40+'\n','','']),('a'*40,['a'*40+'\n','b'*40+'\n',' M tracked.py\n',''])]:
   with patch.object(b.subprocess,'check_output',side_effect=answers),self.assertRaises(ValueError):b.source_provenance(requested,self.root)
  with self.assertRaises(ValueError):b.source_provenance('main',self.root)
  with patch.object(b.subprocess,'check_output',side_effect=['a'*40+'\n','b'*40+'\n','','native/godot/private.png\n']),self.assertRaises(ValueError):b.source_provenance('a'*40,self.root)
 def test_manifest_preserves_file_schema_and_links_exact_source(self):
  app=self.root/'app';(app/'runtime').mkdir(parents=True);(app/'runtime/node.exe').write_bytes(b'unit node fixture');(app/'OvalLegacy27.exe').write_bytes(b'unit exe fixture')
  result=b.write_build_manifest(app,{'sourceCommit':'a'*40,'sourceTree':'b'*40},'unit-database',12,['legacy'])
  self.assertEqual(result['sourceCommit'],'a'*40);self.assertEqual(result['sourceTree'],'b'*40)
  self.assertEqual(result['files']['runtime/node.exe'],{'sha256':hashlib.sha256(b'unit node fixture').hexdigest(),'bytes':17})
  self.assertNotIn('manifest-build.json',result['files']);self.assertEqual(json.loads((app/'manifest-build.json').read_text()),result)
unittest.main(argv=['windows-toolchain-unit'],verbosity=2)
`;
 const result=spawnSync(process.env.PYTHON||(process.platform==='win32'?'python':'python3'),['-c',script,root],{cwd:root,encoding:'utf8',timeout:30000,maxBuffer:1024*1024});
 assert.ifError(result.error);assert.equal(result.status,0,(result.stdout||'')+(result.stderr||''));
 console.log((result.stdout||'')+(result.stderr||''));
});
