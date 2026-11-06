"""Surface-to-surface proximity probe for real skinned rugby v24 meshes.
No collision certification: nearest sampled vertices have unsigned distances.
This independent qualification test deliberately does not mutate runtime or GLBs.
"""
import json
from pathlib import Path

def summarize_surface_samples(left, right):
    """Compute unsigned nearest-neighbour gaps from world-space 3D vertex lists."""
    if len(left)<10 or len(right)<10:
        raise ValueError("Insufficient real skinned torso samples")
    def distance(a,b):
        return sum((x-y)**2 for x,y in zip(a,b))**.5
    closest=[min(distance(a,b) for b in right) for a in left]
    return {'samples':[len(left),len(right)],'minimumMetres':min(closest),
            'meanMetres':sum(closest)/len(closest),
            'warning':'Unsigned vertex distances do not prove nonpenetration'}

if __name__=='__main__':
    a=[[i*.001,0,0] for i in range(20)]
    b=[[i*.001,.1,0] for i in range(20)]
    report=summarize_surface_samples(a,b)
    assert abs(report['minimumMetres']-.1)<1e-8
    print(json.dumps(report))
