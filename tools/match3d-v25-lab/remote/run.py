"""Reproducible remote lab. No writes to game sources, no cloud inference, no secrets in reports."""
import sys,os,subprocess,json,hashlib,shutil,urllib.request,tarfile,zipfile,time,platform
from pathlib import Path

ROOT=Path.cwd();HERE=Path(__file__).resolve().parent
OUT=ROOT/'rd-report';WORK=ROOT/'rd-work';OUT.mkdir(exist_ok=True);WORK.mkdir(exist_ok=True)
LOCK=json.loads((HERE/'lock.json').read_text())

def sha(file):return hashlib.sha256(Path(file).read_bytes()).hexdigest()
def run(name,cmd,cwd=ROOT,timeout=900):
    start=time.monotonic();log=OUT/(name+'.log')
    try:
        with log.open('w') as stream:r=subprocess.run(cmd,cwd=cwd,stdout=stream,stderr=subprocess.STDOUT,timeout=timeout)
        result={'name':name,'command':cmd,'returncode':r.returncode,'status':'PASS' if r.returncode==0 else 'FAIL','seconds':time.monotonic()-start,'log':log.name}
    except Exception as e:result={'name':name,'status':'FAIL','error':str(e),'seconds':time.monotonic()-start,'log':log.name}
    (OUT/(name+'.status.json')).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
    return result['status']=='PASS'

def download(url,dest):
    dest=Path(dest);dest.parent.mkdir(parents=True,exist_ok=True)
    if not dest.exists():
        with urllib.request.urlopen(url,timeout=180) as r,dest.open('wb') as w:shutil.copyfileobj(r,w)
    return {'url':url,'bytes':dest.stat().st_size,'sha256':sha(dest),'file':str(dest)}

def acquire():
    records=[]
    assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT/'baseline',text=True).strip()==LOCK['baseline']
    assets=ROOT/'baseline/dist/match3d/assets';target=WORK/'binary-assets';target.mkdir(exist_ok=True)
    for folder in ['charactercreator-v24','rugby-v24/lod']:
        dest=target/Path(folder).name;dest.mkdir(exist_ok=True)
        for file in (assets/folder).glob('*.glb'):shutil.copy2(file,dest/file.name)
    source_manifest=json.loads((assets/'charactercreator-v24/manifest.json').read_text())
    for entry in source_manifest['files']:
        file=assets/'charactercreator-v24'/entry['file'];assert sha(file)==entry['sha256'],str(file)
    for key,source in LOCK['sources'].items():
        dest=WORK/key
        if not dest.exists():
            subprocess.run(['git','init',str(dest)],check=True,stdout=subprocess.DEVNULL)
            subprocess.run(['git','-C',str(dest),'remote','add','origin','https://github.com/'+source['repo']+'.git'],check=True)
            subprocess.run(['git','-C',str(dest),'fetch','--depth=1','origin',source['sha']],check=True)
            subprocess.run(['git','-C',str(dest),'checkout','--detach',source['sha']],check=True)
        actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=dest,text=True).strip();assert actual==source['sha']
        for f in dest.rglob('*'):
            if f.is_file() and '.git' not in f.parts and (f.suffix=='.glb' or 'LICENSE' in f.name.upper() or f.name in ['package.json','package-lock.json']):
                records.append({'source':key,'file':str(f.relative_to(WORK)),'sha256':sha(f),'bytes':f.stat().st_size})
    blender=download(LOCK['blenderUrl'],WORK/'blender.tar.xz');records.append(blender)
    checksum=download(LOCK['blenderChecksums'],WORK/'blender.sha256');records.append(checksum)
    name=LOCK['blenderUrl'].split('/')[-1]
    expected=next(line.split()[0] for line in (WORK/'blender.sha256').read_text().splitlines() if name in line)
    assert blender['sha256']==expected,'Official Blender checksum mismatch'
    if not (WORK/f"blender-{LOCK['blender']}-linux-x64/blender").exists():
        with tarfile.open(WORK/'blender.tar.xz') as archive:archive.extractall(WORK,filter='data')
    # Pack is CC0; no additional CMU downloads (the Ara source already contains baked clips).
    pack=download(LOCK['makehumanPack'],WORK/'makehuman-system-cc0.zip');records.append(pack)
    expected_pack=LOCK.get('makehumanPackSha256')
    if expected_pack:assert pack['sha256']==expected_pack,'CC0 pack checksum mismatch'
    ara=WORK/'ara';vendor=ara/'vendor';vendor.mkdir(exist_ok=True)
    if not (vendor/'mh').exists():(vendor/'mh').symlink_to(WORK/'makehuman',target_is_directory=True)
    if not (vendor/'sys').exists():
        with zipfile.ZipFile(WORK/'makehuman-system-cc0.zip') as archive:archive.extractall(vendor/'sys')
    (OUT/'acquisition.json').write_text(json.dumps({'lock':LOCK,'files':records},indent=2)+'\n')

def audit():
    files=sorted((WORK/'binary-assets').rglob('*.glb'))
    assert len(files)==16,len(files)
    run('published-auditor',['node',str(HERE.parent/'audit-glb.cjs'),*map(str,files)])
    assert run('binary-audit',[sys.executable,str(HERE/'binary_audit.py'),str(WORK/'binary-assets'),str(OUT/'binary-audit.json')])
    shutil.copytree(WORK/'binary-assets',OUT/'baseline-glb',dirs_exist_ok=True)

def tools():
    for key in ['mesh2motion','ara']:
        good=run(key+'-npm-ci',['npm','ci','--no-audit','--no-fund'],WORK/key)
        if good:
            if key=='mesh2motion':run('mesh2motion-build',['npm','run','build'],WORK/key)
            else:
                good=run('ara-build-assets',['npm','run','build-assets'],WORK/key)
                if good:run('ara-export',['npm','run','export','--','--preset','Athletic man','--formats','glb','--detail','high','--out',str(WORK/'ara-export')],WORK/key)
    # Keep Ara results local to artifacts only if they do not package CMU clips as a standalone library.
    if (WORK/'ara-export').exists():shutil.copytree(WORK/'ara-export',OUT/'ara-export',dirs_exist_ok=True)
    blender=str(WORK/f"blender-{LOCK['blender']}-linux-x64/blender")
    run('rigger-build',[sys.executable,'build.py'],WORK/'rigger')
    assert run('blender-headless',[blender,'--background','--factory-startup','--python-exit-code','1','--python',str(HERE/'blender_probe.py')])
    run('rigger-upstream-generate',[blender,'--background','--factory-startup','--python-exit-code','1','--python',str(WORK/'rigger/tests/test_generate.py')])

def browser():
    for case in ['lod','contact','surface','stage','paired']:
        run('chromium-'+case,[sys.executable,f'tests/match3d-v24-{case}-browser.py'],ROOT/'baseline',timeout=900)
    for folder in (ROOT/'baseline').glob('match3d-v24-*-report'):
        shutil.copytree(folder,OUT/folder.name,dirs_exist_ok=True)

def finalize():
    statuses=[json.loads(p.read_text()) for p in sorted(OUT.glob('*.status.json'))]
    files=[{'path':str(f.relative_to(OUT)),'bytes':f.stat().st_size,'sha256':sha(f)} for f in sorted(OUT.rglob('*')) if f.is_file() and f.name!='manifest.json']
    report={'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'baseline':LOCK['baseline'],'run':os.getenv('GITHUB_RUN_ID'),'renderer':'CPU SwiftShader; no hardware GPU/VRAM measurement','host':platform.platform(),'cpuCount':os.cpu_count(),'node':subprocess.check_output(['node','--version'],text=True).strip(),'python':sys.version,'statuses':statuses,'files':files,
    'limits':['No runtime integration or artistic qualification','Ara generates an alternative character; does not import the canonical rugby GLB','Mesh2Motion build is not yet an import/export test','Rigger registration and synthetic tests are not a rugby rig fitting approval','MakeHuman pack is initially observed SHA256, must be pinned from first receipt']}
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    essential=['binary-audit','blender-headless','chromium-lod','chromium-stage']
    assert all(any(s['name']==name and s['status']=='PASS' for s in statuses) for name in essential),'Missing essential receipt; inspect status JSON and logs'
    assert any(OUT.rglob('*.jpg')),'No real Chromium capture'

if __name__=='__main__':globals()[sys.argv[1]]()
