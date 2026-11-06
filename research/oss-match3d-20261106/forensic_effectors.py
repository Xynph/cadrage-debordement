"""Forensic read-only measurement of authentic V25 stance effectors (not a solver).
Consumes SHA-verified 19-frame observations and original three-LOD GLB rest hierarchy.
No root, pin, target, armature, mesh or animation is modified.
"""
import json, math, os, hashlib
from pathlib import Path
src=Path(os.environ["CD_V25_REAL_FRAMES"])
rig=Path(os.environ["CD_GLB_REST"])
out=Path(os.environ["CD_EFFECTOR_OUT"])
samples=json.loads(src.read_text())
rest=json.loads(rig.read_text())
assert samples["schema"]=="cd-v25-temporal-real-v1" and len(samples["samples"])==57
assert len(rest["lods"])==3
def p(m):
    assert len(m)==16
    # Authentic Blender exporter stores m[col][row]; transposed from matrix row-major.
    # Translation occupies indices 3,7,11 in this exporter (m[row][column] flattened as m[col][row]).
    return [float(m[i]) for i in (3,7,11)]
def d(a,b): return math.dist(a,b)
rows=[]; critical=None
for sample in samples["samples"]:
    lod=sample["lod"]
    for actor_name, actor in sample["actors"].items():
        bones=actor["bones"]
        for side in ("l","r"):
            h=p(bones["thigh_"+side]["world"]);k=p(bones["calf_"+side]["world"])
            a=p(bones["foot_"+side]["world"])
            ball=p(bones["ball_"+side]["world"]) if "ball_"+side in bones else None
            rests={name:p(bones[name+"_"+side]["restWorld"]) for name in ("thigh","calf","foot")}
            upper=d(rests["thigh"],rests["calf"])
            lower=d(rests["calf"],rests["foot"])
            lock=next((x for x in actor["stanceLocks"] if x["side"]==side),None)
            target=p(lock["authoredTargetWorld"]) if lock else None
            row={"lod":lod,"actor":actor_name,"frame":sample["frame"],"side":side,
                 "hip":h,"knee":k,"ankle":a,"ball":ball,
                 "target":target,"influence":lock["influence"] if lock else None,
                 "upperRestM":upper,"lowerRestM":lower,"twoSegmentRestReachM":upper+lower,
                 "hipToAnkleM":d(h,a),"hipToTargetM":d(h,target) if target else None,
                 "ankleToTargetM":d(a,target) if target else None,
                 "ankleToBallM":d(a,ball) if ball else None,\n                 "ballToTargetM":d(ball,target) if ball and target else None,\n                 "anatomicalAnkleForSameBallPin":([a[i]+target[i]-ball[i] for i in range(3)] if ball and target else None),\n                 "hipToAnatomicalAnkleForSameBallPinM":(d(h,[a[i]+target[i]-ball[i] for i in range(3)]) if ball and target else None),
                 "anklePlusFootTargetGapM":(d(h,target)-(upper+lower)) if target else None,
                 "actorRootWorldSha256":hashlib.sha256(json.dumps(actor["actorRootWorld"]).encode()).hexdigest()}
            rows.append(row)
            if (lod,actor_name,sample["frame"],side)==(0,"A",22,"l"):
                critical=row
assert len(rows)==228 and critical is not None
assert abs(critical["hipToTargetM"]-0.805630074354069)<0.00002,critical
# Rest length in the same Blender sampling frame must agree with source Ekza reach.
assert abs(critical["twoSegmentRestReachM"]-0.8020380174703425)<0.00002,critical
assert critical["hipToTargetM"]>critical["twoSegmentRestReachM"]\nassert critical["ballToTargetM"]<0.000002,critical\nassert critical["hipToAnatomicalAnkleForSameBallPinM"]<critical["twoSegmentRestReachM"],critical
# No assert that the unmeasured sole is reachable; ball is a joint, not a shoe outsole.
report={"schema":"cd-v25-anatomical-effector-audit-v1","sourceSha256":hashlib.sha256(src.read_bytes()).hexdigest(),
 "glbRestSha256":hashlib.sha256(rig.read_bytes()).hexdigest(),"status":"GEOMETRY_STOP_UNTIL_SHOE_SOLE_EFFECTOR_PROVEN",
 "observations":len(rows),"sourceFrames":len(samples["samples"]),"critical":critical,
 "byLod":[{"lod":i,\n "criticalFrame22AnkleReachGapM":(next(x for x in rows if x["lod"]==i and x["actor"]=="A" and x["frame"]==22 and x["side"]=="l")["hipToAnatomicalAnkleForSameBallPinM"]-next(x for x in rows if x["lod"]==i and x["actor"]=="A" and x["frame"]==22 and x["side"]=="l")["twoSegmentRestReachM"]),\n "activeLockMaxBallPinDeltaM":max(x["ballToTargetM"] for x in rows if x["lod"]==i and x["influence"] is not None and x["influence"]>=.99),"activeLocks":sum(x["influence"] is not None and x["influence"]>=.99 for x in rows if x["lod"]==i),
 "maxTargetExcessM":max(x["anklePlusFootTargetGapM"] for x in rows if x["lod"]==i and x["influence"] is not None)}
 for i in range(3)],
 "limitations":["Only joint and target object origins measured; target object is not asserted to be shoe outsole.",
 "Blender foot IK chain_length=3 cannot be equated to 3 collinear anatomical segment lengths.",
 "Original meshes/weights not evaluated in this job; no real skinned shoe sole geometry qualified.",
 "Calculated ankle target is an analysis-only effect of preserving the SAME fixed ball pin and original foot orientation; not a new or moved physical pin.",\n "No correction or retargeting applied: preserving baseline until anatomical offset and skinned sole are proven."],
 "rows":rows}
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(report,indent=2)+"\n")
print("FORENSIC_V25_3LOD_228_LEG_FRAME_OBSERVATIONS_PASS")
print(json.dumps({"status":report["status"],"critical":critical,"byLod":report["byLod"]},indent=2))
