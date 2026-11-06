"""Copy-and-instrument the PINNED authentic V25 Blender script.
Exports per-frame REAL evaluated armature bone worlds, root transforms and existing
IK target empties to a sidecar; does not alter authoring, roots, scripts or assets.
"""
import hashlib,importlib.util,json,os,shutil,subprocess,sys,tarfile,urllib.request
from pathlib import Path
ROOT=Path.cwd()
SRC=ROOT/"rd-source/tools/match3d-v25-lab/remote"
LOCK=json.loads((SRC/"lock.json").read_text())
OUT=ROOT/"oss-temporal-report";OUT.mkdir(exist_ok=True)
PINNED_SOURCE="065589001fbef9641070218b6f85bb597da96a6a"
FRAMES=sorted([1,22,30,40,60,90,10,18,24,26,28,32,34,36,38,45,50,70,80])
def sha(path):
    h=hashlib.sha256()
    with open(path,"rb") as f:
        for b in iter(lambda:f.read(1024*1024),b""):h.update(b)
    return h.hexdigest()
def must(cond,reason):
    if not cond:raise RuntimeError(reason)
def one(text,a,b):
    must(text.count(a)==1,f"inject expected exact single marker: {a[:90]}; actual={text.count(a)}")
    return text.replace(a,b)
def instrument(text):
    helper=r'''
FRAME_EVIDENCE=[]
def capture_19frame_real(lod,frame,actors,gait_locks):
    def mat(m):
        return [float(m[col][row]) for col in range(4) for row in range(4)]
    item={"lod":lod,"frame":frame,"actors":{}}
    for lab,actor in actors.items():
        rig=actor["rig"]
        evidence={"rigWorld":mat(rig.matrix_world),
          "actorRootWorld":mat(actor["actor_root"].matrix_world),
          "bones":{},
          "stanceLocks":[]}
        assert len(rig.pose.bones)==53
        for bone in rig.pose.bones:
            evidence["bones"][bone.name]={
                "world":mat(rig.matrix_world@bone.matrix),
                "restWorld":mat(rig.matrix_world@bone.bone.matrix_local)}
        for lock in gait_locks:
            if lock["actor"]!=lab:continue
            side=lock["side"]
            ankle=rig.pose.bones["foot_"+side]
            active=[c.influence for c in ankle.constraints
                    if c.type=="IK" and c.target==lock["target"]]
            assert len(active)==1,"missing authentic V25 IK support target"
            evidence["stanceLocks"].append({
                "side":side,"firstSupportFrame":lock["firstSupportFrame"],
                "influence":float(active[0]),
                "authoredTargetWorld":mat(lock["target"].matrix_world),
                "ankleWorld":mat(rig.matrix_world@ankle.matrix)})
        item["actors"][lab]=evidence
    FRAME_EVIDENCE.append(item)
'''
    text=one(text,'PHASES=[1,22,30,40,60,90]\n',
        'PHASES=[1,22,30,40,60,90]\n'+helper)
    text=one(text,'            row=audit(actors["A"],actors["B"]);row["frame"]=frame',
        '            capture_19frame_real(lod,frame,actors,gait_locks)\n'
        '            row=audit(actors["A"],actors["B"]);row["frame"]=frame')
    text=one(text,'            sample=audit(actors["A"],actors["B"])',
        '            capture_19frame_real(lod,frame,actors,gait_locks)\n'
        '            sample=audit(actors["A"],actors["B"])')
    text=one(text,'    out=OUT/"original-tackle-report.json"',
        '    (OUT/"actual-v25-frame-worlds.json").write_text(json.dumps({"schema":"cd-v25-temporal-real-v1","frames":sorted(PHASES+DENSE_FRAMES),"source":"ORIGINAL_V25_EVALUATED_POSES_AND_IK_TARGETS","samples":FRAME_EVIDENCE},indent=2)+"\\n")\n'
        '    out=OUT/"original-tackle-report.json"')
    compile(text,"<copy-of-v25-with-evidence>","exec")
    return text
def main():
    report={"status":"FAILED","sourceRef":os.getenv("V25_REF"),"errors":[],"images":0,"samples":0}
    try:
        must(report["sourceRef"]==PINNED_SOURCE,"V25 source SHA not pinned")
        orig=SRC/"true_sole_ik_elbow_search_probe.py"
        baseline=ROOT/"baseline/dist/match3d/assets/rugby-v24"
        for lod in range(3):
            for tag in ("base_body_anim","clothing_shoes"):
                p=baseline/"lod"/f"{tag}-lod{lod}.glb"
                rel=f"lod/{tag}-lod{lod}.glb"
                must(p.is_file() and sha(p)==LOCK["baselineSha256"][rel],"baseline GLB mismatch "+rel)
        spec=importlib.util.spec_from_file_location("oss_paired",ROOT/"research/oss-match3d-20261106/run_paired_ik.py")
        mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
        source=mod.instrument(orig.read_text(encoding="utf-8"),False)
        derived=instrument(source)
        script=OUT/"captured-pinned-v25-copy.py";script.write_text(derived,encoding="utf-8")
        blender=mod.get_blender()
        work=OUT/"original";work.mkdir(exist_ok=True)
        (work/"baseline").symlink_to(ROOT/"baseline",target_is_directory=True)
        with (work/"blender.log").open("w") as log:
            cp=subprocess.run([str(blender),"--background","--factory-startup",
                "--python-exit-code","1","--python",str(script)],cwd=work,
                stdout=log,stderr=subprocess.STDOUT,timeout=3200)
        path=work/"rd-report/original-tackle"
        provenance=path/"actual-v25-frame-worlds.json"
        measured=path/"original-tackle-report.json"
        must(provenance.exists() and measured.exists(),"no Blender V25 source evidence produced")
        data=json.loads(provenance.read_text())
        src_report=json.loads(measured.read_text())
        report["samples"]=len(data.get("samples",[]))
        images=list(path.glob("original-lod*-*.png"))
        report["images"]=len(images)
        must(cp.returncode==0 and not src_report.get("errors"),"source Blender aborted; see log")
        must(report["samples"]==3*19,"missing one or more original real time samples")
        must(report["images"]==3*19*3,"missing required 171 original source images")
        for lod in range(3):
            frames=[x for x in data["samples"] if x["lod"]==lod]
            must(sorted(x["frame"] for x in frames)==FRAMES,"missing/duplicate frame")
            for row in frames:
                must(set(row["actors"])=={"A","B"},"missing actor")
                for actor in row["actors"].values():
                    must(len(actor["bones"])==53,"missing original bone")
                    must(all(len(x["world"])==16 for x in actor["bones"].values()),"missing 4x4 world")
                    must(1<=len(actor["stanceLocks"])<=2,"lost source V25 authored stance")
        report.update({"status":"REAL_V25_TEMPORAL_INPUTS_CAPTURED_NOT_EKZA_ANIMATED",
            "sourceScriptSHA256":sha(orig),"instrumentedScriptSHA256":sha(script),
            "timeSampleSHA256":sha(provenance),"V25ReportSHA256":sha(measured)})
        shutil.copy2(provenance,OUT/"actual-v25-frame-worlds.json")
        shutil.copy2(measured,OUT/"original-v25-report.json")
    except Exception as error:report["errors"].append(str(error))
    (OUT/"capture-summary.json").write_text(json.dumps(report,indent=2)+"\n")
    print(json.dumps(report,indent=2),flush=True)
    return 0 if report["status"].startswith("REAL_V25_") else 1
if __name__=="__main__":sys.exit(main())
