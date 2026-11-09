"""Attribute/topology preservation controls; no Blender or game profile required."""
import copy
import json
from pathlib import Path
import struct
import tempfile
import unittest
import numpy as np
from restore_normals import restore_source_normals
from skin_math import Glb


def fixture(path, points=None, normals=None, indices=None, material='cloth'):
    points=points or [[0,0,0],[1,0,0],[0,1,0]]
    normals=normals or [[0,0,1]]*len(points)
    indices=indices or [0,1,2]
    binary=bytearray(); accessors=[]; views=[]
    def add(values,kind,component=5126):
        flat=np.asarray(values).ravel().tolist(); fmt='f' if component==5126 else 'I'
        binary.extend(b'\0'*(-len(binary)%4));offset=len(binary)
        binary.extend(struct.pack('<'+fmt*len(flat),*flat))
        views.append({'buffer':0,'byteOffset':offset,'byteLength':struct.calcsize(fmt)*len(flat)})
        count=len(values)
        accessors.append({'bufferView':len(views)-1,'componentType':component,'count':count,'type':kind})
        return len(accessors)-1
    p=add(points,'VEC3');n=add(normals,'VEC3');j=add([[0]*4]*len(points),'VEC4',5125)
    w=add([[1,0,0,0]]*len(points),'VEC4');ix=add(indices,'SCALAR',5125)
    ib=add([np.eye(4).ravel().tolist()],'MAT4')
    doc={'asset':{'version':'2.0'},'buffers':[{'byteLength':len(binary)}], 'bufferViews':views,'accessors':accessors,
         'nodes':[{'name':'root','children':[1,2]},{'name':'Head'},{'name':'mesh','mesh':0,'skin':0}],
         'skins':[{'joints':[1],'inverseBindMatrices':ib}], 'materials':[{'name':material}],
         'meshes':[{'primitives':[{'attributes':{'POSITION':p,'NORMAL':n,'JOINTS_0':j,'WEIGHTS_0':w},'indices':ix,'material':0}]}]}
    encoded=json.dumps(doc).encode();encoded+=b' '*(-len(encoded)%4)
    body=struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(binary),0x004E4942)+binary
    path.write_bytes(struct.pack('<III',0x46546C67,2,12+len(body))+body)


class NormalPreservation(unittest.TestCase):
    def test_normals_only_and_exact_degenerate_repair(self):
        with tempfile.TemporaryDirectory() as td:
            source,candidate=Path(td)/'source.glb',Path(td)/'candidate.glb'
            fixture(source,indices=[0,1,2,0,0,1])
            fixture(candidate,normals=[[0.1,0,0.9949874]]*3)
            before=Glb(candidate).acc(0).copy();source_bytes=source.read_bytes()
            result=restore_source_normals(source,candidate)
            self.assertTrue(result['preservationSourceNormals'])
            self.assertEqual(result['restoredRepeatedIndexDegenerateTriangles'][0]['count'],1)
            self.assertTrue(np.array_equal(Glb(candidate).acc(0),before))
            self.assertTrue(np.array_equal(Glb(candidate).acc(1),Glb(source).acc(1)))
            self.assertEqual(source.read_bytes(),source_bytes)

    def test_degenerate_repair_uses_the_right_normal_seam(self):
        with tempfile.TemporaryDirectory() as td:
            source,candidate=Path(td)/'source.glb',Path(td)/'candidate.glb'
            points=[[0,0,0],[1,0,0],[0,1,0],[0,0,0],[0,1,0],[0,0,1]]
            normals=[[0,0,1]]*3+[[1,0,0]]*3
            fixture(source,points=points,normals=normals,indices=[0,1,2,3,4,5,3,3,5])
            fixture(candidate,points=points,normals=normals,indices=[0,1,2,3,4,5])
            result=restore_source_normals(source,candidate)
            repair=result['restoredRepeatedIndexDegenerateTriangles'][0]
            self.assertEqual(set(repair['candidate_local_indices']),{3,5})
            g=Glb(candidate)
            for index in repair['candidate_local_indices']:
                self.assertTrue(np.array_equal(g.acc(1)[index],[1,0,0]))

    def test_artwork_or_topology_changes_fail_without_writing(self):
        with tempfile.TemporaryDirectory() as td:
            source,candidate=Path(td)/'source.glb',Path(td)/'candidate.glb'
            fixture(source)
            for kwargs in [dict(points=[[0,0,0],[1.1,0,0],[0,1,0]]),dict(indices=[0,2,1]),
                           dict(indices=[0,1,2,0,1,2]),dict(material='changed')]:
                fixture(candidate,**kwargs);before=candidate.read_bytes()
                with self.subTest(kwargs=kwargs),self.assertRaises(ValueError):
                    restore_source_normals(source,candidate)
                self.assertEqual(before,candidate.read_bytes())

    def test_coincident_source_faces_with_distinct_normals_are_ambiguous(self):
        with tempfile.TemporaryDirectory() as td:
            source,candidate=Path(td)/'source.glb',Path(td)/'candidate.glb'
            pts=[[0,0,0],[1,0,0],[0,1,0]]
            fixture(source,points=pts+pts,normals=[[0,0,1]]*3+[[1,0,0]]*3,indices=[0,1,2,3,4,5])
            fixture(candidate);before=candidate.read_bytes()
            with self.assertRaisesRegex(ValueError,'Ambiguous'):
                restore_source_normals(source,candidate)
            self.assertEqual(before,candidate.read_bytes())


if __name__=='__main__':unittest.main()
