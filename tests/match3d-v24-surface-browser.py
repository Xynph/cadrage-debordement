"""Isolated Chromium probe of actual deformed torso mesh distances at the tackle impact."""
import functools,http.server,json,threading,os
from pathlib import Path
from playwright.sync_api import sync_playwright
from match3d_v24_surface_proximity import summarize_surface_samples
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'match3d-v24-surface-report'
OUT.mkdir(exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
server=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')))
threading.Thread(target=server.serve_forever,daemon=True).start()
errors=[];external=[];report=[]
try:
 with sync_playwright() as playwright:
  browser=playwright.chromium.launch(executable_path=os.environ.get('CD_CHROMIUM_PATH'),
    args=['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  page=browser.new_page(viewport={'width':960,'height':720})
  page.on('pageerror',lambda err:errors.append(str(err)))
  def route(r):
   if r.request.url.startswith('http://127.0.0.1:'):r.continue_()
   else:external.append(r.request.url);r.abort()
  page.route('**/*',route)
  for lod in range(3):
   page.goto(f'http://127.0.0.1:{server.server_port}/match3d/assets/rugby-v24/assembly.html?lod={lod}',wait_until='domcontentloaded')
   page.wait_for_function('window.ready || window.failures.length',timeout=120000)
   assert page.evaluate('window.ready'),page.evaluate('window.failures')
   page.add_script_tag(url=f'http://127.0.0.1:{server.server_port}/match3d/assets/rugby-v24/player-stage.js')
   data=page.evaluate("""()=>{
    window.setPose('rugby_tackle',.55);
    const carrier=CDMatch3DV24Stage.instantiate(THREE,asset,0);
    scene.add(carrier.body);
    asset.body.position.x=-.2;scene.updateMatrixWorld(true);
    const shoulder=asset.bones.find(b=>b.name==='upperarm_l').getWorldPosition(new THREE.Vector3());
    carrier.body.position.set(shoulder.x+.06,0,shoulder.z+.16);
    carrier.body.rotation.y=Math.PI;
    carrier.mixer.clipAction(carrier.clips.find(c=>c.name==='rugby_carry')).play();
    carrier.mixer.setTime(.25);scene.updateMatrixWorld(true);
    const bases={tackler:{position:asset.body.position.clone(),quaternion:asset.body.quaternion.clone(),
      joints:Object.fromEntries(asset.bones.map(b=>[b.name,b.quaternion.clone()]))},
      carrier:{position:carrier.body.position.clone(),quaternion:carrier.body.quaternion.clone(),
      joints:Object.fromEntries(carrier.bones.map(b=>[b.name,b.quaternion.clone()]))}};
    const state=CDMatch3DV24RugbyClips.coordinateFall(THREE,{body:asset.body,bones:asset.bones},carrier,1,bases);
    const ik=CDMatch3DV24RugbyClips.wrapCarrier(THREE,asset.bones,carrier.bones,.85*state.onset);
    scene.updateMatrixWorld(true);
    function sample(body,bones){
      const centre=bones.find(b=>b.name==='spine_03').getWorldPosition(new THREE.Vector3());
      const out=[];body.traverse(mesh=>{
        if(!mesh.isSkinnedMesh||mesh.name!=='Body')return;
        const positions=mesh.geometry.getAttribute('position');
        const stride=Math.max(1,Math.floor(positions.count/700));
        const v=new THREE.Vector3();
        for(let i=0;i<positions.count;i+=stride){
          mesh.boneTransform(i,v.fromBufferAttribute(positions,i));
          mesh.localToWorld(v);
          if(v.distanceTo(centre)<.45)out.push(v.toArray());
        }
      });return out;
    }
    const point=(bones,name)=>bones.find(b=>b.name===name).getWorldPosition(new THREE.Vector3()).toArray();
    window.surfaceScene={carrier};
    return {state,ik,a:sample(asset.body,asset.bones),b:sample(carrier.body,carrier.bones),
      hands:['hand_l','hand_r'].map(n=>point(asset.bones,n))};
   }""")
   surface=summarize_surface_samples(data['a'],data['b'])
   def nearest(hand):
    return min(sum((x-y)**2 for x,y in zip(hand,v))**.5 for v in data['b'])
   surface['handToCarrierSurfaceM']=[nearest(h) for h in data['hands']]
   surface['lod']=lod
   surface['ground']=data['state']['groundSamples']
   assert all(0<=d<2 for d in surface['handToCarrierSurfaceM'])
   assert all(n>=10 for n in surface['samples'])
   report.append(surface)
   page.evaluate("camera.position.set(4,1.2,.3);camera.lookAt(0,.85,.35);renderer.render(scene,camera)")
   page.screenshot(path=str(OUT/f'lod{lod}-surface-side.jpg'),type='jpeg',quality=90)
  assert not errors and not external,(errors,external)
  (OUT/'report.json').write_text(json.dumps({'head':os.environ.get('GITHUB_SHA',''), 'levels':report,
    'status':'SAMPLED_UNSIGNED_SURFACE_GAPS_NOT_CONTACT_APPROVAL',
    'errors':errors,'externalRequests':external},indent=2)+'\n')
  browser.close()
finally:
 server.shutdown()
