"""Pinned, reproducible third-party tackle candidate experiment (Chat R&D only).
Real upstream Godot GUT suite + our canonical 53-bone GLBs. Never imports third-party code into the game.
"""
import hashlib
import json
import os
import pathlib
import shutil
import subprocess
import struct
import sys
import time
import urllib.error
import urllib.request
import zipfile

ROOT=pathlib.Path.cwd()
OUT=ROOT/"rd-report"/"external-tackle"
OUT.mkdir(parents=True,exist_ok=True)
WORK=ROOT/"rd-work"/"external-tackle"
WORK.mkdir(parents=True,exist_ok=True)
PINNED={
    "kickback":{"repo":"blugart-dev/kickback","sha":"1d2c5ae3617eb676dc86368a30eb31f80ab52419","license":"MIT",
        "files":["LICENSE","project.godot","addons/kickback/skeleton_detector.gd","addons/kickback/active_ragdoll_controller.gd","addons/kickback/two_bone_ik.gd","test/test_two_bone_ik.gd","test/test_collision_monitor.gd"]},
    "active_ragdoll":{"repo":"ashleve/ActiveRagdoll","sha":"749cd80dbccd73dffb7bb1d3827ad0e719b84f1c","license":"MIT",
        "files":["LICENSE","Assets/ActiveRagdollScripts/AnimationFollowing.cs","Assets/ActiveRagdollScripts/SlaveController.cs"]},
    "physicsfc":{"repo":"dongdong2222/PhysicsFC","sha":"0f789ef1eff75ce364d5647fd24763789f4dfe95","license":"NVIDIA-NONCOMMERCIAL",
        "files":["License.txt","README.md"]},
    "striker3d":{"repo":"kendrekaran/striker-3d","sha":"57847f87ff3d924712a1bb37df9dae391aedc315","license":"NO_ROOT_LICENSE",
        "files":["README.md","assets/LICENSE-quaternius.txt"]},
}
GODOT_VERSION="4.7-stable"
GODOT_URL=("https://github.com/godotengine/godot/releases/download/"+GODOT_VERSION+
           "/Godot_v4.7-stable_linux.x86_64.zip")

def digest(b):return hashlib.sha256(b).hexdigest()
def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":"CD-Match3D-Lab/1.0"}),timeout=90) as f:
        return f.read()
def command(name,args,cwd=None,timeout=900):
    log=OUT/(name+".log")
    t=time.monotonic()
    try:
        with log.open("w") as out:
            p=subprocess.run(args,cwd=cwd or ROOT,stdout=out,stderr=subprocess.STDOUT,timeout=timeout)
        res={"name":name,"returncode":p.returncode,"status":"PASS" if p.returncode==0 else "FAIL",
             "seconds":round(time.monotonic()-t,2),"log":log.name}
    except Exception as exc:
        res={"name":name,"status":"FAIL","error":str(exc),"seconds":round(time.monotonic()-t,2)}
    (OUT/(name+".json")).write_text(json.dumps(res,indent=2)+"\n")
    print(json.dumps(res),flush=True)
    return res

def audit_sources():
    matrix=[]
    for key,entry in PINNED.items():
        files=[]
        for path in entry["files"]:
            url=f"https://raw.githubusercontent.com/{entry['repo']}/{entry['sha']}/{path}"
            try:
                b=fetch(url)
                files.append({"path":path,"bytes":len(b),"sha256":digest(b),"http":"OK"})
                if key=="kickback" and path=="project.godot":
                    assert b'PackedStringArray("4.7"' in b,"Kickback engine version unexpectedly changed"
                if key=="physicsfc" and path=="License.txt":
                    assert b"non-commercially" in b.lower() and b"3.3 Use Limitation" in b
                if key in ("kickback","active_ragdoll") and path=="LICENSE":
                    assert b"MIT License" in b or b"Permission is hereby granted" in b
            except (urllib.error.HTTPError,TimeoutError) as e:
                files.append({"path":path,"error":str(e),"http":"FAIL"})
        # The Quaternius CC0 art license in Striker3D does NOT license the game source.
        matrix.append({"id":key,"repository":entry["repo"],"head":entry["sha"],
           "declaredLicense":entry["license"],"files":files,
           "mayPortCode":key in ("kickback","active_ragdoll"),
           "commercialGameUse":key in ("kickback","active_ragdoll"),
           "directEngineCompatibility":("Godot 4.7+" if key=="kickback" else
              "Unity / C#; port mandatory" if key=="active_ragdoll" else "NOT APPROVED"),
           "verification":"PINNED_SOURCE_BYTES_NOT_PROOF_OF_RUNTIME_COMPATIBILITY"})
    (OUT/"source-license-matrix.json").write_text(json.dumps(matrix,indent=2)+"\n")
    assert all(f.get("http")=="OK" for x in matrix for f in x["files"]), "Source audit incomplete"
    return matrix

def godot_release():
    location=WORK/"godot-4.7-stable.zip"
    if not location.exists():location.write_bytes(fetch(GODOT_URL))
    if location.stat().st_size<50_000_000:raise RuntimeError("Godot binary too small")
    binary=WORK/"godot"
    if not binary.exists():
        with zipfile.ZipFile(location) as z:
            members=[i for i in z.namelist() if i.endswith("linux.x86_64")]
            assert len(members)==1,members
            with z.open(members[0]) as r,binary.open("wb") as w:shutil.copyfileobj(r,w)
        binary.chmod(0o755)
    details={"tag":GODOT_VERSION,"url":GODOT_URL,"zipBytes":location.stat().st_size,
        "zipSha256":digest(location.read_bytes()),"binarySha256":digest(binary.read_bytes())}
    (OUT/"godot-version.json").write_text(json.dumps(details,indent=2)+"\n")
    return binary

def acquire_kickback():
    k=PINNED["kickback"]
    location=WORK/"kickback"
    if not (location/".git").exists():
        subprocess.run(["git","clone","--depth=1","--branch","main",
                        f"https://github.com/{k['repo']}.git",str(location)],check=True,timeout=180)
    actual=subprocess.check_output(["git","rev-parse","HEAD"],cwd=location,text=True).strip()
    if actual!=k["sha"]:
        subprocess.run(["git","fetch","--depth=1","origin",k["sha"]],cwd=location,check=True,timeout=180)
        subprocess.run(["git","checkout","--detach",k["sha"]],cwd=location,check=True)
    assert subprocess.check_output(["git","rev-parse","HEAD"],cwd=location,text=True).strip()==k["sha"]
    return location

def glb_structure(file):
    """Compare identities/parentage of real skinned joints, independent of binary accessor order."""
    blob=pathlib.Path(file).read_bytes()
    assert blob[:4]==b"glTF",str(file)
    json_length,chunk_type=struct.unpack_from("<I4s",blob,12)
    assert chunk_type==b"JSON",str(file)
    doc=json.loads(blob[20:20+json_length])
    nodes=doc["nodes"]
    parent={}
    for parent_index,node in enumerate(nodes):
        for child in node.get("children",[]):
            parent[child]=parent_index
    skins=[]
    for skin in doc.get("skins",[]):
        joints=skin["joints"]
        names=[nodes[i].get("name",str(i)) for i in joints]
        pairs=sorted((nodes[i].get("name",str(i)),
                      nodes[parent[i]].get("name",str(parent[i])) if i in parent else None)
                     for i in joints)
        skins.append({"count":len(joints),"names":names,"parentPairs":pairs})
    assert skins and any(x["count"]==53 for x in skins),str(file)
    return {"extensionsRequired":doc.get("extensionsRequired",[]),
            "skins":skins,"animationCount":len(doc.get("animations",[]))}

def dequantize_canonical():
    package="@gltf-transform/cli@4.5.1"  # MIT, pinned: no auto-update.
    tools_dir=WORK/"gltf-transform-tools"
    tools_dir.mkdir(exist_ok=True)
    installed=command("gltf-transform-install",["npm","install","--prefix",str(tools_dir),
                      "--no-save","--no-audit","--no-fund",package],timeout=480)
    assert installed["status"]=="PASS","Pinned glTF Transform CLI install failed"
    cli=tools_dir/"node_modules/@gltf-transform/cli/bin/cli.js"
    assert cli.exists(),str(cli)
    baseline=ROOT/"baseline/dist/match3d/assets/rugby-v24/lod"
    converted=WORK/"dequantized"
    converted.mkdir(exist_ok=True)
    records=[]
    for lod in range(3):
        original=baseline/f"base_body_anim-lod{lod}.glb"
        target=converted/f"body-lod{lod}-dequantized.glb"
        before=glb_structure(original)
        assert "KHR_mesh_quantization" in before["extensionsRequired"],before
        task=command(f"gltf-dequantize-lod{lod}",["node",str(cli),"dequantize",
                     str(original),str(target)],timeout=180)
        assert task["status"]=="PASS",task
        after=glb_structure(target)
        assert "KHR_mesh_quantization" not in after["extensionsRequired"],after
        assert len(before["skins"])==len(after["skins"])
        for a,b in zip(before["skins"],after["skins"]):
            assert a["count"]==b["count"]==53
            assert a["parentPairs"]==b["parentPairs"],"Canonical hierarchy altered by dequantize"
        assert before["animationCount"]==after["animationCount"],"Animation count changed"
        records.append({"lod":lod,"originalSha256":digest(original.read_bytes()),
                        "copySha256":digest(target.read_bytes()),
                        "originalBytes":original.stat().st_size,
                        "copyBytes":target.stat().st_size,
                        "originalStructure":before,
                        "copyStructure":after,
                        "verdict":"PRESERVED_53_BONE_HIERARCHY_AND_ANIMATION_COUNT"})
    (OUT/"canonical-dequantization.json").write_text(json.dumps(
        {"tool":package,"originalsUnmodified":True,"records":records},indent=2)+"\n")
    return [str(converted/f"body-lod{i}-dequantized.glb") for i in range(3)]

def run_godot():
    binary=godot_release()
    directory=acquire_kickback()
    version=command("godot-version",[str(binary),"--version"],timeout=60)
    imported=command("kickback-godot-import",[str(binary),"--headless","--import","--path",str(directory)],timeout=300)
    upstream=command("kickback-upstream-gut",
        [str(binary),"--headless","--path",str(directory),"--script",
         "addons/gut/gut_cmdln.gd","--","-gdir=res://test/","-gexit"],timeout=900)
    # Godot 4.7 rejects the ORIGINAL KHR_mesh_quantization extension.
    # Decode copies with a pinned MIT tool, compare all 53 parent/bone pairs,
    # and never rewrite the canonical repository assets.
    input_paths=dequantize_canonical()
    scene_script=ROOT/"tools/match3d-v25-lab/remote/godot_canonical_probe.gd"
    canonical=command("kickback-canonical-53-rig",[str(binary),"--headless",
        "--path",str(directory),"--script",str(scene_script),"--",
        str(OUT/"canonical-import.json"),*input_paths],timeout=360)
    # Two full canonical characters per LOD. Run ACTUAL Godot Jolt bodies,
    # Kickback spring tracking and a deterministic hit. Distinct from a
    # rugby tackle qualification, and no assets are written to the game.
    physical=command("kickback-real-ragdoll-3lod",[
        str(binary),"--headless","--path",str(directory),"--script",
        str(ROOT/"tools/match3d-v25-lab/remote/godot_real_ragdoll_probe.gd"),"--",
        str(OUT/"real-ragdoll-3lod.json"),*input_paths],timeout=480) if canonical["status"]=="PASS" else {"status":"SKIP"}
    if "--idle-only" in sys.argv:
        # Paired tackle is previously rejected; isolate target-vs-physics
        # WITHOUT impulses, joints or root movement. Do not conflate its
        # expected failures with a failed experiment execution.
        idle=command("kickback-idle-stability-3lod",[
            "xvfb-run","-a","-s","-screen 0 800x450x24",
            str(binary),"--rendering-driver","opengl3",
            "--rendering-method","gl_compatibility",
            "--path",str(directory),"--script",
            str(ROOT/"tools/match3d-v25-lab/remote/godot_idle_stability_probe.gd"),"--",
            str(OUT/"idle-stability-3lod.json"),*input_paths,"visual"],timeout=650)
        verdict={"version":version["status"],"upstreamGodotImport":imported["status"],
                 "upstreamGutTests":upstream["status"],"ourThreeCanonRigs":canonical["status"],
                 "historicalTwoRigImpact":physical["status"],"idleDiagnostic":idle["status"],
                 "qualification":"NOT_APPROVED_UNTIL_IDLE_STABILITY_AND_SKIN_CONTACT",
                 "limitations":"Diagnostic per-mode FAIL_UNSTABLE is expected, not an approved tackle"}
        (OUT/"godot-test-verdict.json").write_text(json.dumps(verdict,indent=2)+"\n")
        assert all(verdict[k]=="PASS" for k in
            ("version","upstreamGodotImport","upstreamGutTests","ourThreeCanonRigs","historicalTwoRigImpact","idleDiagnostic")),verdict
        return
    paired=command("kickback-paired-tackle-3lod",[
        str(binary),"--headless","--path",str(directory),"--script",
        str(ROOT/"tools/match3d-v25-lab/remote/godot_paired_tackle_probe.gd"),"--",
        str(OUT/"paired-tackle-3lod.json"),*input_paths],timeout=480) if physical["status"]=="PASS" else {"status":"SKIP"}
    # Re-run the IDENTICAL paired scenarios with an actual software OpenGL
    # renderer in Xvfb, saving skinned GLB face/side screenshots at five phases.
    # Never claim rendered visuals from the headless/null-renderer run.
    render=command("kickback-paired-render-3lod",[
        "xvfb-run","-a","-s","-screen 0 800x450x24",
        str(binary),"--rendering-driver","opengl3",
        "--rendering-method","gl_compatibility",
        "--path",str(directory),"--script",
        str(ROOT/"tools/match3d-v25-lab/remote/godot_paired_tackle_probe.gd"),"--",
        str(OUT/"paired-render-3lod.json"),*input_paths,"visual"],timeout=480) if paired["status"]=="PASS" else {"status":"SKIP"}
    verdict={"version":version["status"],"upstreamGodotImport":imported["status"],
             "upstreamGutTests":upstream["status"],"ourThreeCanonRigs":canonical["status"],
             "realTwoRigJoltImpacts":physical["status"],
             "realPairedControlImpactGrip":paired["status"],
             "pairedRealGlbFaceSideRendering":render["status"],
             "licensing":"Kickback MIT; no Kickback source copied to V24",
             "limitations":"Physical hit smoke is NOT a qualified rugby grasp, skin collision approval or Three.js port"}
    (OUT/"godot-test-verdict.json").write_text(json.dumps(verdict,indent=2)+"\n")
    assert all(v=="PASS" for k,v in verdict.items() if k in
               ("version","upstreamGodotImport","upstreamGutTests","ourThreeCanonRigs","realTwoRigJoltImpacts","realPairedControlImpactGrip","pairedRealGlbFaceSideRendering")),verdict

def main():
    try:
        audit_sources()
        run_godot()
        status={"status":"PASS","tests":"UPSTREAM_GODOT_AND_REAL_CANONICAL_GLBS"}
    except Exception as e:
        status={"status":"FAIL","error":str(e)}
        raise
    finally:
        (OUT/"verdict.json").write_text(json.dumps(status,indent=2)+"\n")
if __name__=="__main__":main()
