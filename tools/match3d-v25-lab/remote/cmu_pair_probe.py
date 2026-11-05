"""Real, synchronized CMU two-actor motion audit. NO retargeting claimed.
The A/B 18_03+19_03 pair depicts pulling/resistance, NOT a rugby tackle.
No raw motion content is included in the archived report or commercial game.
"""
import hashlib
import json
import math
import pathlib
import re
import urllib.request

ROOT=pathlib.Path.cwd()
OUT=ROOT/"rd-report"/"external-tackle"
OUT.mkdir(parents=True,exist_ok=True)
SHA="09a07f54f3bbb58797325f009282d0b2048a2871"
BASE=f"https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/{SHA}"
CLIPS=[("A","018/18_03.bvh"),("B","019/19_03.bvh")]

def get(rel):
    url=f"{BASE}/{rel}"
    with urllib.request.urlopen(urllib.request.Request(url,headers={"User-Agent":"CD-RD/1.0"}),timeout=80) as r:
        return r.read()

def parse_bvh(content):
    lines=content.decode("utf-8").replace("\r","\n").split("\n")
    header=next(i for i,line in enumerate(lines) if line.strip()=="MOTION")
    names=[re.search(r"^\s*(?:ROOT|JOINT)\s+(\S+)",x).group(1)
           for x in lines[:header] if re.search(r"^\s*(?:ROOT|JOINT)\s+(\S+)",x)]
    channels=[int(re.search(r"CHANNELS\s+(\d+)",x).group(1))
              for x in lines[:header] if "CHANNELS" in x]
    count=sum(channels)
    assert len(names)>20 and len(names)==len(channels),("Invalid BVH hierarchy",len(names),len(channels))
    frames=int(re.search(r"Frames:\s*(\d+)",lines[header+1]).group(1))
    timestep=float(re.search(r"Frame Time:\s*([\d.]+)",lines[header+2]).group(1))
    motion=[]
    for line in lines[header+3:]:
        if not line.strip():continue
        fields=[float(v) for v in line.split()]
        if len(fields)!=count:raise AssertionError(("Unexpected BVH channels",len(fields),count))
        motion.append(fields)
    assert len(motion)==frames and all(math.isfinite(x) for row in motion for x in row)
    # BVH root channels are explicitly XYZ position followed by ZYX rotation.
    assert "ROOT Hips" in content[:200].decode("utf-8")
    assert [x.lower() for x in names[:2]]==["hips","lhipjoint"],names[:2]
    assert 90<=1/timestep<=130,(frames,timestep)
    root=[row[:3] for row in motion]
    return dict(frames=frames,timestep=timestep,channels=count,bones=names,
                rootPositionFirst=root[0],rootPositionLast=root[-1],rootPositions=root,
                durationSec=frames*timestep)

def main():
    rights=get("READMEFIRST.txt")
    assert b"USAGE RIGHTS" in rights and b"no additional restrictions" in rights
    result={"schema":1,"status":"FAIL","source":"CMU / Bruce Hahne BVH conversion",
        "sourceGitCommit":SHA,
        "sourceRightsSha256":hashlib.sha256(rights).hexdigest(),
        "clipDescription":"A pulls B; B resists, two subjects A+B",
        "isRugbyTackle":False,"retargetedOnto53Bones":False,"rendersProduced":False,
        "clips":[]}
    clips=[]
    for label,path in CLIPS:
        content=get("data/"+path)
        clip=parse_bvh(content)
        clips.append(clip)
        result["clips"].append({k:v for k,v in clip.items() if k!="rootPositions"}|
              {"actor":label,"path":path,"sizeBytes":len(content),
               "sha256":hashlib.sha256(content).hexdigest()})
    assert clips[0]["frames"]==clips[1]["frames"],"Pair not synchronized in frame count"
    assert abs(clips[0]["timestep"]-clips[1]["timestep"])<1e-8,"Pair frame rate differs"
    scale=0.01 # BVH units converted to metres (nominal; verify actor scale before use)
    distances=[math.dist(a[:3],b[:3])*scale for a,b in zip(
        clips[0]["rootPositions"],clips[1]["rootPositions"])]
    assert max(distances)-min(distances)>.02,"No measurable inter-actor relative motion"
    result["interActorRootDistancesNominalMetres"]={
        "first":round(distances[0],5),"mid":round(distances[len(distances)//2],5),
        "last":round(distances[-1],5),"min":round(min(distances),5),
        "max":round(max(distances),5),
        "scaleAssumption":"Nominal centimetres; do NOT use as metric contact truth"}
    result["status"]="PASS_PAIRED_SOURCE_ONLY_NOT_RETARGETED"
    (OUT/"cmu-two-actor-pull-source.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps({"status":result["status"],"frames":clips[0]["frames"],
        "durationSec":clips[0]["durationSec"],"sourceSha":SHA,
        "actorSeparation":result["interActorRootDistancesNominalMetres"]}))
if __name__=="__main__":main()
