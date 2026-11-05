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
      // Freeze the four real arm bones BEFORE the first skin-target solve.
      // Repeated IK should start from these same anatomical joint rotations,
      // rather than treating the last wrist displacement as a fresh input.
      const referenceArms=Object.fromEntries(['upperarm_l','lowerarm_l','upperarm_r','lowerarm_r']
        .map(n=>[n,asset.bones.find(b=>b.name===n).quaternion.clone()]));
      const surfaceGrip=CDMatch3DV24RugbyClips.gripCarrierSurface(
        THREE,asset.bones,partner.body,partner.bones,state.onset,{referenceArms});
      scene.updateMatrixWorld(true);
      const p=(bones,name)=>bones.find(b=>b.name===name).getWorldPosition(new THREE.Vector3());
      const target=p(partner.bones,'spine_03');
      const collision=CDMatch3DV24MeshIntersections.probe(THREE,{body:asset.body,bones:asset.bones},partner,850);
      // Anatomical approach-only probe at p=.75, the worst observed LOD2
      // skinned-mesh crossing phase. No rig translation or fake collision hull.
      // Never leave a changed approach pose in the rendered timeline.
      let approachShoulderTrial=null;
      if(Math.abs(progress-.75)<1e-8){
        const original=asset.bones.map(b=>b.quaternion.clone());
        const base={leftM:surfaceGrip.l.afterSurfaceMetres,
          rightM:surfaceGrip.r.afterSurfaceMetres,
          intersections:collision.properTriangleIntersections};
        const clav=asset.bones.find(b=>b.name==='clavicle_r'),samples=[];
        for(const angle of [.10,.15,.20]){
          asset.bones.forEach((bone,i)=>bone.quaternion.copy(original[i]));
          clav.quaternion.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,0,1),angle));
          asset.body.updateMatrixWorld(true);
          const grip=CDMatch3DV24RugbyClips.gripCarrierSurface(
            THREE,asset.bones,partner.body,partner.bones,state.onset,{referenceArms});
          const crossing=CDMatch3DV24MeshIntersections.probe(
            THREE,{body:asset.body,bones:asset.bones},partner,850);
          samples.push({angleRadians:angle,leftM:grip.l.afterSurfaceMetres,
            rightM:grip.r.afterSurfaceMetres,
            intersections:crossing.properTriangleIntersections});
        }
        asset.bones.forEach((bone,i)=>bone.quaternion.copy(original[i]));
        asset.body.updateMatrixWorld(true);
        approachShoulderTrial={baseline:base,samples,status:'DIAGNOSTIC_ONLY_SKINNED_POSE_RESTORED'};
      }
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
            THREE,asset.bones,partner.body,partner.bones,state.onset,{referenceArms});
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
        // First verify the baseline is a fixed point when the exact same
        // four arm joint rotations are supplied again. This MUST hold even
        // if no clavicle angle is safe on all LODs.
        asset.bones.forEach((bone,i)=>bone.quaternion.copy(originalBones[i]));
        asset.body.updateMatrixWorld(true);
        const repeated=CDMatch3DV24RugbyClips.gripCarrierSurface(
          THREE,asset.bones,partner.body,partner.bones,state.onset,{referenceArms});
        const repeatedCrossings=CDMatch3DV24MeshIntersections.probe(
          THREE,{body:asset.body,bones:asset.bones},partner,850).properTriangleIntersections;
        const repeatability={first:baseline,
          second:{leftM:repeated.l.afterSurfaceMetres,
            rightM:repeated.r.afterSurfaceMetres,intersections:repeatedCrossings},
          maxJointQuaternionDelta:Math.max(...asset.bones.map((bone,i)=>
            1-Math.abs(bone.quaternion.dot(originalBones[i]))))};
        // Do NOT preview any anatomical angle in the screenshots unless its
        // cross-LOD safety is established by a separate completed report.
        asset.bones.forEach((bone,i)=>bone.quaternion.copy(originalBones[i]));
        asset.body.updateMatrixWorld(true);
        const preview={appliedToIsolatedScreenshot:false,reason:'NO_UNQUALIFIED_SHARED_CLAVICLE'};
        clavicleGripTrial={baseline,trials,preview,repeatability,
          accepted:trials.some(t=>t.accepted),
          status:'FIXED_INPUT_IDEMPOTENCE_TEST_NO_POSE_PREVIEW'};
      }
      // Sweep anatomically bounded elbow-pole targets in the +0.20
      // clavicle pose. Measure real wrists, opposing elbow placement and
      // sampled skinned-surface crossings, restoring all bones each time.
      let elbowPoleTrial=null;
      if(progress===1 && clavicleGripTrial?.preview?.appliedToIsolatedScreenshot){
        const original=asset.bones.map(b=>b.quaternion.clone());
        const center=p(partner.bones,'spine_03');
        const toward=center.clone().sub(p(asset.bones,'upperarm_l')
          .add(p(asset.bones,'upperarm_r')).multiplyScalar(.5));
        toward.y=0;toward.normalize();
        const lateral=new THREE.Vector3(-toward.z,0,toward.x);
        const profiles=[[0,0],[.16,0],[-.16,0],[0,.16],[0,-.16]];
        const candidates=[];
        for(const [poleY,poleZ] of profiles){
          asset.bones.forEach((bone,i)=>bone.quaternion.copy(original[i]));
          asset.body.updateMatrixWorld(true);
          const grip=CDMatch3DV24RugbyClips.gripCarrierSurface(
            THREE,asset.bones,partner.body,partner.bones,state.onset,{poleY,poleZ,referenceArms});
          const crossings=CDMatch3DV24MeshIntersections.probe(
            THREE,{body:asset.body,bones:asset.bones},partner,850);
          const eL=p(asset.bones,'lowerarm_l'),eR=p(asset.bones,'lowerarm_r');
          candidates.push({poleY,poleZ,leftM:grip.l.afterSurfaceMetres,
            rightM:grip.r.afterSurfaceMetres,intersections:crossings.properTriangleIntersections,
            elbowSeparationM:eL.distanceTo(eR),
            elbowLateralL:eL.clone().sub(center).dot(lateral),
            elbowLateralR:eR.clone().sub(center).dot(lateral)});
        }
        asset.bones.forEach((bone,i)=>bone.quaternion.copy(original[i]));
        asset.body.updateMatrixWorld(true);
        const base=candidates[0];
        elbowPoleTrial={candidates,
          eligible:candidates.slice(1).filter(t=>t.rightM<=base.rightM+.001
            &&t.leftM<=base.leftM+.001&&t.intersections<=base.intersections),
          status:'DIAGNOSTIC_ONLY_SKELETON_RESTORED'};
      }
      // Isolated anatomical preview at exactly the two independently tested
      // keyframes. The root, player GLBs and match runtime remain untouched.
      // If ANY measured criterion fails, restore the complete original pose.
      let anatomicalPreview=null;
      if(Math.abs(progress-.75)<1e-8 || progress===1){
        const angle=progress===1?.15:.20;
        const saved=asset.bones.map(b=>b.quaternion.clone());
        const baseline={leftM:surfaceGrip.l.afterSurfaceMetres,
          rightM:surfaceGrip.r.afterSurfaceMetres,
          intersections:collision.properTriangleIntersections};
        const clav=asset.bones.find(b=>b.name==='clavicle_r');
        clav.quaternion.multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0,0,1),angle));
        asset.body.updateMatrixWorld(true);
        const trial=CDMatch3DV24RugbyClips.gripCarrierSurface(
          THREE,asset.bones,partner.body,partner.bones,state.onset,{referenceArms});
        const crossing=CDMatch3DV24MeshIntersections.probe(
          THREE,{body:asset.body,bones:asset.bones},partner,850).properTriangleIntersections;
        let lowest=Infinity,sampled=0;
        asset.body.traverse(mesh=>{
          if(!mesh.isSkinnedMesh)return;
          const attr=mesh.geometry.getAttribute('position'),v=new THREE.Vector3();
          if(!attr)return;
          const stride=Math.max(1,Math.floor(attr.count/350));
          for(let i=0;i<attr.count;i+=stride){
            mesh.boneTransform(i,v.fromBufferAttribute(attr,i));mesh.localToWorld(v);
            lowest=Math.min(lowest,v.y);sampled++;
          }
        });
        const candidate={leftM:trial.l.afterSurfaceMetres,
          rightM:trial.r.afterSurfaceMetres,intersections:crossing,
          minSkinnedY:lowest,sampledSkinnedVertices:sampled};
        const accepted=candidate.rightM<baseline.rightM-.005 &&
          candidate.leftM<=baseline.leftM+.001 &&
          candidate.intersections<=baseline.intersections &&
          candidate.minSkinnedY>=.015 && candidate.sampledSkinnedVertices>=30;
        // A candidate is never shown before it has passed the *same*
        // ground, wrist and triangle constraints on all three LODs.
        asset.bones.forEach((bone,i)=>bone.quaternion.copy(saved[i]));
        asset.body.updateMatrixWorld(true);
        anatomicalPreview={angleRadians:angle,baseline,candidate,accepted,
          appliedToScreenshot:false,
          status:'DIAGNOSTIC_ONLY_REJECT_OR_DEFER_CROSS_LOD_PREVIEW'};
      }
      return {...state,meshIntersections:collision,approachShoulderTrial,relativePoseSweep,clavicleSweep,clavicleGripTrial,elbowPoleTrial,anatomicalPreview,handDistancesM:[p(asset.bones,'hand_l').distanceTo(target),p(asset.bones,'hand_r').distanceTo(target)],ik,surfaceGrip};
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
     assert preview and not preview['appliedToIsolatedScreenshot'],(lod,'unqualified pose preview forbidden',preview)
     repeat=grip_trial['repeatability']
     assert repeat is not None,(lod,'repeatability test missing')
     assert abs(repeat['first']['leftM']-repeat['second']['leftM'])<1e-5,(lod,'left wrist non-idempotent',repeat)
     assert abs(repeat['first']['rightM']-repeat['second']['rightM'])<1e-5,(lod,'right wrist non-idempotent',repeat)
     assert repeat['first']['intersections']==repeat['second']['intersections'],(lod,'skinned triangles non-idempotent',repeat)
     assert repeat['maxJointQuaternionDelta']<1e-5,(lod,'bones changed on repeated IK',repeat)
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
    if phase in (.75,1.0):
     preview=fall['anatomicalPreview']
     assert preview and not preview['appliedToScreenshot'],(lod,phase,'unqualified anatomy may not affect the screenshots',preview)
     assert preview['candidate']['sampledSkinnedVertices']>=30,(lod,phase,'missing real surface samples',preview)
     if preview['accepted']:
      assert preview['candidate']['minSkinnedY']>=.015,(lod,phase,'ground clearance regression',preview)
      assert preview['candidate']['intersections']<=preview['baseline']['intersections'],(lod,phase,'mesh crossing regression',preview)
    if phase==.75:
     approach=fall['approachShoulderTrial']
     assert approach and len(approach['samples'])==3,(lod,'approach skin probe absent',approach)
     assert all(item['intersections']>=0 and item['leftM']>=0 and item['rightM']>=0 for item in approach['samples']),(lod,'approach probe invalid',approach)
    if phase==1.0:
     pole=fall['elbowPoleTrial']
     # An elbow sweep is forbidden until a common clavicle pose has been
     # qualified; a missing sweep here is the intended safe diagnostic.
     if pole is not None:
      assert len(pole['candidates'])==5,(lod,'five real elbow pole profiles required',pole)
      assert all(v['intersections']>=0 and v['elbowSeparationM']>.05 for v in pole['candidates']),(lod,'invalid anatomical elbow pose',pole)
    fallSequence.append(fall)
    page.evaluate('renderer.render(scene,camera)')
    page.screenshot(path=str(OUT/f'lod{lod}-fall-{int(phase*100):03d}-side.jpg'),type='jpeg',quality=90)
    page.evaluate('camera.position.set(3.4,1.5,2.6);camera.lookAt(0,.85,.35);renderer.render(scene,camera)')
    page.screenshot(path=str(OUT/f'lod{lod}-fall-{int(phase*100):03d}-front.jpg'),type='jpeg',quality=90)
    if phase in (.75,1.0):
     # True close-up: focus camera on world-space wrist/elbow/skin rather
     # than cropping a distant TV image. Both viewpoints use the same target.
     page.evaluate("""()=>{
       const bone=name=>asset.bones.find(b=>b.name===name).getWorldPosition(new THREE.Vector3());
       const carrier=partner.bones.find(b=>b.name==='spine_03').getWorldPosition(new THREE.Vector3());
       const focus=bone('hand_l').add(bone('hand_r')).add(bone('lowerarm_l'))
         .add(bone('lowerarm_r')).add(carrier.multiplyScalar(2)).multiplyScalar(1/6);
       window.gripCameraFocus=focus.clone();
       camera.position.copy(focus).add(new THREE.Vector3(1.2,.40,.95));
       camera.lookAt(focus);renderer.render(scene,camera);
     }""")
     page.screenshot(path=str(OUT/f'lod{lod}-fall-{int(phase*100):03d}-grip-close-front.jpg'),type='jpeg',quality=92)
     page.evaluate("""()=>{
       camera.position.copy(window.gripCameraFocus).add(new THREE.Vector3(1.45,.30,.12));
       camera.lookAt(window.gripCameraFocus);renderer.render(scene,camera);
     }""")
     page.screenshot(path=str(OUT/f'lod{lod}-fall-{int(phase*100):03d}-grip-close-side.jpg'),type='jpeg',quality=92)
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
  anatomical_keyframes={phase:{x['lod']:x['anatomicalPreview'] for x in fallSequence if x['progress']==phase} for phase in (.75,1)}
  assert all(set(by_lod)=={0,1,2} for by_lod in anatomical_keyframes.values()),('missing LOD anatomical keyframes',anatomical_keyframes.keys())
  safe_keyframe_previews={str(phase):all(by_lod[lod]['accepted'] for lod in range(3))
    for phase,by_lod in anatomical_keyframes.items()}
  approach_profiles={x['lod']:x['approachShoulderTrial'] for x in fallSequence if x['progress']==.75}
  assert set(approach_profiles)=={0,1,2},('missing approach probes',approach_profiles.keys())
  safe_approach_angles=[angle for angle in (.10,.15,.20)
    if all(any(abs(item['angleRadians']-angle)<1e-8
               and item['rightM']<data['baseline']['rightM']-.005
               and item['leftM']<=data['baseline']['leftM']+.001
               and item['intersections']<=data['baseline']['intersections']
               for item in data['samples']) for data in approach_profiles.values())]
  elbow_profiles={x['lod']:x['elbowPoleTrial'] for x in fallSequence if x['progress']==1}
  assert set(elbow_profiles)=={0,1,2},('missing elbow phases',elbow_profiles.keys())
  safe_elbow_poles=[]
  if all(data is not None for data in elbow_profiles.values()):
   # Only evaluate a shared elbow pole when all 3 LODs produced safe
   # anatomical input poses. Otherwise expose the missing evidence.
   for index in range(1,5):
    candidates=[elbow_profiles[lod]['candidates'][index] for lod in range(3)]
    baselines=[elbow_profiles[lod]['candidates'][0] for lod in range(3)]
    assert len({(x['poleY'],x['poleZ']) for x in candidates})==1
    if all(x['rightM']<=base['rightM']+.001 and
           x['leftM']<=base['leftM']+.001 and
           x['intersections']<=base['intersections'] and
           x['elbowSeparationM']>=base['elbowSeparationM']+.005
           for x,base in zip(candidates,baselines)):
     safe_elbow_poles.append({'poleY':candidates[0]['poleY'],'poleZ':candidates[0]['poleZ']})
  pose_decision={'status':'DIAGNOSTIC_ONLY_NO_RUNTIME_RELOCATION',
    'safeSharedOffsets':safe_shared,'sharedClavicleAccepted':shared_clavicle_safe,'safeClavicleAngles':shared_clavicle_angles,
    'clavicleByLOD':clavicle_trials,'safeElbowPoles':safe_elbow_poles,'elbowByLOD':elbow_profiles,'safeApproachAngles':safe_approach_angles,'approachByLOD':approach_profiles,'safeAnatomicalKeyframes':safe_keyframe_previews,'anatomicalByPhase':anatomical_keyframes,'referenceByLOD':reference,
    'limits':'Sampled Body triangles are not exhaustive collision certification'}
  assert not errors and not external,(errors,external)
  (OUT/'report.json').write_text(json.dumps({'status':'TWO_RIG_VISUAL_PROBE_NOT_CONTACT_APPROVAL','poseDecision':pose_decision,'levels':results,'temporalSamples':temporal,'fallSequence':fallSequence,'errors':errors,'externalRequests':external,'limits':['Paired-rig arm IK aims at carrier torso; no coordinated impact dynamics or contact certification','No collision physics or engine mutation','Actual skinned-mesh ground and torso-horizontal metrics tested at impact; visual contact and runtime still unqualified']},indent=2)+'\n');b.close()
finally:s.shutdown()
