"""Pinned V25 A/B: real skinned body GLBs; baseline vs Blender two-bone IK proxy.
The candidate is informed by Ekza, NOT a port of Ekza's TypeScript solver.
Neither Blender source, baseline assets, game code nor PR #300 is edited.
"""
import hashlib,json,os,shutil,subprocess,sys,tarfile,urllib.request
from pathlib import Path
ROOT=Path.cwd()
SRC=ROOT/"rd-source/tools/match3d-v25-lab/remote"
LOCK=json.loads((SRC/"lock.json").read_text())
OUTPUT=ROOT/"oss-paired-report"
OUTPUT.mkdir(exist_ok=True)
SCRIPT=SRC/"true_sole_ik_elbow_search_probe.py"
EXPECTED=171

def check(p,msg):
    if not p: raise RuntimeError(msg)

def sha(p):
    h=hashlib.sha256()
    with Path(p).open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""): h.update(chunk)
    return h.hexdigest()

def replace_once(s,a,b,name):
    check(s.count(a)==1,f"{name}: expected one occurrence, found {s.count(a)}")
    return s.replace(a,b)

def instrument(s,candidate):
    # No changes to source keyframes, foot measurements, root motion or GLB.
    marker="        # True longitudinal actor-isolated profiles."
    end="        scene.frame_set(PHASES[0]);bpy.context.view_layer.update()"
    check(s.count(marker)==1 and s.count(end)==1,"pinned source markers missing")
    first,tail=s.split(marker,1)
    solo,remaining=tail.split(end,1)
    check("singleActorProfiles" in solo and "bpy.ops.render.render" in solo,"solo block changed")
    s=first+"        # Paired study: shared three-camera frames only.\n"+end+remaining
    s=replace_once(s,'            if sample["frame"] not in (24,34):continue',
        '            if sample["frame"] not in DENSE_FRAMES:continue',"dense frame render")
    if candidate:
        # Proxy: true Blender two-link IK (thigh+calf) towards same ankle target.
        # NOT copied Ekza code; result can fail and must NOT be art-approved.
        s=replace_once(s,'        con=ankle.constraints.new("IK")',
            '        con=shin.constraints.new("IK")',"two-link effector")
        s=replace_once(s,'        con.target=target;con.chain_count=3;con.use_rotation=False',
            '        con.target=target;con.chain_count=2;con.use_rotation=False',"two-link count")
    compile(s,"<derived-v25-copy>","exec")
    return s

def verify_glbs():
    out={}
    for lod in range(3):
        rel=f"lod/base_body_anim-lod{lod}.glb"
        p=ROOT/"baseline/dist/match3d/assets/rugby-v24"/rel
        check(p.is_file(),f"missing GLB: {p}")
        digest=sha(p)
        check(digest==LOCK["baselineSha256"][rel],f"GLB SHA mismatch LOD{lod}")
        out[f"lod{lod}"]={"sha256":digest,"bytes":p.stat().st_size}
    return out

def get_blender():
    check(LOCK["blender"]=="4.5.3","unexpected Blender version")
    folder=ROOT/"rd-work";folder.mkdir(exist_ok=True)
    archive=folder/"blender.tar.xz"
    if not archive.exists():
        with urllib.request.urlopen(LOCK["blenderUrl"],timeout=180) as src,archive.open("wb") as dst:
            shutil.copyfileobj(src,dst)
    check(sha(archive)==LOCK["blenderSha256"],"Blender ZIP SHA mismatch")
    binary=folder/f'blender-{LOCK["blender"]}-linux-x64'/"blender"
    if not binary.exists():
        with tarfile.open(archive,"r:xz") as t:t.extractall(folder,filter="data")
    check(binary.exists(),"Blender binary not extracted")
    return binary

def run_variant(blender,src,label):
    script=OUTPUT/f"{label}.py"
    script.write_text(instrument(src,label=="two-bone-proxy"),encoding="utf-8")
    work=OUTPUT/label;work.mkdir(exist_ok=True)
    (work/"baseline").symlink_to(ROOT/"baseline",target_is_directory=True)
    log=work/"blender.log"
    with log.open("w",encoding="utf-8") as stream:
        proc=subprocess.run([str(blender),"--background","--factory-startup",
            "--python-exit-code","1","--python",str(script)],cwd=work,
            stdout=stream,stderr=subprocess.STDOUT,timeout=2700)
    folder=work/"rd-report/original-tackle"
    reportfile=folder/"original-tackle-report.json"
    check(reportfile.is_file(),f"{label}: report missing, rc={proc.returncode}")
    report=json.loads(reportfile.read_text(encoding="utf-8"))
    images=sorted(folder.glob("original-lod*-*.png"))
    check(proc.returncode==0 and not report.get("errors"),f"{label}: Blender errors, see log")
    check(len(report.get("lods",[]))==3,f"{label}: missing three LOD")
    check(len(images)==EXPECTED and report.get("imagesProduced")==EXPECTED,
        f"{label}: images {len(images)}/{EXPECTED}, report={report.get('imagesProduced')}")
    check(all(len(x.get("frames",[]))==6 and len(x.get("denseFrames",[]))==13
        for x in report["lods"]),f"{label}: 19 frames not measured")
    check(all(len(x.get("gaitStanceIK",[]))==3 for x in report["lods"]),
        f"{label}: missing locks")
    return {"label":label,"scriptSha256":sha(script),"reportSha256":sha(reportfile),
        "status":report.get("status"),"visualApproval":report.get("visualApproval"),
        "imagesProduced":len(images),"lods":3,
        "files":[{"name":p.relative_to(work).as_posix(),"sha256":sha(p),"bytes":p.stat().st_size}
          for p in images]}

def main():
    state={"status":"FAILED","sourceRef":os.getenv("V25_REF"),
        "branchSha":os.getenv("GITHUB_SHA"),"expectedImages":342,
        "method":"Blender three-link vs Blender two-link IK proxy informed by Ekza; NOT Ekza source port",
        "variants":[],"errors":[]}
    try:
        check(state["sourceRef"]=="065589001fbef9641070218b6f85bb597da96a6a","unpinned source")
        state["sourceSha256"]=sha(SCRIPT)
        state["sourceGLB"]=verify_glbs()
        blender=get_blender()
        source=SCRIPT.read_text(encoding="utf-8")
        for label in ("baseline-three-bone","two-bone-proxy"):
            state["variants"].append(run_variant(blender,source,label))
        check(sum(x["imagesProduced"] for x in state["variants"])==342,
            "paired image count incomplete")
        state["status"]="RENDERED_NOT_VISUALLY_APPROVED"
    except Exception as err:state["errors"].append(str(err))
    (OUTPUT/"run-summary.json").write_text(json.dumps(state,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({k:v for k,v in state.items() if k!="variants"},indent=2),flush=True)
    return 1 if state["errors"] else 0
if __name__=="__main__":sys.exit(main())
