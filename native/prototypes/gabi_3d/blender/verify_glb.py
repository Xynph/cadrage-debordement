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
assert len(gltf["skins"]) == 1
assert len(gltf["meshes"]) == 7 and len(gltf["materials"]) == 5 and len(gltf["images"]) == 2
assert {a["name"] for a in gltf["animations"]} == {"Approbation", "Parole", "Repos"}
assert len(gltf["skins"][0]["joints"]) == 20
assert p.stat().st_size < 5_000_000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(p))
rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
body = next(obj for obj in bpy.context.scene.objects
            if obj.type == "MESH" and any(mod.type == "ARMATURE" for mod in obj.modifiers))
parts = [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name.startswith("Carnet_")]
assert len(parts) == 6 and all(part.parent_bone == "Hand.L" for part in parts)
assert sum(len(part.data.polygons) for part in parts) == 648
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
