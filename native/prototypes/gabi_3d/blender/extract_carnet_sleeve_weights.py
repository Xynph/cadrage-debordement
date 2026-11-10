"""Extract reference sleeve weights without importing a second rig."""
from pathlib import Path
import sys

import bpy
import numpy as np

out = Path(sys.argv[sys.argv.index("--") + 1])
body = bpy.data.objects["SK_Gabi"]
vertices = [v for v in body.data.vertices if v.co.x > .11 and .96 < v.co.z < 1.48]
names = np.array([g.name for g in body.vertex_groups])
coordinates = np.array([v.co[:] for v in vertices],dtype=np.float32)
weights = np.zeros((len(vertices),len(names)),dtype=np.float32)
for i,vertex in enumerate(vertices):
    for group in vertex.groups:
        weights[i,group.group] = group.weight
np.savez_compressed(out,names=names,coordinates=coordinates,weights=weights)
