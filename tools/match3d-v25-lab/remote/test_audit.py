import importlib.util, struct, unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('audit',Path(__file__).with_name('binary_audit.py'))
audit=importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)

class Accessors(unittest.TestCase):
    def test_sparse_normalized_and_stride(self):
        raw=struct.pack('<4B4B',255,0,0,0,0,255,0,0)+bytes([1])+bytes([128,127,0,0])
        g={'bufferViews':[{'byteOffset':0,'byteLength':8,'byteStride':4},{'byteOffset':8,'byteLength':1},{'byteOffset':9,'byteLength':4}],
           'accessors':[{'bufferView':0,'componentType':5121,'type':'VEC4','count':2,'normalized':True,'sparse':{'count':1,'indices':{'bufferView':1,'componentType':5121},'values':{'bufferView':2}}}]}
        rows=audit.accessor(g,raw,0)
        self.assertEqual(rows[0],[1,0,0,0]);self.assertAlmostEqual(sum(rows[1]),1)
        self.assertAlmostEqual(rows[1][0],128/255)
    def test_weight_and_joint_rejection(self):
        self.assertEqual(audit.skin_errors([[1,0,0,0]],[[0,0,0,0]],53),[0,0,0])
        self.assertEqual(audit.skin_errors([[.2,0,0,0]],[[53,0,0,0]],53),[0,1,1])
        self.assertEqual(audit.skin_errors([[float('nan'),0,0,0]],[[0,0,0,0]],53)[0],1)

if __name__=='__main__':unittest.main()
