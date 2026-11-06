"""Extract actual glTF rest TRS and ancestor paths from 3 locked 53-joint body GLBs.
No guess of bone axes or changes to source assets. Non-TRS nodes reject.
"""
import hashlib,json,struct,sys
from pathlib import Path
base=Path(sys.argv[1]); lock=json.loads(Path(sys.argv[2]).read_text());out=Path(sys.argv[3])
result={"schema":"cd-real-rest-trs-v1","lods":[]}
for lod in range(3):
    rel=f"lod/base_body_anim-lod{lod}.glb"
    raw=(base/"dist/match3d/assets/rugby-v24"/rel).read_bytes()
    sha=hashlib.sha256(raw).hexdigest()
    assert sha==lock["baselineSha256"][rel],f"LOD{lod} hash mismatch"
    magic,version,total=struct.unpack_from("<III",raw)
    assert (magic,version,total)==(0x46546c67,2,len(raw))
    n,kind=struct.unpack_from("<I4s",raw,12);assert kind==b"JSON"
    data=json.loads(raw[20:20+n]);nodes=data["nodes"]
    parent={c:i for i,nod in enumerate(nodes) for c in nod.get("children",[])}
    joints=data["skins"][0]["joints"]
    assert len(joints)==len(set(joints))==53
    def tr(idx):
        node=nodes[idx]
        assert "matrix" not in node,f"GLB LOD{lod} node {idx} uses matrix; no unsupported decomposition"
        t=node.get("translation",[0.,0.,0.])
        q=node.get("rotation",[0.,0.,0.,1.])
        s=node.get("scale",[1.,1.,1.])
        assert len(t)==3 and len(q)==4 and len(s)==3
        return {"t":t,"q":q,"s":s,"name":node.get("name",""),"id":idx}
    sides={}
    for side in ("l","r"):
        ix=[next(i for i in joints if nodes[i].get("name")==b+"_"+side)
            for b in ("thigh","calf","foot")]
        assert parent.get(ix[1])==ix[0] and parent.get(ix[2])==ix[1]
        ancestors=[];p=parent.get(ix[0])
        while p is not None:
            ancestors.append(p);p=parent.get(p)
            assert len(ancestors)<len(nodes)
        ancestors.reverse()
        sides[side]={"ancestors":[tr(k) for k in ancestors],
                     "upper":tr(ix[0]),"mid":tr(ix[1]),"end":tr(ix[2])}
    result["lods"].append({"lod":lod,"originalGlbSha256":sha,"rigBoneCount":53,"sides":sides})
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps({"realRestLods":len(result["lods"]),"sides":6,"source":"original glTF TRS"},indent=2))
