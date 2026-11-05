"""Reproducible remote lab. No writes to game sources, no cloud inference, no secrets in reports."""
import sys,os,subprocess,json,hashlib,shutil,urllib.request,tarfile,zipfile,time,platform
from pathlib import Path

ROOT=Path.cwd();HERE=Path(__file__).resolve().parent
OUT=ROOT/'rd-report';WORK=ROOT/'rd-work';OUT.mkdir(exist_ok=True);WORK.mkdir(exist_ok=True)
LOCK=json.loads((HERE/'lock.json').read_text())
REQUIRED=['acquire','published-auditor','binary-audit','blender-headless','rigger-registration',
          'mesh2motion-npm-ci','mesh2motion-build','mesh2motion-roundtrip','ara-npm-ci','ara-build-assets','ara-export',
          'ara-rigger-real-body','ara-controlled-retarget',
          'chromium-lod','chromium-contact','chromium-surface','chromium-stage','chromium-paired',
          'baseline-offline-node','baseline-runtime-browser']

def receipt(statuses,has_acquisition,has_capture):
    missing=[name for name in REQUIRED if not any(s['name']==name and s['status']=='PASS' for s in statuses)]
    if not has_acquisition:missing.append('acquisition.json')
    if not has_capture:missing.append('real Chromium capture')
    return {'complete':not missing,'verdict':'COMPLETE' if not missing else 'PARTIAL_OR_FAILED','missingOrFailed':missing}

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
    for name,expected in LOCK['baselineSha256'].items():assert sha(target/name)==expected,name
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
                if 'LICENSE' in f.name.upper():
                    license_copy=OUT/'licenses'/key/f.relative_to(dest);license_copy.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,license_copy)
    blender=download(LOCK['blenderUrl'],WORK/'blender.tar.xz');records.append(blender)
    checksum=download(LOCK['blenderChecksums'],WORK/'blender.sha256');records.append(checksum)
    name=LOCK['blenderUrl'].split('/')[-1]
    expected=next(line.split()[0] for line in (WORK/'blender.sha256').read_text().splitlines() if name in line)
    assert blender['sha256']==expected,'Official Blender checksum mismatch'
    assert blender['sha256']==LOCK['blenderSha256'] and checksum['sha256']==LOCK['blenderChecksumFileSha256'],'Pinned Blender SHA256 mismatch'
    if not (WORK/f"blender-{LOCK['blender']}-linux-x64/blender").exists():
        with tarfile.open(WORK/'blender.tar.xz') as archive:archive.extractall(WORK,filter='data')
    # Pack is CC0; no additional CMU downloads (the Ara source already contains baked clips).
    pack=download(LOCK['makehumanPack'],WORK/'makehuman-system-cc0.zip');records.append(pack)
    expected_pack=LOCK['makehumanPackSha256']
    assert pack['sha256']==expected_pack,'CC0 pack checksum mismatch'
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
    blender_report=json.loads((OUT/'blender.json').read_text())
    (OUT/'rigger-registration.status.json').write_text(json.dumps({'name':'rigger-registration','status':blender_report['riggerRegistration'],'error':blender_report.get('riggerError')},indent=2)+'\n')
    run('rigger-upstream-generate',[blender,'--background','--factory-startup','--python-exit-code','1','--python',str(WORK/'rigger/tests/test_generate.py')])
    # Exploratory real-body probe is separately reported, not part of REQUIRED nor artistic approval.
    run('ara-rigger-real-body',[blender,'--background','--factory-startup','--python-exit-code','1','--python',str(HERE/'ara_rigger_probe.py')],timeout=600)
    run('ara-controlled-retarget',[blender,'--background','--factory-startup','--python-exit-code','1','--python',str(HERE/'ara_retarget_probe.py')],timeout=360)

def browser():
    (OUT/'copies').mkdir(exist_ok=True)
    if (WORK/'mesh2motion/node_modules').exists():
        run('mesh2motion-roundtrip',[sys.executable,str(HERE/'mesh2motion_probe.py')])
    for case in ['lod','contact','surface','stage','paired']:
        run('chromium-'+case,[sys.executable,f'tests/match3d-v24-{case}-browser.py'],ROOT/'baseline',timeout=900)
    run('baseline-offline-node',['node','tests/offline.cjs'],ROOT/'baseline')
    run('baseline-offline-pack',[sys.executable,'scripts/build-offline.py','--prepare-only'],ROOT/'baseline')
    run('baseline-runtime-browser',[sys.executable,'tests/match3d-browser.py'],ROOT/'baseline')
    for folder in (ROOT/'baseline').glob('match3d-v24-*-report'):
        shutil.copytree(folder,OUT/folder.name,dirs_exist_ok=True)
    if (ROOT/'baseline/match3d-browser-report').exists():
        shutil.copytree(ROOT/'baseline/match3d-browser-report',OUT/'baseline-runtime-report',dirs_exist_ok=True)

def finalize():
    statuses=[json.loads(p.read_text()) for p in sorted(OUT.glob('*.status.json'))]
    files=[{'path':str(f.relative_to(OUT)),'bytes':f.stat().st_size,'sha256':sha(f)} for f in sorted(OUT.rglob('*')) if f.is_file() and f.name!='manifest.json']
    report={'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'baseline':LOCK['baseline'],'run':os.getenv('GITHUB_RUN_ID'),'renderer':'CPU SwiftShader; no hardware GPU/VRAM measurement','host':platform.platform(),'cpuCount':os.cpu_count(),'node':subprocess.check_output(['node','--version'],text=True).strip(),'python':sys.version,'statuses':statuses,'files':files,
    'receipt':receipt(statuses,(OUT/'acquisition.json').is_file(),any(OUT.rglob('*.jpg'))),
    'limits':['No V24 runtime integration or artistic qualification','Ara generates an alternative character; does not import the canonical rugby GLB','Mesh2Motion minimal API roundtrip does not fit/retarget rugby animations','Rigger registration and synthetic tests are not a rugby rig fitting approval','Baseline runtime/fallback tests are separate from isolated V24 stage']}
    (OUT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    assert report['receipt']['complete'],report['receipt']

if __name__=='__main__':
    stage=sys.argv[1];start=time.monotonic()
    try:
        globals()[stage]();status={'name':stage,'status':'PASS','seconds':time.monotonic()-start}
    except Exception as error:
        status={'name':stage,'status':'FAIL','error':str(error),'seconds':time.monotonic()-start}
        raise
    finally:
        (OUT/(stage+'.status.json')).write_text(json.dumps(status,indent=2)+'\n')
