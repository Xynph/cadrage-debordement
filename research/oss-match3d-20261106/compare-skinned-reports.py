"""Fail-closed structural comparison of true-skinned-foot evidence reports.
This does NOT authenticate the origin of GLB, images, or evidence files.
"""
import json, math, sys
from pathlib import Path

LODS = ("lod0", "lod1", "lod2")
FRAMES = [1,10,18,22,24,26,28,30,32,34,36,38,40,45,50,60,70,80,90]
VIEWS = ["front", "profile", "threequarter"]

def require(condition, message):
    if not condition:
        raise ValueError(message)

def number(value, name):
    require(type(value) in (float, int) and math.isfinite(value), name + ": missing/nonfinite")
    return float(value)

def digest(value, name):
    require(isinstance(value, str) and len(value) == 64 and
            all(c in "0123456789abcdef" for c in value), name + ": invalid SHA256")

def load_report(filename):
    report = json.loads(Path(filename).read_text(encoding="utf-8"))
    require(report.get("schema") == "cd-skinned-comparison-v1", "wrong schema")
    require(report.get("source") == "actual-evaluated-skinned-vertices", "no true skin")
    require(report.get("rig_bone_count") == 53, "wrong bone count")
    require(report.get("frames") == FRAMES and report.get("views") == VIEWS, "wrong temporal/view coverage")
    for k in ("scene_root_motion_unchanged", "auxiliary_excluded_by_provenance", "glb_originals_untouched"):
        require(report.get(k) is True, k + " not attested")
    require(report.get("method") in ("baseline-blender-ik", "ekza-derived-candidate"), "wrong method")
    require(isinstance(report.get("lods"), dict) and set(report["lods"]) == set(LODS), "missing LOD")
    for lod in LODS:
        d = report["lods"][lod]
        for key in ("source_glb_sha256", "bone_names_sha256"):
            digest(d.get(key), lod + "." + key)
        require(d.get("skinned_foot_vertices") is True, lod + ": proxy not real skin")
        require(d.get("samples") == 19 and d.get("render_views") == 57, lod + ": missing frames/images")
        require(d.get("visual_review") in ("approved", "rejected"), lod + ": no visual review")
        for key in ("min_sole_z_cm", "max_sole_z_cm", "max_stance_xy_drift_cm",
                    "max_leg_reach_ratio", "strict_non_coplanar_crossings", "coplanar_unresolved"):
            number(d.get(key), lod + "." + key)
        require(d["strict_non_coplanar_crossings"] >= 0 and d["coplanar_unresolved"] >= 0,
                lod + ": invalid collision counts")
    return report

def compare(baseline, candidate):
    require(baseline["method"] == "baseline-blender-ik", "wrong baseline")
    require(candidate["method"] == "ekza-derived-candidate", "wrong candidate")
    checks = {}
    for lod in LODS:
        a, b = baseline["lods"][lod], candidate["lods"][lod]
        require(a["source_glb_sha256"] == b["source_glb_sha256"], lod + ": source GLB mismatch")
        require(a["bone_names_sha256"] == b["bone_names_sha256"], lod + ": 53-bone mapping mismatch")
        geometry = (
            b["min_sole_z_cm"] >= -1.0 and b["max_sole_z_cm"] <= 3.0 and
            b["max_stance_xy_drift_cm"] <= 5.0 and b["max_leg_reach_ratio"] <= 1.0 and
            b["strict_non_coplanar_crossings"] <= a["strict_non_coplanar_crossings"] and
            b["coplanar_unresolved"] <= a["coplanar_unresolved"])
        checks[lod] = {
            "geometry_qualified": geometry,
            "visual_approved": b["visual_review"] == "approved",
            "drift_delta_cm": round(b["max_stance_xy_drift_cm"] - a["max_stance_xy_drift_cm"], 5),
            "strict_crossings_delta": int(b["strict_non_coplanar_crossings"] -
                                          a["strict_non_coplanar_crossings"])}
    return {"qualified": all(c["geometry_qualified"] and c["visual_approved"] for c in checks.values()),
            "lods": checks,
            "limitation": "Structure only. GLB and image bytes and visual judgment MUST be independently verified."}

def main(args):
    if len(args) != 3:
        print("Usage: python compare-skinned-reports.py baseline.json candidate.json", file=sys.stderr)
        return 2
    try:
        result = compare(load_report(args[1]), load_report(args[2]))
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0 if result["qualified"] else 1
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(json.dumps({"qualified": False, "error": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 2

if __name__ == "__main__":
    sys.exit(main(sys.argv))
