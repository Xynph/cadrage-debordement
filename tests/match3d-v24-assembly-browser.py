"""Qualification réelle offline de l'assemblage ; ne teste pas les 30 joueurs."""
import functools,http.server,threading,json,os
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'dist/match3d/assets/rugby-v24/proof';OUT.mkdir(exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args): pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
errors=[];external=[];checks=[]
try:
 with sync_playwright() as p:
  print('Launching Chromium',flush=True)
  browser=p.chromium.launch(executable_path=os.environ.get('CD_CHROMIUM_PATH'),headless=True,args=['--no-sandbox','--disable-gpu-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  print('Browser launched',flush=True)
  page=browser.new_page(viewport={'width':960,'height':720})
  page.on('pageerror',lambda e:errors.append(str(e)))
  def route(r):
   if r.request.url.startswith('http://127.0.0.1:'):r.continue_()
   else:external.append(r.request.url);r.abort()
  page.route('**/*',route)
  print('Navigating',flush=True)
  page.goto(f'http://127.0.0.1:{server.server_port}/match3d/assets/rugby-v24/assembly.html')
  print('Waiting for asset assembly',flush=True)
  page.wait_for_function('window.ready || window.failures.length',timeout=60000,polling=100)
  print('Ready flag received',flush=True)
  assert page.evaluate('window.ready'),page.evaluate('window.failures')
  page.screenshot(path=str(OUT/'preview.png'),timeout=15000)
  data=page.evaluate('''() => {
   const meshes=[];asset.body.traverse(n=>{if(n.isSkinnedMesh)meshes.push(n);});
   return {meshes:meshes.map(n=>({name:n.name,bones:n.skeleton.bones.length})),allGarmentsShareBones:meshes.filter(n=>n.name.startsWith('Cloth')).every(n=>n.skeleton.bones.every(b=>asset.bones.includes(b))),clips:asset.clips.map(c=>c.name)};
  }''')
  assert len([m for m in data['meshes'] if m['name'].startswith('Cloth')])==3
  assert data['allGarmentsShareBones'];checks.append('Trois vêtements liés aux 53 os du corps')
  bounds=page.evaluate("() => {const b=new THREE.Box3().setFromObject(asset.body);return {min:b.min.toArray(),max:b.max.toArray()};}")
  assert 1.4 < bounds['max'][1]-bounds['min'][1] < 2.3,bounds
  assert bounds['max'][0]-bounds['min'][0] < 2.5,bounds
  checks.append('Dimensions humaines du corps et des vêtements après morphs normalisés')
  print('Assembly linked',bounds,flush=True)
  assert len(data['clips'])==12;checks.append('12 clips génériques chargés')
  for pose,time in [('idle',0),('run',.25),('run',.5)]:
   page.evaluate('([n,t])=>setPose(n,t)',[pose,time])
   finite=page.evaluate('''() => {let ok=true;asset.body.traverse(n=>{if(n.isSkinnedMesh){const v=new THREE.Vector3();for(let i=0;i<n.geometry.attributes.position.count;i+=37){v.fromBufferAttribute(n.geometry.attributes.position,i);n.boneTransform(i,v);if(![v.x,v.y,v.z].every(Number.isFinite))ok=false;}}});return ok;}''')
   print('Pose checked',pose,time,flush=True)
   assert finite;checks.append(f'Déformations finies {pose} {time}')
  for view in ['front','back','side']:
   page.evaluate("setPose('idle',0)");page.evaluate('(v)=>document.getElementById(v).click()',view);page.screenshot(path=str(OUT/(view+'.jpg')),type='jpeg',quality=88,timeout=15000)
  page.evaluate("document.getElementById('front').click()");page.evaluate("setPose('run',.25)");page.screenshot(path=str(OUT/'run.jpg'),type='jpeg',quality=88,timeout=15000)
  assert not errors,errors
  assert not external,external
  checks+=['Aucune erreur JavaScript','Aucune requête externe autorisée']
  (OUT/'report.json').write_text(json.dumps({'checks':checks,'asset':data,'bounds':bounds,'status':'CAPTURED_NOT_PRODUCTION_READY','visualReview':'visual-review.md','errors':errors,'external':external,'limits':['Un joueur de qualification ; pas de LOD, gestes rugby ou benchmark 30 joueurs','Rendu logiciel Chromium ; aucune mesure GPU Windows']},ensure_ascii=False,indent=2)+'\n')
  browser.close();print(json.dumps({'checks':checks,'meshes':data['meshes']},ensure_ascii=False))
finally:server.shutdown()
