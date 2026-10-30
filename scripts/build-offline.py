#!/usr/bin/env python3
"""Préparer l’exécutable autonome Windows à partir du même dossier dist/."""
import argparse, hashlib, json, os, pathlib, shutil, subprocess, zipfile
root=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--go',default='go');p.add_argument('--out',type=pathlib.Path,default=root/'offline/out');p.add_argument('--prepare-only',action='store_true');p.add_argument('--native-test',action='store_true');args=p.parse_args()
out=args.out.resolve();out.mkdir(parents=True,exist_ok=True)
app=root/'offline/launcher/app'
if app.exists():shutil.rmtree(app)
shutil.copytree(root/'dist',app)
shutil.copyfile(root/'offline/offline-bridge.js',app/'offline-bridge.js')
index=(app/'index.html').read_text();marker='<script src="storage.js"></script>'
assert index.count(marker)==1
(app/'index.html').write_text(index.replace(marker,'<script src="offline-bridge.js"></script>'+marker))
# Aucune ressource distante automatiquement chargée dans la version livrée.
for file in app.rglob('*'):
 if file.suffix=='.css':
  text=file.read_text();assert '@import' not in text
  import re
  assert not re.search(r'url\([\s\'\"]*https?://',text)
if args.prepare_only:print('Ressources embarquées préparées.');raise SystemExit
base_env=dict(os.environ,GOTOOLCHAIN='local',GOPROXY='off',GOSUMDB='off',CGO_ENABLED='0')
def go_run(arguments,env=base_env):subprocess.run([args.go,*arguments],cwd=root/'offline',env=env,check=True)
go_run(['test','./launcher'])
exe=out/'CadrageDebordement.exe'
go_run(['build','-trimpath','-buildvcs=false','-ldflags=-s -w -H=windowsgui','-o',str(exe),'./launcher'],dict(base_env,GOOS='windows',GOARCH='amd64'))
if args.native_test:go_run(['build','-trimpath','-buildvcs=false','-o',str(out/'cadrage-test-linux'),'./launcher'],dict(base_env,GOOS='linux',GOARCH='amd64'))
assert exe.read_bytes()[:2]==b'MZ'
archive=out/'CadrageDebordement-Windows-v16.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 z.write(exe,'CadrageDebordement/CadrageDebordement.exe')
 z.write(root/'offline/Go-LICENCE.txt','CadrageDebordement/Licences/Go-LICENCE.txt')
 z.writestr('CadrageDebordement/LIRE-MOI.txt',b'\xef\xbb\xbf'+(root/'offline/LIRE-MOI.txt').read_bytes())
 for license_file in (root/'dist/fonts').glob('*LICENCE.txt'):z.write(license_file,'CadrageDebordement/Licences/'+license_file.name)
manifest={'version':'16.0.0','platform':'windows-amd64','executable_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'archive_bytes':archive.stat().st_size,'assets':{str(f.relative_to(app)):hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(app.rglob('*')) if f.is_file()}}
(out/'verification.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
print(json.dumps({"archive":str(archive),"bytes":archive.stat().st_size,"sha256":manifest['archive_sha256']}))
