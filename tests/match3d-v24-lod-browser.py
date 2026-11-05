"""Qualification géométrique et animations des trois LOD, offline sur Chromium SwiftShader."""
import functools,http.server,threading,json,os
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'match3d-v24-lod-report'
OUT.mkdir(exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
errors=[];external=[];results=[]
try:
 with sync_playwright() as p:
  browser=p.chromium.launch(executable_path=os.environ.get('CD_CHROMIUM_PATH'),headless=True,args=['--no-sandbox','--disable-gpu-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  page=browser.new_page(viewport={'width':960,'height':720})
  page.on('pageerror',lambda err:errors.append(str(err)))
  def route(r):
   if r.request.url.startswith('http://127.0.0.1:'):r.continue_()
   else:external.append(r.request.url);r.abort()
  page.route('**/*',route)
  for level in range(3):
   page.goto(f'http://127.0.0.1:{server.server_port}/match3d/assets/rugby-v24/assembly.html?lod={level}',wait_until='domcontentloaded')
   page.wait_for_function('window.ready || window.failures.length',timeout=120000)
   assert page.evaluate('window.ready'),page.evaluate('window.failures')
   info=page.evaluate("""() => {
     const meshes=[];
     asset.body.traverse(n=>{if(n.isSkinnedMesh)meshes.push(n);});
     const bounds=new THREE.Box3().setFromObject(asset.body);
     return {lod:asset.lod,clips:asset.clips.map(c=>c.name),meshes:meshes.map(m=>({name:m.name,joints:m.skeleton.bones.length,vertices:m.geometry.attributes.position.count})),
       garmentsShareBones:meshes.filter(m=>m.name.startsWith('Cloth')).every(m=>m.skeleton.bones.every(b=>asset.bones.includes(b))),
       height:bounds.max.y-bounds.min.y, width:bounds.max.x-bounds.min.x};
   }""")
   assert info['lod']==level,info
   assert len(info['meshes'])>=4,info
   assert info['garmentsShareBones'],info
   assert all(m['joints']==53 for m in info['meshes']),info
   assert 1.4<info['height']<2.3,info
   assert set(['rugby_carry','rugby_pass','rugby_tackle','rugby_recover']).issubset(set(info['clips'])),info
   for gesture in ['idle','run','rugby_carry','rugby_pass','rugby_tackle','rugby_recover']:
    page.evaluate('([name,time])=>window.setPose(name,time)',[gesture,.25])
    finite=page.evaluate("""() => {
     let ok=true, samples=0;const v=new THREE.Vector3();
     asset.body.traverse(n=>{if(!n.isSkinnedMesh)return;
       const count=n.geometry.attributes.position.count;
       for(let i=0;i<count;i+=Math.max(1,Math.floor(count/120))){
         v.fromBufferAttribute(n.geometry.attributes.position,i);
         n.boneTransform(i,v);
         if(![v.x,v.y,v.z].every(Number.isFinite))ok=false;samples++;
       }
     });return {ok,samples};
    }""")
    assert finite['ok'] and finite['samples']>0,(level,gesture,finite)
    if gesture in ['idle','rugby_pass','rugby_tackle']:
     page.screenshot(path=str(OUT/f'lod{level}-{gesture}.jpg'),type='jpeg',quality=85,timeout=25000)
   # Profil détaillé au sommet des gestes : contrôle visuel, pas approbation automatique.
   for gesture,when in [('rugby_pass',.42),('rugby_tackle',.55)]:
    page.evaluate('([name,time])=>window.setPose(name,time)',[gesture,when])
    page.evaluate("document.getElementById('side').click()")
    page.screenshot(path=str(OUT/f'lod{level}-{gesture}-side.jpg'),type='jpeg',quality=90,timeout=25000)
    page.evaluate("document.getElementById('front').click()")
   results.append(info)
  assert not errors,errors
  assert not external,external
  (OUT/'report.json').write_text(json.dumps({'status':'BROWSER_STRUCTURAL_PASS_NOT_VISUAL_APPROVAL','levels':results,'jsErrors':errors,'externalRequests':external,'caveat':'Captures non approuvees esthetiquement, chaussure/penetration a inspecter; ne teste pas les 30 joueurs ou FPS'},indent=2,ensure_ascii=False)+'\n')
  print(json.dumps({'levels':len(results),'screenshots':len(list(OUT.glob('*.jpg'))),'errors':errors,'external':external},ensure_ascii=False))
  browser.close()
finally:server.shutdown()
