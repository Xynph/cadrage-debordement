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


def fixture(path, points=None, normals=None, indices=None, material='cloth', uvs=None, amend=None):
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
    attributes={'POSITION':p,'NORMAL':n,'JOINTS_0':j,'WEIGHTS_0':w}
    if uvs is not None:
        attributes['TEXCOORD_0']=add(uvs,'VEC2')
    doc={'asset':{'version':'2.0'},'buffers':[{'byteLength':len(binary)}], 'bufferViews':views,'accessors':accessors,
         'nodes':[{'name':'root','children':[1,2]},{'name':'Head'},{'name':'mesh','mesh':0,'skin':0}],
         'skins':[{'joints':[1],'inverseBindMatrices':ib}], 'materials':[{'name':material}],
         'meshes':[{'primitives':[{'attributes':attributes,'indices':ix,'material':0}]}]}
    if amend:
        amend(doc)
    encoded=json.dumps(doc).encode();encoded+=b' '*(-len(encoded)%4)
    body=struct.pack('<II',len(encoded),0x4E4F534A)+encoded+struct.pack('<II',len(binary),0x004E4942)+binary
    path.write_bytes(struct.pack('<III',0x46546C67,2,12+len(body))+body)


class NormalPreservation(unittest.TestCase):
    def test_exact_split_vertices_are_compacted_without_changing_corners(self):
        with tempfile.TemporaryDirectory() as td:
            source,candidate=Path(td)/'source.glb',Path(td)/'candidate.glb'
            points=[[0,0,0],[1,0,0],[0,1,0]]
            uvs=[[0,0],[1,0],[0,1]]
            fixture(source,points=points,indices=[0,1,2,0,1,2],uvs=uvs)
            fixture(candidate,points=points+[points[0]],indices=[3,1,2,0,1,2],uvs=uvs+[uvs[0]])

            def corners(mesh):
                primitive=mesh.d['meshes'][0]['primitives'][0]
                indices=mesh.acc(primitive['indices']).ravel()
                return {name:mesh.acc(index)[indices].tobytes() for name,index in primitive['attributes'].items()}

            before=corners(Glb(candidate))
            report=restore_source_normals(source,candidate)
            self.assertEqual(report['compacted_vertices_by_material'],{'cloth':1})
            result=Glb(candidate)
            primitive=result.d['meshes'][0]['primitives'][0]
            self.assertEqual(len(result.acc(primitive['attributes']['POSITION'])),3)
            self.assertEqual(corners(result),before)

    def test_repaired_face_receipt_points_to_final_compacted_indices(self):
        with tempfile.TemporaryDirectory() as td:
            source,candidate=Path(td)/'source.glb',Path(td)/'candidate.glb'
            points=[[0,0,0],[1,0,0],[0,1,0]]
            fixture(source,points=points,indices=[0,1,2,0,1,2,0,0,2])
            fixture(candidate,points=[points[0]]+points,indices=[0,2,3,1,2,3])
            report=restore_source_normals(source,candidate)
            result=Glb(candidate)
            primitive=result.d['meshes'][0]['primitives'][0]
            repair=report['restoredRepeatedIndexDegenerateTriangles'][0]
            self.assertEqual(repair['candidate_local_indices'],[0,0,2])
            self.assertEqual(result.acc(primitive['indices']).ravel().tolist()[-3:],[0,0,2])

    def test_normal_accessor_shared_with_unskinned_mesh_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            source,candidate=Path(td)/'source.glb',Path(td)/'candidate.glb'
            fixture(source)

            def share_normal(doc):
                doc['meshes'].append(copy.deepcopy(doc['meshes'][0]))
                doc['nodes'].append({'mesh':1})

            fixture(candidate,normals=[[0.1,0,0.9949874]]*3,amend=share_normal)
            before=candidate.read_bytes()
            with self.assertRaisesRegex(ValueError,'aliases'):
                restore_source_normals(source,candidate)
            self.assertEqual(candidate.read_bytes(),before)

    def test_distinct_normal_accessors_cannot_write_the_same_bytes(self):
        with tempfile.TemporaryDirectory() as td:
            source,candidate=Path(td)/'source.glb',Path(td)/'candidate.glb'

            def second_material(doc, alias=False):
                primitive=copy.deepcopy(doc['meshes'][0]['primitives'][0])
                doc['materials'].append({'name':'lining'})
                primitive['material']=1
                if alias:
                    normal=primitive['attributes']['NORMAL']
                    primitive['attributes']['NORMAL']=len(doc['accessors'])
                    doc['accessors'].append(dict(doc['accessors'][normal]))
                doc['meshes'][0]['primitives'].append(primitive)

            fixture(source,amend=second_material)
            fixture(candidate,amend=lambda doc:second_material(doc,alias=True))
            before=candidate.read_bytes()
            with self.assertRaisesRegex(ValueError,'normal accessors share'):
                restore_source_normals(source,candidate)
            self.assertEqual(candidate.read_bytes(),before)

    def test_compaction_refuses_a_distinct_uv_or_new_repeated_corner(self):
        with tempfile.TemporaryDirectory() as td:
            source,candidate=Path(td)/'source.glb',Path(td)/'candidate.glb'
            points=[[0,0,0],[1,0,0],[0,1,0]]
            uvs=[[0,0],[1,0],[0,1]]
            for src_indices,candidate_indices,extra_uv in [
                ([0,1,2,0,1,2],[3,1,2,0,1,2],[0.25,0]),
                ([0,1,2,0,0,1],[0,1,2,0,3,1],[0,0]),
            ]:
                fixture(source,points=points,indices=src_indices,uvs=uvs)
                fixture(candidate,points=points+[points[0]],indices=candidate_indices,uvs=uvs+[extra_uv])
                before=candidate.read_bytes()
                with self.subTest(extra_uv=extra_uv),self.assertRaisesRegex(ValueError,'Vertex compaction'):
                    restore_source_normals(source,candidate)
                self.assertEqual(candidate.read_bytes(),before)

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
