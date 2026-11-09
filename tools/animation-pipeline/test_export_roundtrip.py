"""Guard tests run without Blender and never change a GLB input."""
import importlib.util
import os
import json
import struct
import copy
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('roundtrip', Path(__file__).with_name('export_roundtrip.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class ExportGuards(unittest.TestCase):
    def test_existing_source_destination_and_links_are_never_overwritten(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            src = root / 'source.glb'
            src.write_bytes(b'preserved input')
            existing = root / 'existing.glb'
            existing.write_bytes(b'preserved output')
            aliases = [src, existing]
            for name, create in [('hard.glb', os.link), ('sym.glb', os.symlink)]:
                target = root / name
                try:
                    create(src, target)
                except OSError:
                    continue
                aliases.append(target)
            for alias in aliases:
                with self.subTest(alias=alias), self.assertRaises(ValueError):
                    m.validate_paths(root, src, alias)
            self.assertEqual(src.read_bytes(), b'preserved input')
            self.assertEqual(existing.read_bytes(), b'preserved output')
            self.assertEqual(m.validate_paths(root, src, root/'new.glb')[2], root/'new.glb')

    def test_static_scale_preservation_is_narrow_and_rejects_authored_changes(self):
        def write(path, doc):
            j = json.dumps(doc).encode()
            j += b' ' * (-len(j) % 4)
            binary = struct.pack('<fff', 1, 1, 1)
            body = struct.pack('<II', len(j), 0x4E4F534A) + j + struct.pack('<II', len(binary), 0x004E4942) + binary
            path.write_bytes(struct.pack('<III', 0x46546C67, 2, 12+len(body)) + body)
        source_doc = {'buffers':[{'byteLength':12}], 'nodes':[{'name':'Root','children':[1]}, {'name':'Bone','scale':[1,1,1]}],
                      'skins':[{'joints':[1]}], 'animations':[{'name':'idle','channels':[{'target':{'node':1,'path':'rotation'},'sampler':0}]}]}
        target_doc = copy.deepcopy(source_doc)
        target_doc['nodes'][1]['scale'] = [1.000001, 1, 1]
        target_doc['animations'][0]['channels'].append({'target':{'node':1,'path':'scale'},'sampler':0})
        target_doc['animations'][0]['samplers'] = [{'output':0}]
        target_doc['accessors'] = [{'bufferView':0,'componentType':5126,'type':'VEC3','count':1}]
        target_doc['bufferViews'] = [{'buffer':0,'byteOffset':0,'byteLength':12}]
        with tempfile.TemporaryDirectory() as td:
            source, candidate = Path(td)/'source.glb', Path(td)/'candidate.glb'
            write(source, source_doc); write(candidate, target_doc)
            source_before = source.read_bytes()
            report = m.preserve_static_scales(source, candidate)
            after, chunks = m.read_glb(candidate)
            self.assertEqual(after['nodes'][1]['scale'], [1,1,1])
            self.assertEqual(after['animations'][0]['channels'], source_doc['animations'][0]['channels'])
            self.assertTrue(report['binary_unchanged'])
            self.assertFalse(report['copied_rotation_translation_keys'])
            self.assertEqual(source.read_bytes(), source_before)
            variants = []
            authored = copy.deepcopy(target_doc); authored['nodes'][1]['scale']=[1.1,1,1]; variants.append(authored)
            hierarchy = copy.deepcopy(target_doc); hierarchy['nodes'][0].pop('children'); variants.append(hierarchy)
            renamed = copy.deepcopy(target_doc); renamed['nodes'][1]['name']='Other'; variants.append(renamed)
            for bad in variants:
                write(candidate, bad)
                before = candidate.read_bytes()
                with self.assertRaises(ValueError):
                    m.preserve_static_scales(source, candidate)
                self.assertEqual(candidate.read_bytes(), before)
            animated = copy.deepcopy(source_doc)
            animated['animations'][0]['channels'][0]['target']['path'] = 'scale'
            write(source, animated); write(candidate, target_doc)
            with self.assertRaises(ValueError):
                m.preserve_static_scales(source, candidate)

    def test_private_blender_patch_refuses_unreviewed_versions_and_code(self):
        class Creator:
            def __get_bone_data(self):
                min_influence = 0.0001
                return min_influence
        # Attribute name follows the reviewed Blender class, not the local class.
        Creator._PrimitiveCreator__get_bone_data = Creator._Creator__get_bone_data
        original = Creator._PrimitiveCreator__get_bone_data.__code__
        with self.assertRaises(ValueError):
            m.preserve_positive_influences(Creator, (5, 2, 0))
        with patch.object(m.inspect, 'getsource', return_value='unreviewed code'):
            with self.assertRaises(ValueError):
                m.preserve_positive_influences(Creator, (4, 3, 2))
        self.assertIs(Creator._PrimitiveCreator__get_bone_data.__code__, original)

    def test_unreviewed_or_dirty_upstream_is_refused(self):
        with patch.object(m.subprocess, 'check_output', return_value='wrong\n'):
            with self.assertRaises(ValueError):
                m.validate_upstream(Path('.'))
        with patch.object(m.subprocess, 'check_output', side_effect=[m.PIN+'\n', ' M scripts/file.py\n']):
            with self.assertRaises(ValueError):
                m.validate_upstream(Path('.'))
        with patch.object(m.subprocess, 'check_output', side_effect=[m.PIN+'\n', '']):
            m.validate_upstream(Path('.'))


if __name__ == '__main__':
    unittest.main()
