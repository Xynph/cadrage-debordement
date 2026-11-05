"""Visual two-rig contact probe. No sports-engine collision or runtime integration."""
import json,os,threading,http.server,functools
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'match3d-v24-contact-report';OUT.mkdir(exist_ok=True)
class Handler(http.server.SimpleHTTPRequestHandler):
 def log_message(self,*args):pass
s=http.server.ThreadingHTTPServer(('127.0.0.1',0),functools.partial(Handler,directory=str(ROOT/'dist')));threading.Thread(target=s.serve_forever,daemon=True).start()
errors=[];external=[];results=[];temporal=[];fallSequence=[]
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
    window.partner=partner;window.contactBases={tackler:{position:asset.body.position.clone(),quaternion:asset.body.quaternion.clone(),joints:Object.fromEntries(asset.bones.map(b=>[b.name,b.quaternion.clone()]))},carrier:{position:partner.body.position.clone(),quaternion:partner.body.quaternion.clone(),joints:Object.fromEntries(partner.bones.map(b=>[b.name,b.quaternion.clone()]))}};
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
    # Restore the unmodified tackle pose before the 'before' screenshots:
    # previous code accidentally photographed the IK-modified pose twice.
    page.evaluate('(time)=>{window.setPose("rugby_tackle",time);scene.updateMatrixWorld(true);renderer.render(scene,camera)}',t)
    page.screenshot(path=str(OUT/f'lod{lod}-tackle-{int(t*100):02d}-side.jpg'),type='jpeg',quality=90)
    page.evaluate('camera.position.set(3.4,1.5,2.6);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
    page.screenshot(path=str(OUT/f'lod{lod}-tackle-{int(t*100):02d}-front.jpg'),type='jpeg',quality=90)
    page.evaluate('camera.position.set(4,1.2,.3);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
   # Genuine, reproducible two-rig transform timeline: approach, fall, then recovery.
   # No mesh replacement, rigid-body collision claim, or match-runtime coupling.
   for phase in [0,.40,.75,1.0,1.15,1.85]:
    fall=page.evaluate("""(progress)=>{
      window.setPose('rugby_tackle',.55);
      partner.mixer.setTime(.25);
      asset.body.position.copy(contactBases.tackler.position);
      asset.body.quaternion.copy(contactBases.tackler.quaternion);
      partner.body.position.copy(contactBases.carrier.position);
      partner.body.quaternion.copy(contactBases.carrier.quaternion);
      scene.updateMatrixWorld(true);
      const state=CDMatch3DV24RugbyClips.coordinateFall(THREE,
        {body:asset.body,bones:asset.bones},partner,progress,contactBases);
      // Real post-fall wrist targets depend on the actual carrier pose.
      const ik=CDMatch3DV24RugbyClips.wrapCarrier(THREE,asset.bones,partner.bones,.85*state.onset);
      const surfaceGrip=CDMatch3DV24RugbyClips.gripCarrierSurface(
        THREE,asset.bones,partner.body,partner.bones,state.onset);
      scene.updateMatrixWorld(true);
      const p=(bones,name)=>bones.find(b=>b.name===name).getWorldPosition(new THREE.Vector3());
      const target=p(partner.bones,'spine_03');
      return {...state,handDistancesM:[p(asset.bones,'hand_l').distanceTo(target),p(asset.bones,'hand_r').distanceTo(target)],ik,surfaceGrip};
    }""",phase)
    fall['lod']=lod
    assert fall['horizontalTorsoGapM']>=.375,(lod,phase,'torso clearance',fall)
    if phase==1.0:
     assert fall['landing']>.95,(lod,phase,'full landing not reached',fall)
     assert len(fall['groundSamples'])==2,(lod,phase,'two real skinned rigs',fall)
     assert all(-.04<g['minMeshY']<.10 and g['vertices']>=30 for g in fall['groundSamples']),(lod,phase,'grounded real GLB surfaces',fall)
     assert all(g['torsoVertices']>=10 and isinstance(g['torsoMinY'],(float,int)) for g in fall['groundSamples']),(lod,phase,'real skinned torso-floor evidence absent',fall)
     assert all(g['verticalTorsoRatio']<.60 for g in fall['groundSamples']),(lod,phase,'torsos not horizontal',fall)
     assert all(.12<g['pelvisY']<.55 for g in fall['groundSamples']),(lod,phase,'pelvis hovering or underground',fall)
     assert max(fall['handDistancesM'])<.60,(lod,phase,'arms lost contact',fall)
    assert all(isinstance(d,(float,int)) and 0<=d<2 for d in fall['handDistancesM']),(lod,phase,fall)
    fallSequence.append(fall)
    page.evaluate('renderer.render(scene,camera)')
    page.screenshot(path=str(OUT/f'lod{lod}-fall-{int(phase*100):03d}-side.jpg'),type='jpeg',quality=90)
    page.evaluate('camera.position.set(3.4,1.5,2.6);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
    page.screenshot(path=str(OUT/f'lod{lod}-fall-{int(phase*100):03d}-front.jpg'),type='jpeg',quality=90)
    page.evaluate('camera.position.set(4,1.2,.3);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
   results.append(info)
  assert not errors and not external,(errors,external)
  (OUT/'report.json').write_text(json.dumps({'status':'TWO_RIG_VISUAL_PROBE_NOT_CONTACT_APPROVAL','levels':results,'temporalSamples':temporal,'fallSequence':fallSequence,'errors':errors,'externalRequests':external,'limits':['Paired-rig arm IK aims at carrier torso; no coordinated impact dynamics or contact certification','No collision physics or engine mutation','Actual skinned-mesh ground and torso-horizontal metrics tested at impact; visual contact and runtime still unqualified']},indent=2)+'\n');b.close()
finally:s.shutdown()
