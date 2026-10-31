"""Publish prepared Git objects only; report API errors without exposing credentials."""
import hashlib,json,os,subprocess
from pathlib import Path
REPO='Xynph/cadrage-debordement'
BASE='6dfa6cf94efbc7f65e9c9f6a1521f497a1d338a7'
TREE='ec0620beb0fa86d5bfe0a1d826242655d7dfa621'
assert os.environ['GITHUB_REPOSITORY']==REPO
assert os.environ['GITHUB_REF']=='refs/heads/prepare/champion-budget-native'
files=['dist/game.js','dist/career-integration.js','tests/economy-audit.cjs','tests/champion-budget-regression.cjs','.github/workflows/economy-audit.yml','docs/correctifs-prime-entretien.md','DEVELOPPEMENT.md']
def api(endpoint,payload):
 r=subprocess.run(['gh','api','--method','POST','repos/'+REPO+'/git/'+endpoint,'--input','-'],input=json.dumps(payload),text=True,capture_output=True)
 if r.returncode:
  error={'endpoint':endpoint,'code':r.returncode,'stderr':r.stderr,'response':r.stdout}
  Path('candidate-proof/publication-error.json').write_text(json.dumps(error,indent=2));print(json.dumps(error));raise RuntimeError('Git object publication failed; no ref update attempted')
 return json.loads(r.stdout)
entries=[]
for name in files:
 b=Path(name).read_bytes();sha=hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
 blob=api('blobs',{'content':b.decode(),'encoding':'utf-8'});assert blob['sha']==sha
 entries.append({'path':name,'mode':'100644','type':'blob','sha':sha})
manifest={'base':BASE,'baseTree':TREE,'files':entries,'writes':'unreferenced objects only, no branch update'}
Path('candidate-proof/objects.json').write_text(json.dumps(manifest,indent=2))
result=api('trees',{'base_tree':TREE,'tree':entries});manifest['tree']=result['sha']
Path('candidate-proof/tree.json').write_text(json.dumps(manifest,indent=2));print(json.dumps(manifest))
