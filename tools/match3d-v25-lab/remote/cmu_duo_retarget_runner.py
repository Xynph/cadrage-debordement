"""Minimal pinned Blender/Rigger/CMU dual-actor retarget runner.
Does not touch game sources or package original BVH animations in reports.
"""
import hashlib,json,pathlib,subprocess,sys,tarfile,urllib.request,shutil,traceback
ROOT=pathlib.Path.cwd();WORK=ROOT/"rd-work";OUT=ROOT/"rd-report"/"cmu-duo"
WORK.mkdir(exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
LOCK=json.loads((ROOT/"tools"/"match3d-v25-lab"/"remote"/"lock.json").read_text())
BVHS=[("18_03.bvh","018/18_03.bvh","9ad0bd0cdb3c55c712bc495b07ebea2fd472132d824a79e3b0a50dcbfc16c1f1"),
      ("19_03.bvh","019/19_03.bvh","d1005fc10d57099176cee6475b920d92df2c53d7105e34c6720f07f0c0c866ed")]
SRC="09a07f54f3bbb58797325f009282d0b2048a2871"
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def fetch(url,p):
    p.parent.mkdir(parents=True,exist_ok=True)
    if not p.exists():
        with urllib.request.urlopen(url,timeout=150) as r,p.open("wb") as f:shutil.copyfileobj(r,f)
    return p
def run(name,cmd,cwd=ROOT,timeout=480):
    log=OUT/(name+".log")
    with log.open("w") as f:
        q=subprocess.run(cmd,cwd=cwd,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
    result={"name":name,"returncode":q.returncode,"log":log.name}
    (OUT/(name+".json")).write_text(json.dumps(result,indent=2)+"\n")
    if q.returncode:raise RuntimeError(f"{name} failed: see {log}")
    return result
status={"status":"FAIL","sourceGitSha":SRC,"sourceClips":[],"artisticApproved":False}
try:
    bvhdir=WORK/"cmu-duo"
    for name,source,digest in BVHS:
        path=fetch(f"https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/{SRC}/data/{source}",bvhdir/name)
        assert sha(path)==digest,name
        status["sourceClips"].append({"name":name,"sha256":digest,"bytes":path.stat().st_size})
    rigger=WORK/"rigger"
    ref=LOCK["sources"]["rigger"]
    if not (rigger/".git").exists():
        run("rigger-clone",["git","clone","--filter=blob:none","--no-checkout",
            "https://github.com/"+ref["repo"]+".git",str(rigger)],timeout=180)
    run("rigger-fetch",["git","fetch","--depth=1","origin",ref["sha"]],cwd=rigger,timeout=180)
    run("rigger-checkout",["git","checkout","--detach",ref["sha"]],cwd=rigger,timeout=180)
    assert subprocess.check_output(["git","rev-parse","HEAD"],cwd=rigger,text=True).strip()==ref["sha"]
    run("rigger-build",[sys.executable,"build.py"],cwd=rigger)
    tar=fetch(LOCK["blenderUrl"],WORK/"blender.tar.xz")
    assert sha(tar)==LOCK["blenderSha256"],"Blender download digest mismatch"
    blender=WORK/f"blender-{LOCK['blender']}-linux-x64"/"blender"
    if not blender.exists():
        with tarfile.open(tar) as t:t.extractall(WORK,filter="data")
    assert blender.exists()
    run("cmu-2actor-3lod-retarget",[
        str(blender),"--background","--factory-startup","--python-exit-code","1","--python",
        "tools/match3d-v25-lab/remote/cmu_duo_retarget_probe.py"],timeout=900)
    status["status"]="PASS_SOURCE_RETARGET_PROBE_RECORDED"
except Exception as e:
    status["error"]=str(e)
    status["traceback"]=traceback.format_exc()
finally:
    (OUT/"acquisition-verdict.json").write_text(json.dumps(status,indent=2)+"\n")
if status["status"]=="FAIL":raise SystemExit(1)
