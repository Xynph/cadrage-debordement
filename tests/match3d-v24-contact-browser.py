"""Visual two-rig contact probe. No sports-engine collision or runtime integration."""
import json,os,threading,http.server,functools
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'match3d-v24-contact-report';OUT.mkdir(exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
s=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')));threading.Thread(target=s.serve_forever,daemon=True).start()
errors=[];external=[];results=[];temporal=[]
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
   # Temporal evidence: four real clip samples, both views, with wrist-to-carrier distances.
   # Distances are observations, not an invented contact approval threshold.
   for t in [.12,.30,.55,.75]:
    sample=page.evaluate("""(time)=>{
      window.setPose('rugby_tackle',time);
      partner.mixer.setTime(.25);
      scene.updateMatrixWorld(true);
      const pos=(bones,name)=>bones.find(b=>b.name===name).getWorldPosition(new THREE.Vector3());
      const torso=pos(partner.bones,'spine_03');
      const left=pos(asset.bones,'hand_l'),right=pos(asset.bones,'hand_r');
      const separation=left.distanceTo(right);
      renderer.render(scene,camera);
      return {time,leftTorsoM:left.distanceTo(torso),rightTorsoM:right.distanceTo(torso),handSeparationM:separation,torso:torso.toArray()};
    }""",t)
    # Paired-rig IK contact: compare real skinned meshes and measured wrist distances.
    wrapped=page.evaluate("""(time)=>{
      const blend=Math.max(0,Math.min(1,(time-.18)/.27));
      const info=CDMatch3DV24RugbyClips.wrapCarrier(THREE,asset.bones,partner.bones,blend);
      scene.updateMatrixWorld(true);
      const pos=(bones,name)=>bones.find(b=>b.name===name).getWorldPosition(new THREE.Vector3());
      const torso=pos(partner.bones,'spine_03');
      return {blend,leftTorsoM:pos(asset.bones,'hand_l').distanceTo(torso),
        rightTorsoM:pos(asset.bones,'hand_r').distanceTo(torso),ikTargets:info};
    }""",t)
    sample['wrapped']=wrapped
    page.evaluate('renderer.render(scene,camera)')
    page.screenshot(path=str(OUT/f'lod{lod}-wrap-{int(t*100):02d}-side.jpg'),type='jpeg',quality=90)
    page.evaluate('camera.position.set(3.4,1.5,2.6);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
    page.screenshot(path=str(OUT/f'lod{lod}-wrap-{int(t*100):02d}-front.jpg'),type='jpeg',quality=90)
    page.evaluate('camera.position.set(4,1.2,.3);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
    sample['lod']=lod
    temporal.append(sample)
    page.screenshot(path=str(OUT/f'lod{lod}-tackle-{int(t*100):02d}-side.jpg'),type='jpeg',quality=90)
    page.evaluate('camera.position.set(3.4,1.5,2.6);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
    page.screenshot(path=str(OUT/f'lod{lod}-tackle-{int(t*100):02d}-front.jpg'),type='jpeg',quality=90)
    page.evaluate('camera.position.set(4,1.2,.3);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
   results.append(info)
  assert not errors and not external,(errors,external)
  (OUT/'report.json').write_text(json.dumps({'status':'TWO_RIG_VISUAL_PROBE_NOT_CONTACT_APPROVAL','levels':results,'temporalSamples':temporal,'errors':errors,'externalRequests':external,'limits':['Paired-rig arm IK aims at carrier torso; no coordinated impact dynamics or contact certification','No collision physics or engine mutation','No fall/landing sequence qualified']},indent=2)+'\n');b.close()
finally:s.shutdown()
