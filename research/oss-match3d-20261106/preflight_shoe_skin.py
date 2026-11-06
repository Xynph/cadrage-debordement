"""True Blender inspection of original body + shoe GLBs for all three LODs.
No rig/mesh writes. Renders nothing and never qualifies rugby gait.
"""
import bpy,hashlib,json,sys,traceback
from pathlib import Path
from mathutils import Vector
BASE=Path(sys.argv[sys.argv.index("--")+1]);LOCK=Path(sys.argv[sys.argv.index("--")+2]);OUT=Path(sys.argv[sys.argv.index("--")+3])
OUT.parent.mkdir(parents=True,exist_ok=True)
lock=json.loads(LOCK.read_text())
report={"schema":"cd-oss-real-shoes-preflight-v1","lods":[],"qualified":False,"errors":[]}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def require(ok,msg):
    if not ok:raise RuntimeError(msg)
def skin_regions(meshes):
    out={"foot_l":{"vertices":0,"minZ":None},"foot_r":{"vertices":0,"minZ":None}}
    deps=bpy.context.evaluated_depsgraph_get()
    for obj in meshes:
        feet={side:{g.index for g in obj.vertex_groups if g.name in ("foot_"+side,"ball_"+side)} for side in ("l","r")}
        evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh()
        try:
            require(len(mesh.vertices)==len(obj.data.vertices),"evaluated topology mismatch")
            for i,p in enumerate(mesh.vertices):
                memberships=obj.data.vertices[i].groups
                for side in ("l","r"):
                    if not any(g.group in feet[side] and g.weight>=.5 for g in memberships):continue
                    val=out["foot_"+side]
                    z=(evaluated.matrix_world@p.co).z
                    val["vertices"]+=1
                    val["minZ"]=min(z,val["minZ"]) if val["minZ"] is not None else z
        finally:evaluated.to_mesh_clear()
    return out
def read_glb(lod,kind):
    rel=f"lod/{'base_body_anim' if kind=='body' else 'clothing_shoes'}-lod{lod}.glb"
    file=BASE/"dist/match3d/assets/rugby-v24"/rel
    require(file.is_file(),"missing original GLB "+rel)
    digest=sha(file)
    require(digest==lock["baselineSha256"][rel],"original GLB SHA mismatch "+rel)
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(file))
    objs=[obj for obj in bpy.data.objects if obj not in before]
    rigs=[x for x in objs if x.type=="ARMATURE"]
    meshes=[x for x in objs if x.type=="MESH" and x.vertex_groups and any(
        m.type=="ARMATURE" and m.object is not None for m in x.modifiers)]
    return {"rel":rel,"sha256":digest,"objects":objs,"rigs":rigs,"meshes":meshes}
try:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for lod in range(3):
        body=read_glb(lod,"body");shoe=read_glb(lod,"shoe")
        row={"lod":lod,"assets":{kind:asset["sha256"] for kind,asset in (("body",body),("shoe",shoe))},
             "bodyRigCount":len(body["rigs"]),"shoeRigCount":len(shoe["rigs"]),
             "shoeMeshCount":len(shoe["meshes"]),"issues":[]}
        report["lods"].append(row)
        if len(body["rigs"])!=1 or len(body["rigs"][0].data.bones)!=53:
            row["issues"].append("Body original canonical 53-bone rig not found")
        if len(shoe["rigs"])!=1:
            row["issues"].append("Shoe GLB has no unique rig: cannot assume weights match")
        if not shoe["meshes"]:
            row["issues"].append("No skinned shoe mesh with armature modifier")
        if len(body["rigs"])==1 and len(shoe["rigs"])==1:
            b=body["rigs"][0];s=shoe["rigs"][0]
            bn=set(b.data.bones.keys());sn=set(s.data.bones.keys())
            row["bodyBones"]=len(bn);row["shoeBones"]=len(sn)
            row["bonesInBodyNotShoe"]=sorted(bn-sn)
            row["bonesInShoeNotBody"]=sorted(sn-bn)
            row["minRestMatrixMaxElementError"]=None
            if bn==sn and len(sn)==53:
                errors=[max(abs(a-bb) for rowa,rowb in zip(b.data.bones[name].matrix_local,s.data.bones[name].matrix_local)
                    for a,bb in zip(rowa,rowb)) for name in bn]
                row["maxRestMatrixElementError"]=max(errors)
                if max(errors)>1e-3:row["issues"].append("Body/shoe bind skeleton rest transforms mismatch >1e-3")
            else:row["issues"].append("Shoe GLB 53-bone mapping differs from body")
        if shoe["meshes"]:
            row["shoeTrueSkinnedFoot"]=skin_regions(shoe["meshes"])
            for name,vals in row["shoeTrueSkinnedFoot"].items():
                if vals["vertices"]<10:row["issues"].append("insufficient true shoe weighted vertices for "+name)
        if body["meshes"]:row["bodyTrueSkinnedFoot"]=skin_regions(body["meshes"])
        for obj in body["objects"]+shoe["objects"]:
            if obj.name in bpy.data.objects:bpy.data.objects.remove(obj,do_unlink=True)
    report["qualified"]=len(report["lods"])==3 and all(not x["issues"] for x in report["lods"])
except Exception as error:
    report["errors"].append(str(error));report["traceback"]=traceback.format_exc()
finally:
    report["status"]="PASS_SHOES_SKIN_RIG_MATCH" if report["qualified"] else "BLOCKED_SHOES_SKIN_INTEGRATION"
    OUT.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"status":report["status"],"lods":len(report["lods"]),
                      "issues":[{"lod":x["lod"],"issues":x["issues"]} for x in report["lods"]],
                      "errors":report["errors"]}),flush=True)
if not report["qualified"]:sys.exit(1)
