"""Run only original procedural Blender probe; pinned Blender, no CMU assets."""
import hashlib,json,pathlib,subprocess,tarfile,urllib.request,shutil,traceback,sys
ROOT=pathlib.Path.cwd(); WORK=ROOT/"rd-work";WORK.mkdir(exist_ok=True)
OUT=ROOT/"rd-report"/"original-tackle";OUT.mkdir(parents=True,exist_ok=True)
LOCK=json.loads((ROOT/"tools/match3d-v25-lab/remote/lock.json").read_text())
def sha(p):return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
status={"status":"FAIL","origin":"ORIGINAL_TRUE_SOLE_IK_CADENCE_V9_NO_EXTERNAL_CLIP","blender":LOCK["blender"]}
try:
    path=WORK/"blender.tar.xz"
    if not path.exists():
        with urllib.request.urlopen(LOCK["blenderUrl"],timeout=180) as src,path.open("wb") as dst:
            shutil.copyfileobj(src,dst)
    assert sha(path)==LOCK["blenderSha256"],"Pinned Blender archive SHA mismatch"
    blender=WORK/f"blender-{LOCK['blender']}-linux-x64"/"blender"
    if not blender.exists():
        with tarfile.open(path) as tar:tar.extractall(WORK,filter="data")
    assert blender.exists()
    status["archiveSha256"]=sha(path)
    cmd=[str(blender),"--background","--factory-startup","--python-exit-code","1",
         "--python","tools/match3d-v25-lab/remote/true_sole_ik_cadence_probe.py"]
    with (OUT/"blender-original.log").open("w") as log:
        proc=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=1000)
    status["returnCode"]=proc.returncode
    assert proc.returncode==0,"Blender error: read blender-original.log"
    report=json.loads((OUT/"original-tackle-report.json").read_text())
    assert report["status"]=="AUTHORED_AND_MEASURED_NOT_VISUALLY_APPROVED"
    assert len(report["lods"])==3 and report["imagesProduced"]==54
    status["status"]="RENDERED_NOT_ART_APPROVED"
    status["reportSha256"]=sha(OUT/"original-tackle-report.json")
except Exception as e:
    status["error"]=str(e);status["traceback"]=traceback.format_exc()
finally:
    (OUT/"runner-status.json").write_text(json.dumps(status,indent=2)+"\n")
print(json.dumps(status),flush=True)
if status["status"]=="FAIL":sys.exit(1)
