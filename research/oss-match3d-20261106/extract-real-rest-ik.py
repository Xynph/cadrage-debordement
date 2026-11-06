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
    # Keep exactly the 53 original skin joints plus their original ancestors.
    # The compiler's node array is parent-before-child; glTF node IDs are retained separately.
    kept=set(joints)
    for joint in joints:
        p=parent.get(joint)
        while p is not None:
            kept.add(p)
            p=parent.get(p)
    def depth(i):
        d=0
        while i in parent:
            i=parent[i];d+=1
            assert d<len(nodes),"cycle in original glTF hierarchy"
        return d
    ordered=sorted(kept,key=lambda i:(depth(i),i))
    index={old:new for new,old in enumerate(ordered)}
    skeleton_nodes=[]
    for i in ordered:
        node=tr(i)
        skeleton_nodes.append({
            "index":index[i],"gltfIndex":i,"name":node["name"],
            "parent":index[parent[i]] if i in parent else -1,
            "restLocal":{k:node[k] for k in ("t","q","s")},
            "hasMatrix":False,"isJoint":i in joints,"hasMesh":"mesh" in nodes[i]
        })
    required_names={
        "hips":["pelvis"],"spine":["spine_01"],"chest":["spine_02"],
        "upperChest":["spine_03"],"neck":["neck_01","neck"],"head":["head"],
        "leftUpperLeg":["thigh_l"],"leftLowerLeg":["calf_l"],"leftFoot":["foot_l"],"leftToes":["ball_l"],
        "rightUpperLeg":["thigh_r"],"rightLowerLeg":["calf_r"],"rightFoot":["foot_r"],"rightToes":["ball_r"],
        "leftUpperArm":["upperarm_l"],"leftLowerArm":["lowerarm_l"],"leftHand":["hand_l"],
        "rightUpperArm":["upperarm_r"],"rightLowerArm":["lowerarm_r"],"rightHand":["hand_r"],
    }
    by_name={obj["name"]:obj["index"] for obj in skeleton_nodes}
    humanoid={}
    for human,alternates in required_names.items():
        for name in alternates:
            if name in by_name:
                humanoid[human]=by_name[name];break
    for name in ("hips","head","leftUpperLeg","leftLowerLeg","leftFoot","rightUpperLeg",
                 "rightLowerLeg","rightFoot","leftUpperArm","leftLowerArm","leftHand",
                 "rightUpperArm","rightLowerArm","rightHand"):
        assert name in humanoid,f"LOD{lod} unmapped required humanoid name: {name}"
    full={
        "format":"gltf","facing":[0,0,0,1],"nodes":skeleton_nodes,
        "humanoid":humanoid,"springJoints":[],"nodeConstraints":[],"constrainedNodes":[],
        "boneRadii":[None]*len(skeleton_nodes),"height":1.8,"heightSource":"joints",
        "fingerprint":"sha256:"+sha,"ekzaHeightScale":None,"warnings":[]
    }
    result["lods"].append({"lod":lod,"originalGlbSha256":sha,"rigBoneCount":53,
                           "sides":sides,"compiledHumanoidSkeleton":full})
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(json.dumps(result,indent=2)+"\n")
print(json.dumps({"realRestLods":len(result["lods"]),"sides":6,"source":"original glTF TRS"},indent=2))
