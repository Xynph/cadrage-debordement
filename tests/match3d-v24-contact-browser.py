"""Visual two-rig contact probe. No sports-engine collision or runtime integration."""
import json,os,threading,http.server,functools
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'match3d-v24-contact-report';OUT.mkdir(exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
s=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')));threading.Thread(target=s.serve_forever,daemon=True).start()
errors=[];external=[];results=[]
try:
 with sync_playwright() as p:
  b=p.chromium.launch(executable_path=os.environ.get('CD_CHROMIUM_PATH'),args=['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'])
  page=b.new_page(viewport={'width':960,'height':720});page.on('pageerror',lambda e:errors.append(str(e)))
  def route(r):
   if r.request.url.startswith('http://127.0.0.1:'):r.continue_()
   else:external.append(r.request.url);r.abort()
  page.route('**/*',route)
  for lod in range(3):
   page.goto(f'http://127.0.0.1:{s.server_port}/match3d/assets/rugby-v24/assembly.html?lod={lod}',wait_until='domcontentloaded');page.wait_for_function('window.ready || window.failures.length',timeout=120000);assert page.evaluate('window.ready'),page.evaluate('window.failures')
   page.add_script_tag(url=f'http://127.0.0.1:{s.server_port}/match3d/assets/rugby-v24/player-stage.js')
   info=page.evaluate("""()=>{
    window.setPose('idle',0);const partner=CDMatch3DV24Stage.instantiate(THREE,asset,0);scene.add(partner.body);
    window.setPose('rugby_tackle',.55);asset.body.position.x=-.2;scene.updateMatrixWorld(true);
    const shoulder=asset.bones.find(b=>b.name==='upperarm_l').getWorldPosition(new THREE.Vector3());
    partner.body.position.set(shoulder.x+.06,0,shoulder.z+.16);partner.body.rotation.y=Math.PI;
    partner.mixer.clipAction(partner.clips.find(c=>c.name==='rugby_carry')).play();partner.mixer.setTime(.25);scene.updateMatrixWorld(true);
    window.partner=partner;
    document.querySelector('header').style.display='none';camera.position.set(3.4,1.5,2.6);camera.lookAt(0,.85,.35);renderer.render(scene,camera);
    return {independentRig:partner.bones.every((b,i)=>b!==asset.bones[i]),shoulder:shoulder.toArray(),carrierRoot:partner.body.position.toArray(),lod:asset.lod};
   }""")
   assert info['independentRig'],info
   page.screenshot(path=str(OUT/f'lod{lod}-contact-front.jpg'),type='jpeg',quality=90)
   page.evaluate('camera.position.set(4,1.2,.3);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
   page.screenshot(path=str(OUT/f'lod{lod}-contact-side.jpg'),type='jpeg',quality=90)
   results.append(info)
  assert not errors and not external,(errors,external)
  (OUT/'report.json').write_text(json.dumps({'status':'TWO_RIG_VISUAL_PROBE_NOT_CONTACT_APPROVAL','levels':results,'errors':errors,'externalRequests':external,'limits':['Static contact arrangement','No collision physics or engine mutation','No fall/landing sequence qualified']},indent=2)+'\n');b.close()
finally:s.shutdown()
