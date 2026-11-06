"""Read 3 exact original GLBs; emit real 53-bone rig dimensions for native Ekza tests.
No binary writes. This is NOT an animation evaluation.
"""
import hashlib,json,struct,sys
from pathlib import Path
BASE=Path(sys.argv[1]);OUT=Path(sys.argv[2])
lock=json.loads(Path(sys.argv[3]).read_text())
result={"schema":"cd-glb-53bone-ik-fixture-v1","lods":[]}
for lod in range(3):
    rel=f"lod/base_body_anim-lod{lod}.glb"
    p=BASE/"dist/match3d/assets/rugby-v24"/rel
    data=p.read_bytes()
    digest=hashlib.sha256(data).hexdigest()
    assert digest==lock["baselineSha256"][rel],f"LOD{lod} SHA mismatch"
    magic,ver,size=struct.unpack_from("<III",data,0)
    assert magic==0x46546c67 and ver==2 and size==len(data)
    json_len,json_type=struct.unpack_from("<I4s",data,12)
    assert json_type==b"JSON"
    doc=json.loads(data[20:20+json_len])
    nodes=doc["nodes"]
    joints=doc["skins"][0]["joints"]
    names=[nodes[i].get("name","") for i in joints]
    assert len(joints)==len(set(joints))==53 and len(names)==len(set(names))==53
    parent={child:idx for idx,n in enumerate(nodes) for child in n.get("children",[])}
    sides={}
    for side in ("l","r"):
        inds=[next(i for i,n in enumerate(nodes) if n.get("name")==b+"_"+side)
              for b in ("thigh","calf","foot")]
        assert parent[inds[1]]==inds[0] and parent[inds[2]]==inds[1]
        a=nodes[inds[1]].get("translation")
        b=nodes[inds[2]].get("translation")
        assert a is not None and b is not None
        l1=sum(t*t for t in a)**.5
        l2=sum(t*t for t in b)**.5
        assert .1<l1<.7 and .1<l2<.7
        sides[side]={"upperLengthM":l1,"lowerLengthM":l2,
                     "names":["thigh_"+side,"calf_"+side,"foot_"+side]}
    result["lods"].append({"lod":lod,"glbSha256":digest,"jointCount":53,
        "boneNames":names,"orderedBoneNamesSha256":hashlib.sha256(
            json.dumps(names,separators=(",",":"),ensure_ascii=False).encode()).hexdigest(),
        "sides":sides})
OUT.parent.mkdir(parents=True,exist_ok=True)
OUT.write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps({"source":"real pinned GLBs","lods":len(result["lods"]),
                  "bones":[x["jointCount"] for x in result["lods"]]},indent=2))
