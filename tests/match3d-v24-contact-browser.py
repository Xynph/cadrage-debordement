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
   page.add_script_tag(url=f'http://127.0.0.1:{s.server_port}/match3d/assets/rugby-v24/mesh-intersections.js')
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
      // At recovery, sample the actual authored rugby_recover clip rather
      // than continuing to replay an impact crouch through p=1.85.
      // Avoid sampling exactly at 1.15s: LoopRepeat wraps to the initial
      // crouched keyframe. Stop strictly before the clip endpoint.
      if(progress>1.15)window.setPose('rugby_recover',Math.min(1.149,(progress-1.15)/.70*1.15));
      else window.setPose('rugby_tackle',.55);
      // Apply the same authored recovery to the carrier; leaving rugby_carry
      // active produced an upright tackler behind a leaning carrier.
      const recovering=progress>1.15;
      partner.mixer.stopAllAction();
      partner.mixer.clipAction(partner.clips.find(c=>c.name===(recovering?'rugby_recover':'rugby_carry'))).play();
      partner.mixer.setTime(recovering?Math.min(1.149,(progress-1.15)/.70*1.15):.25);
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
      const collision=CDMatch3DV24MeshIntersections.probe(THREE,{body:asset.body,bones:asset.bones},partner,850);
      // Non-mutating deterministic pose search at impact. Test ACTUAL skinned
      // carrier vertices, two anatomically fixed arm reaches and intersecting
      // triangles. Only report candidates; never move a rig without review.
      let relativePoseSweep=null;
      if(progress===1){
        const right=p(asset.bones,'upperarm_r'),left=p(asset.bones,'upperarm_l');
        const chest=p(partner.bones,'spine_03'),direction=right.clone().sub(chest);
        direction.y=0;
        if(direction.lengthSq()<1e-8)direction.set(1,0,0);
        direction.normalize();
        const sideways=new THREE.Vector3(-direction.z,0,direction.x);
        const start=partner.body.position.clone(),samples=[];
        const reach=side=>{const a=p(asset.bones,'upperarm_'+side),b=p(asset.bones,'lowerarm_'+side),c=p(asset.bones,'hand_'+side);return a.distanceTo(b)+b.distanceTo(c);};
        const reachL=reach('l'),reachR=reach('r');
        for(const [forward,lateral] of [[0,0],[.04,0],[.08,0],[.12,0],[0,.04],[0,-.04],[.06,.04],[.06,-.04],[.10,.04],[.10,-.04]]){
          partner.body.position.copy(start).addScaledVector(direction,forward).addScaledVector(sideways,lateral);
          partner.body.updateMatrixWorld(true);
          const skin=[];
          partner.body.traverse(mesh=>{
            if(!mesh.isSkinnedMesh||mesh.name!=='Body')return;
            const attr=mesh.geometry.getAttribute('position'),v=new THREE.Vector3();
            const stride=Math.max(1,Math.floor(attr.count/600));
            for(let i=0;i<attr.count;i+=stride){
              mesh.boneTransform(i,v.fromBufferAttribute(attr,i));mesh.localToWorld(v);
              if(v.distanceTo(p(partner.bones,'spine_03'))<.45)skin.push(v.clone());
            }
          });
          const distance=a=>Math.min(...skin.map(v=>v.distanceTo(a)));
          const leftDeficit=Math.max(0,distance(left)-reachL);
          const rightDeficit=Math.max(0,distance(right)-reachR);
          const crossed=CDMatch3DV24MeshIntersections.probe(THREE,{body:asset.body,bones:asset.bones},partner,260);
          samples.push({forwardM:forward,lateralM:lateral,leftDeficitM:leftDeficit,
            rightDeficitM:rightDeficit,sampledTriangleIntersections:crossed.properTriangleIntersections});
        }
        partner.body.position.copy(start);partner.body.updateMatrixWorld(true);
        relativePoseSweep={reachL,reachR,samples,
          status:'DIAGNOSTIC_ONLY_NO_POSE_MUTATION_AND_SAMPLED_TRIANGLES_ONLY'};
      }
      // Separate diagnostic: do bounded REAL right-clavicle rotations make
      // the carrier reachable without worsening the actual skinned crossing?
      // Probe no fake limb extensions; restore the skeleton before screenshot.
      let clavicleSweep=null;
      if(progress===1){
        const clav=asset.bones.find(b=>b.name==='clavicle_r'),base=clav.quaternion.clone();
        const shoulder=asset.bones.find(b=>b.name==='upperarm_r');
        const elbow=asset.bones.find(b=>b.name==='lowerarm_r');
        const wrist=asset.bones.find(b=>b.name==='hand_r');
        const skin=[],centre=p(partner.bones,'spine_03');
        partner.body.traverse(mesh=>{
          if(!mesh.isSkinnedMesh||mesh.name!=='Body')return;
          const attr=mesh.geometry.getAttribute('position'),v=new THREE.Vector3();
          const stride=Math.max(1,Math.floor(attr.count/700));
          for(let i=0;i<attr.count;i+=stride){
            mesh.boneTransform(i,v.fromBufferAttribute(attr,i));mesh.localToWorld(v);
            if(v.distanceTo(centre)<.45)skin.push(v.clone());
          }
        });
        const candidates=[];
        for(const [axis,angle] of [['x',0],['x',-.25],['x',.25],['y',-.25],['y',.25],['z',-.25],['z',.25]]){
          clav.quaternion.copy(base);
          if(angle)clav.quaternion.multiply(new THREE.Quaternion().setFromAxisAngle(
            axis==='x'?new THREE.Vector3(1,0,0):axis==='y'?new THREE.Vector3(0,1,0):new THREE.Vector3(0,0,1),angle));
          asset.body.updateMatrixWorld(true);
          const a=p(asset.bones,'upperarm_r');
          const armLength=a.distanceTo(p(asset.bones,'lowerarm_r'))+
            p(asset.bones,'lowerarm_r').distanceTo(p(asset.bones,'hand_r'));
          const closest=Math.min(...skin.map(v=>a.distanceTo(v)));
          const crossings=CDMatch3DV24MeshIntersections.probe(THREE,{body:asset.body,bones:asset.bones},partner,260);
          candidates.push({axis,angleRadians:angle,armReachM:armLength,
            shoulderToRealSkinM:closest,reachDeficitM:Math.max(0,closest-armLength),
            sampledTriangleIntersections:crossings.properTriangleIntersections});
        }
        clav.quaternion.copy(base);asset.body.updateMatrixWorld(true);
        clavicleSweep={candidates,status:'DIAGNOSTIC_ONLY_RESTORED_SKELETON'};
      }
      // Four bounded real right-clavicle angles, each followed by the exact
      // two-hand IK and the 850-triangle Body intersection probe. Restore ALL
      // bone quaternions between trials and before screenshots: no per-LOD
      // acceptance may silently alter the scene if another LOD fails.
      let clavicleGripTrial=null;
      if(progress===1){
        const originalBones=asset.bones.map(b=>b.quaternion.clone());
        const baseline={leftM:surfaceGrip.l.afterSurfaceMetres,
          rightM:surfaceGrip.r.afterSurfaceMetres,
          intersections:collision.properTriangleIntersections};
        const clav=asset.bones.find(b=>b.name==='clavicle_r');
        const trials=[];
        for(const angle of [.10,.15,.20,.25]){
          asset.bones.forEach((bone,i)=>bone.quaternion.copy(originalBones[i]));
          clav.quaternion.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,0,1),angle));
          asset.body.updateMatrixWorld(true);
          const trialGrip=CDMatch3DV24RugbyClips.gripCarrierSurface(
            THREE,asset.bones,partner.body,partner.bones,state.onset);
          const intersections=CDMatch3DV24MeshIntersections.probe(
            THREE,{body:asset.body,bones:asset.bones},partner,850).properTriangleIntersections;
          const candidate={angleRadians:angle,leftM:trialGrip.l.afterSurfaceMetres,
            rightM:trialGrip.r.afterSurfaceMetres,intersections};
          candidate.accepted=candidate.rightM<baseline.rightM-.005
            && candidate.leftM<=baseline.leftM+.001
            && candidate.intersections<=baseline.intersections;
          trials.push(candidate);
        }
        asset.bones.forEach((bone,i)=>bone.quaternion.copy(originalBones[i]));
        asset.body.updateMatrixWorld(true);
        // Trial preview ONLY. Never write to assets/runtime and only show
        // +0.20 rad if the exact current LOD passes both wrists and 850-face
        // intersection checks. The Python report requires ALL 3 LODs safe.
        const previewCandidate=trials.find(t=>Math.abs(t.angleRadians-.20)<1e-8);
        let preview=null;
        if(previewCandidate?.accepted){
          clav.quaternion.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,0,1),.20));
          asset.body.updateMatrixWorld(true);
          const gripPreview=CDMatch3DV24RugbyClips.gripCarrierSurface(
            THREE,asset.bones,partner.body,partner.bones,state.onset);
          const crossingsPreview=CDMatch3DV24MeshIntersections.probe(
            THREE,{body:asset.body,bones:asset.bones},partner,850).properTriangleIntersections;
          preview={appliedToIsolatedScreenshot:true,angleRadians:.20,
            leftM:gripPreview.l.afterSurfaceMetres,rightM:gripPreview.r.afterSurfaceMetres,
            intersections:crossingsPreview};
          if(preview.rightM>=baseline.rightM-.005
            ||preview.leftM>baseline.leftM+.001
            ||preview.intersections>baseline.intersections)
            throw Error('Real skinned candidate preview violates original contact and collision checks');
        } else {
          preview={appliedToIsolatedScreenshot:false,angleRadians:.20};
        }
        clavicleGripTrial={baseline,trials,preview,
          accepted:trials.some(t=>t.accepted),
          status:'STAGE_ONLY_PREVIEW_NO_GLBS_OR_RUNTIME_MODIFIED'};
      }
      return {...state,meshIntersections:collision,relativePoseSweep,clavicleSweep,clavicleGripTrial,handDistancesM:[p(asset.bones,'hand_l').distanceTo(target),p(asset.bones,'hand_r').distanceTo(target)],ik,surfaceGrip};
    }""",phase)
    fall['lod']=lod
    assert fall['meshIntersections']['tacklerTriangles']>=20 and fall['meshIntersections']['carrierTriangles']>=20,(lod,phase,'real mesh triangle samples missing',fall['meshIntersections'])
    assert isinstance(fall['meshIntersections']['properTriangleIntersections'],int),(lod,phase,'intersection count unavailable')
    # Real deformed surface samples near anatomical support regions;
    # neither joint position nor an invisible floor proxy is a contact proof.
    for support in fall['groundSamples']:
     regions=support['supportSurfaces']
     assert set(regions)=={'chest','pelvis','kneeL','kneeR','footL','footR'},(lod,phase,'missing anatomical support regions')
     assert all(region['samples']>=10 and isinstance(region['minY'],(float,int))
                for region in regions.values()),(lod,phase,'insufficient skinned support samples',regions)
     if phase==1.0:
      assert all(.015 <= regions[name]['minY'] <= .11 for name in regions),(lod,phase,'impact body support outside measured pitch range',regions)
     if phase==1.85:
      # The tackler must genuinely rise after touchdown, not hold the first
      # crouched recovery keyframe due to looping at exactly duration.
      assert support['headY']>1.45,(lod,phase,'both players must rise from recovery crouch',support)
      assert support['headY']-support['pelvisY']>.57,(lod,phase,'recovery torso not upright',support)
      assert all(.015 <= regions[name]['minY'] <= .075 for name in ('footL','footR')),(lod,phase,'recovery feet do not plant on real mesh',regions)
      assert regions['chest']['minY']>.20 and regions['pelvis']['minY']>.15,(lod,phase,'torso still down during recovery',regions)
    assert fall['horizontalTorsoGapM']>=.375,(lod,phase,'torso clearance',fall)
    # Grounded skinned mesh must remain outside the turf while upright again,
    # not just at the peak of the fall. Measure both actual player meshes.
    if phase in (0,1.85):
     assert len(fall['groundSamples'])==2,(lod,phase,'two skinned rigs required')
     assert all(.015 <= g['minMeshY'] <= .055 for g in fall['groundSamples']),(lod,phase,'standing/recovery mesh penetrates turf',fall['groundSamples'])
    if phase==1.0:
     sweep=fall['relativePoseSweep']
     clavicle=fall['clavicleSweep']
     grip_trial=fall['clavicleGripTrial']
     assert grip_trial and len(grip_trial['trials'])==4,(lod,'missing four real-IK trials',grip_trial)
     preview=grip_trial['preview']
     assert preview and preview['appliedToIsolatedScreenshot'],(lod,'shared +.20 rad candidate must safely preview on all 3 LOD',grip_trial)
     assert preview['rightM']<grip_trial['baseline']['rightM']-.005,(lod,'right wrist regression')
     assert preview['leftM']<=grip_trial['baseline']['leftM']+.001,(lod,'left wrist regression')
     assert preview['intersections']<=grip_trial['baseline']['intersections'],(lod,'real triangle crossings regression')
     assert all(isinstance(grip_trial['baseline'][metric],(int,float)) for metric in ('leftM','rightM','intersections')),(lod,'invalid baseline',grip_trial)
     for trial in grip_trial['trials']:
      assert all(isinstance(trial[metric],(int,float)) for metric in ('angleRadians','leftM','rightM','intersections')),(lod,'invalid actual-grip trial',trial)
      if trial['accepted']:
       assert trial['rightM']<grip_trial['baseline']['rightM']-.005
       assert trial['leftM']<=grip_trial['baseline']['leftM']+.001
       assert trial['intersections']<=grip_trial['baseline']['intersections']
     assert len(clavicle['candidates'])==7 and clavicle['candidates'][0]['angleRadians']==0,(lod,'clavicle diagnostic unavailable',clavicle)
     assert all(x['armReachM']>.3 and x['sampledTriangleIntersections']>=0 for x in clavicle['candidates']),(lod,'invalid skinned clavicle sweep',clavicle)
     assert len(sweep['samples'])==10 and sweep['samples'][0]['forwardM']==0 and sweep['samples'][0]['lateralM']==0,(lod,'pose-sweep unavailable',sweep)
     assert all(isinstance(item['rightDeficitM'],(int,float)) and isinstance(item['leftDeficitM'],(int,float)) and item['sampledTriangleIntersections']>=0 for item in sweep['samples']),(lod,'invalid real-skin pose sweep',sweep)
     assert fall['landing']>.95,(lod,phase,'full landing not reached',fall)
     assert len(fall['groundSamples'])==2,(lod,phase,'two real skinned rigs',fall)
     assert all(-.04<g['minMeshY']<.10 and g['vertices']>=30 for g in fall['groundSamples']),(lod,phase,'grounded real GLB surfaces',fall)
     assert all(g['torsoVertices']>=10 and isinstance(g['torsoMinY'],(float,int)) for g in fall['groundSamples']),(lod,phase,'real skinned torso-floor evidence absent',fall)
     # Actual skinned chest must approach turf, not merely a toe or calf.
     assert all(.015 <= g['torsoMinY'] <= .10 for g in fall['groundSamples']),(lod,phase,'chest still airborne or penetrating ground',fall)
     assert all(g['verticalTorsoRatio']<.60 for g in fall['groundSamples']),(lod,phase,'torsos not horizontal',fall)
     assert all(.12<g['pelvisY']<.55 for g in fall['groundSamples']),(lod,phase,'pelvis hovering or underground',fall)
     assert max(fall['handDistancesM'])<.60,(lod,phase,'arms lost contact',fall)
     for side in ('l','r'):
      grip=fall['surfaceGrip'][side]
      assert grip['afterSurfaceMetres']<=grip['bestReachableSurfaceMetres']+.00051,(lod,phase,side,'opposite flank loses reachable real-skin contact',grip)
    assert all(isinstance(d,(float,int)) and 0<=d<2 for d in fall['handDistancesM']),(lod,phase,fall)
    fallSequence.append(fall)
    page.evaluate('renderer.render(scene,camera)')
    page.screenshot(path=str(OUT/f'lod{lod}-fall-{int(phase*100):03d}-side.jpg'),type='jpeg',quality=90)
    page.evaluate('camera.position.set(3.4,1.5,2.6);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
    page.screenshot(path=str(OUT/f'lod{lod}-fall-{int(phase*100):03d}-front.jpg'),type='jpeg',quality=90)
    page.evaluate('camera.position.set(4,1.2,.3);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
   results.append(info)
  # Reject a shared positional "fix" unless all three skinned LODs
  # improve right-arm reach without worsening left reach or sampled crossings.
  # Diagnostic only: the runtime never consumes these offsets.
  sweeps={f['lod']:f['relativePoseSweep']['samples'] for f in fallSequence if f['progress']==1}
  assert set(sweeps)=={0,1,2},('all LOD impact sweeps required',sweeps.keys())
  reference={lod:items[0] for lod,items in sweeps.items()}
  safe_shared=[]
  for index in range(1,10):
   candidates=[sweeps[lod][index] for lod in range(3)]
   assert len({(x['forwardM'],x['lateralM']) for x in candidates})==1,('offset mismatch across LOD',index)
   if all(x['rightDeficitM'] < reference[lod]['rightDeficitM']-.005
          and x['leftDeficitM'] <= reference[lod]['leftDeficitM']+1e-6
          and x['sampledTriangleIntersections']<=reference[lod]['sampledTriangleIntersections']
          for lod,x in enumerate(candidates)):
    safe_shared.append({'forwardM':candidates[0]['forwardM'],'lateralM':candidates[0]['lateralM']})
  clavicle_trials={x['lod']:x['clavicleGripTrial'] for x in fallSequence if x['progress']==1}
  assert set(clavicle_trials)=={0,1,2},('trial must cover every LOD',clavicle_trials.keys())
  shared_clavicle_angles=[angle for angle in (.10,.15,.20,.25)
    if all(any(abs(t['angleRadians']-angle)<1e-8 and t['accepted']
               for t in data['trials']) for data in clavicle_trials.values())]
  shared_clavicle_safe=bool(shared_clavicle_angles)
  pose_decision={'status':'DIAGNOSTIC_ONLY_NO_RUNTIME_RELOCATION',
    'safeSharedOffsets':safe_shared,'sharedClavicleAccepted':shared_clavicle_safe,'safeClavicleAngles':shared_clavicle_angles,
    'clavicleByLOD':clavicle_trials,'referenceByLOD':reference,
    'limits':'Sampled Body triangles are not exhaustive collision certification'}
  assert not errors and not external,(errors,external)
  (OUT/'report.json').write_text(json.dumps({'status':'TWO_RIG_VISUAL_PROBE_NOT_CONTACT_APPROVAL','poseDecision':pose_decision,'levels':results,'temporalSamples':temporal,'fallSequence':fallSequence,'errors':errors,'externalRequests':external,'limits':['Paired-rig arm IK aims at carrier torso; no coordinated impact dynamics or contact certification','No collision physics or engine mutation','Actual skinned-mesh ground and torso-horizontal metrics tested at impact; visual contact and runtime still unqualified']},indent=2)+'\n');b.close()
finally:s.shutdown()
