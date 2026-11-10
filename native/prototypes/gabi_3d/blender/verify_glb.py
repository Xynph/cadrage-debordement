import bpy
import json
import math
import struct
import sys
from pathlib import Path

p = Path(sys.argv[sys.argv.index("--")+1])
header = p.read_bytes()
magic, version, size, json_len, chunk_type = struct.unpack_from("<4sIII4s", header)
assert magic == b"glTF" and version == 2 and size == len(header) and chunk_type == b"JSON"
gltf = json.loads(header[20:20+json_len])
assert len(gltf["skins"]) == 1 and len(gltf["images"]) == 2
assert len(gltf["meshes"]) == 3 and len(gltf["materials"]) == 9
assert {a["name"] for a in gltf["animations"]} == {"Approbation", "Parole", "Repos"}
assert len(gltf["skins"][0]["joints"]) == 20
assert p.stat().st_size < 5_500_000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(p))
rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
body = bpy.data.objects["SK_Gabi"]
assert set(body.data.shape_keys.key_blocks.keys()) == {
    "Basis", "Machoire", "Paupiere_Mi", "Paupiere_Fermee",
    "ArrondiPhrase", "OuverturePhrase", "EtirementPhrase",
}
for name in ("Globe_L", "Globe_R"):
    eye = bpy.data.objects[name]
    assert len(eye.data.polygons) == 1280
    assert set(eye.data.shape_keys.key_blocks.keys()) == {
        "Basis", "Paupiere_Mi", "Paupiere_Fermee",
    }
    assert all(len(vert.groups) == 1 and eye.vertex_groups[vert.groups[0].group].name == "Head"
               for vert in eye.data.vertices)
assert len(rig.data.bones) == 20
assert math.isclose(body.dimensions.z, 1.8, abs_tol=.001)
max_groups = max(len(vertex.groups) for vertex in body.data.vertices)
assert max_groups <= 4
assert all(abs(sum(group.weight for group in vertex.groups) - 1) < .0001
           for vertex in body.data.vertices)
print(json.dumps({"bytes": p.stat().st_size, "animations": sorted(a["name"] for a in gltf["animations"]),
                  "triangles": len(body.data.polygons), "height_m": body.dimensions.z,
                  "bones": len(rig.data.bones), "max_influences": max_groups,
                  "images": len(gltf["images"])}))
