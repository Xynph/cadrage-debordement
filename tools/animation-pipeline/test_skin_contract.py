"""Pure fixed-corner contract tests; no Blender/Godot/download or input writes."""
import unittest
import tempfile
import struct
from pathlib import Path
import numpy as np
from compare_skin import match_oriented_corners, validate_skin_scope, compare
from skin_math import Glb
from types import SimpleNamespace

class SkinFaceContract(unittest.TestCase):
 def test_ignored_geometry_is_explicitly_refused(self):
  base={'skins':[{'joints':[0]}],'meshes':[{'primitives':[]}],'animations':[]}
  good=SimpleNamespace(d=base,nodes=[{'name':'Root','mesh':0,'skin':0}])
  validate_skin_scope(good)
  with self.assertRaises(ValueError):validate_skin_scope(SimpleNamespace(d=base,nodes=good.nodes+[{'mesh':0}]))
  morph={**base,'meshes':[{'primitives':[{'targets':[{}]}]}]}
  with self.assertRaises(ValueError):validate_skin_scope(SimpleNamespace(d=morph,nodes=good.nodes))
 def test_nonfinite_animated_translation_is_refused(self):
  source=Path(__file__).resolve().parents[2]/'native/godot/assets/match3d/quaternius-rugby-athlete.glb'
  glb=Glb(source)
  output=None
  for animation in glb.d['animations']:
   for channel in animation['channels']:
    if channel['target']['path']=='translation':
     output=animation['samplers'][channel['sampler']]['output'];break
   if output is not None:break
  self.assertIsNotNone(output,'Real fixture must contain translation keys')
  accessor=glb.d['accessors'][output];view=glb.d['bufferViews'][accessor['bufferView']]
  raw=bytearray(source.read_bytes());json_size=struct.unpack_from('<I',raw,12)[0]
  offset=28+json_size+view.get('byteOffset',0)+accessor.get('byteOffset',0)
  struct.pack_into('<f',raw,offset,float('nan'))
  with tempfile.TemporaryDirectory() as td:
   candidate=Path(td)/'nan-translation.glb';candidate.write_bytes(raw)
   with self.assertRaisesRegex(ValueError,'Non-finite animated geometry'):
    compare(source,candidate)
 def test_identity_cyclic_winding_and_missing_or_extra_faces(self):
  faces=[('kit',(0,1,2)),('kit',(0,2,3))]
  matches=[{i} for i in range(4)];normals=np.tile([0.,0.,1.],(4,1))
  for target,accepted in [(faces,True),([('kit',(1,2,0)),('kit',(2,3,0))],True),([('kit',(0,2,1)),faces[1]],False),(faces+[faces[0]],False),(faces[:1],False),([('kit',(0,1,3)),faces[1]],False)]:
   with self.subTest(target=target):
    r=match_oriented_corners(faces,target,matches,normals,normals)
    self.assertEqual(r['oriented_faces_equal'],accepted)
    self.assertEqual(r['corner_normals_equal'],accepted)
 def test_normal_swap_between_coincident_seams_is_not_a_match(self):
  faces=[('kit',(0,1,2)),('kit',(3,4,5))]
  matches=[{0,3},{1},{2},{0,3},{4},{5}]
  source=np.array([[0.,0.,1.]]*3+[[1.,0.,0.]]*3)
  target=source.copy();target[[0,3]]=target[[3,0]]
  r=match_oriented_corners(faces,faces,matches,source,target)
  self.assertTrue(r['oriented_faces_equal'])
  self.assertFalse(r['corner_normals_equal'])
 def test_duplicate_faces_are_matched_one_to_one_not_greedily(self):
  faces=[('kit',(0,1,2)),('kit',(3,4,5))]
  matches=[{0,3},{1,4},{2,5}]*2
  normals=np.array([[0.,0.,1.]]*3+[[1.,0.,0.]]*3)
  r=match_oriented_corners(faces,faces,matches,normals,normals)
  self.assertTrue(r['corner_normals_equal']);self.assertEqual(r['matched_normal_faces'],2)
 def test_degenerate_faces_keep_multiplicity_and_material(self):
  faces=[('shoe',(0,0,1))];matches=[{0},{1}];normals=np.tile([0.,0.,1.],(2,1))
  self.assertTrue(match_oriented_corners(faces,faces,matches,normals,normals)['corner_normals_equal'])
  self.assertFalse(match_oriented_corners(faces,[('kit',(0,0,1))],matches,normals,normals)['oriented_faces_equal'])
 def test_normal_tolerance_is_not_relaxed(self):
  faces=[('kit',(0,1,2))];matches=[{0},{1},{2}];source=np.tile([0.,0.,1.],(3,1))
  for angle,accepted in [(0.0009,True),(0.0011,False)]:
   target=np.tile([np.sin(angle),0.,np.cos(angle)],(3,1))
   self.assertEqual(match_oriented_corners(faces,faces,matches,source,target)['corner_normals_equal'],accepted)

if __name__=='__main__':unittest.main()
