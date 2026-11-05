import importlib.util,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('runner',Path(__file__).with_name('run.py'))
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)

class Receipt(unittest.TestCase):
    def test_missing_acquisition_cannot_be_complete(self):
        statuses=[{'name':name,'status':'PASS'} for name in runner.REQUIRED]
        self.assertFalse(runner.receipt(statuses,False,True)['complete'])
    def test_failed_benchmark_and_auditor_cannot_be_complete(self):
        statuses=[{'name':name,'status':'PASS'} for name in runner.REQUIRED]
        self.assertTrue(runner.receipt(statuses,True,True)['complete'])
        for name in ['published-auditor','chromium-paired','baseline-runtime-browser','rigger-registration']:
            damaged=[{**s,'status':'FAIL'} if s['name']==name else s for s in statuses]
            self.assertFalse(runner.receipt(damaged,True,True)['complete'],name)
    def test_no_capture_cannot_be_complete(self):
        statuses=[{'name':name,'status':'PASS'} for name in runner.REQUIRED]
        self.assertFalse(runner.receipt(statuses,True,False)['complete'])

if __name__=='__main__':unittest.main()
