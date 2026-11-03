'use strict';
/* MATCH 3D: optional, render-only Three.js scene fed by the existing matchScene(). */
(function(){
 if(typeof match2D!=='function'||typeof matchScene!=='function'||!window.CDMatch3DAdapter)return;
 const original2D=match2D,bridge=window.CDMatch3DAdapter;
 let mode='2d',cameraMode='tv',sceneData=null,liveInstance=null,scheduled=false;
 const motion=window.CDMatch3DMotion,cameraGuide=window.CDMatch3DCamera,contact=window.CDMatch3DContact;
 if(!motion||!cameraGuide||!contact||!window.CDMatch3DPlayerModel)return;
 function setMode(next){if(!['2d','3d'].includes(next))return;mode=next;dispose();render();}
 function setCamera(next){if(!['tv','tactical'].includes(next))return;cameraMode=next;if(liveInstance)positionCamera(liveInstance.camera);}
 window.CDMatch3D=Object.freeze({setMode,setCamera,getMode:()=>mode});
 match2D=function(l){
  let scene;
  try{scene=bridge.normalize(matchScene(l));}catch(e){return original2D(l);}
  sceneData=scene;
  const legacy=original2D(l);
  const controls='<section class="card cd3d-panel" aria-label="Affichage du match"><div class="cd3d-toolbar"><strong>Vue du match</strong><button type="button" aria-pressed="'+(mode==='2d')+'" onclick="CDMatch3D.setMode(\'2d\')">2D</button><button type="button" aria-pressed="'+(mode==='3d')+'" onclick="CDMatch3D.setMode(\'3d\')">3D</button></div>'+
   (mode==='3d'?'<div class="cd3d-toolbar"><span>Caméra</span><button type="button" onclick="CDMatch3D.setCamera(\'tv\')">TV</button><button type="button" onclick="CDMatch3D.setCamera(\'tactical\')">Tactique</button><small>Reconstitution visuelle · moteur rugby inchangé</small></div><div id="cd3d-host" aria-label="Terrain de rugby 3D"></div><p class="cd3d-help">30 joueurs, ballon et phases issus du moteur de match. Affichage expérimental : mouvements schématiques interpolés.</p>':'');
  if(mode==='3d'&&!scheduled){scheduled=true;requestAnimationFrame(()=>{scheduled=false;mount();});}
  return mode==='3d'?controls:controls+legacy;
 };
 function positionCamera(camera){
  if(cameraMode==='tactical'){camera.position.set(0,115,.01);camera.up.set(0,0,-1);}
  else {camera.position.set(8,68,85);camera.up.set(0,1,0);}
  camera.lookAt(0,0,0);
 }
 function field(scene){
  const T=window.THREE;
  const grass=new T.Mesh(new T.PlaneGeometry(110,80),new T.MeshLambertMaterial({color:0x2c7548}));
  grass.rotation.x=-Math.PI/2;grass.position.y=-.025;scene.add(grass);
  const stripe=new T.MeshBasicMaterial({color:0x348355,side:T.DoubleSide});
  for(let x=-50;x<50;x+=20){const m=new T.Mesh(new T.PlaneGeometry(10,70),stripe);m.rotation.x=-Math.PI/2;m.position.set(x+5,.002,0);scene.add(m);}
  const lineMat=new T.LineBasicMaterial({color:0xf3f1df});
  function line(x1,z1,x2,z2){
   const g=new T.BufferGeometry().setFromPoints([new T.Vector3(x1,.045,z1),new T.Vector3(x2,.045,z2)]);
   scene.add(new T.Line(g,lineMat));
  }
  for(const x of [-50,-28,-10,0,10,28,50])line(x,-35,x,35);
  line(-50,-35,50,-35);line(-50,35,50,35);
  for(const x of [-50,50]){
   const p=new T.MeshStandardMaterial({color:0xeeeeee,metalness:.3,roughness:.5});
   for(const z of [-2.8,2.8]){const post=new T.Mesh(new T.CylinderGeometry(.16,.16,9,8),p);post.position.set(x,4.5,z);scene.add(post);}
   const bar=new T.Mesh(new T.CylinderGeometry(.14,.14,5.6,8),p);bar.rotation.x=Math.PI/2;bar.position.set(x,3,0);scene.add(bar);
  }
 }
 function makePlayer(scene,p){
  const T=window.THREE;
  const model=window.CDMatch3DPlayerModel;
  if(!model)return null;
  const group=model.build(T,p);scene.add(group);return group;
 }
 function dispose(){
  if(!liveInstance)return;const i=liveInstance;liveInstance=null;cancelAnimationFrame(i.raf);if(i.crowdAnimator)i.crowdAnimator.dispose();
  i.renderer.dispose();i.renderer.domElement.remove();
  i.scene.traverse(o=>{if(o.geometry)o.geometry.dispose();if(o.material){const mats=Array.isArray(o.material)?o.material:[o.material];mats.forEach(m=>m.dispose());}});
 }
 function mount(){
  if(mode!=='3d'||!sceneData)return;
  const host=document.getElementById('cd3d-host');if(!host)return;
  if(typeof window.THREE==='undefined'){host.textContent='Moteur graphique indisponible : utilisez la vue 2D.';return;}
  if(liveInstance){
   if(liveInstance.host!==host){liveInstance.host=host;host.appendChild(liveInstance.renderer.domElement);}
   const width=Math.max(300,host.clientWidth),height=Math.max(180,Math.floor(host.clientWidth*9/16));
   liveInstance.camera.aspect=width/height;liveInstance.camera.updateProjectionMatrix();
   liveInstance.renderer.setSize(width,height);
   update(liveInstance,sceneData);return;
  }
  dispose();
  const T=window.THREE;let renderer;
  try{renderer=new T.WebGLRenderer({antialias:true,alpha:false,powerPreference:'high-performance'});}
  catch(e){host.textContent='WebGL indisponible. Choisissez la vue 2D.';return;}
  const scene=new T.Scene();scene.background=new T.Color(0x101d19);field(scene);
  if(window.CDMatch3DStadium)window.CDMatch3DStadium.build(scene,T);
  const crowdMesh=window.CDMatch3DCrowd?window.CDMatch3DCrowd.build(scene,T):null;
  const crowdAnimator=crowdMesh&&window.CDMatch3DCrowdAnimation?window.CDMatch3DCrowdAnimation.create(crowdMesh,T,window.CDMatch3DCrowd.plan()):null;
  scene.add(new T.HemisphereLight(0xe6fbff,0x3e4436,2.2));
  const stadium=new T.Mesh(new T.RingGeometry(64,86,96),new T.MeshStandardMaterial({color:0x263c3b,roughness:1,side:T.DoubleSide}));
  stadium.rotation.x=-Math.PI/2;stadium.position.y=-.08;scene.add(stadium);
  const crowd=new T.Mesh(new T.RingGeometry(88,98,96),new T.MeshBasicMaterial({color:0x45605a,side:T.DoubleSide}));
  crowd.rotation.x=-Math.PI/2;crowd.position.y=.22;scene.add(crowd);
  const sun=new T.DirectionalLight(0xffffff,2.4);sun.position.set(30,80,10);scene.add(sun);
  const camera=new T.PerspectiveCamera(48,16/9,.1,500);positionCamera(camera);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,1.5));
  renderer.setSize(Math.max(300,host.clientWidth),Math.max(180,Math.floor(host.clientWidth*9/16)));
  renderer.outputEncoding=T.sRGBEncoding;
  host.append(renderer.domElement);
  const ball=new T.Mesh(new T.SphereGeometry(.58,12,8),new T.MeshStandardMaterial({color:0xf8e9c6}));
  ball.scale.set(1.4,.7,.85);scene.add(ball);
  const instance={host,renderer,scene,camera,ball,players:new Map(),crowdAnimator,raf:0,last:performance.now(),state:null,start:performance.now()};
  liveInstance=instance;update(instance,sceneData);
  function loop(now){
   if(liveInstance!==instance)return;
   const t=Math.min(1,(now-instance.start)/750),f=bridge.frame(instance.previous,instance.state,t);
   for(const p of f.players){const object=instance.players.get(p.id);if(object){
    const w=bridge.world(p),previous=instance.previous?.players?.find(q=>q.id===p.id)||p;
    const pose=motion.pose(previous,p,t,now-instance.start,p.slot+p.side*15);
    object.position.set(w.x,pose.bounce,w.z);
    object.rotation.y=-(pose.direction+Math.PI/2);
    const cue=contact.pose(instance.contact,p.id,now-instance.start);
    object.rotation.x=cue.fall;
    object.rotation.z=cue.roll;
    const parts=object.userData.motionParts;
    if(parts){parts.legs[0].rotation.x=pose.stride*.68;parts.legs[1].rotation.x=-pose.stride*.68;
     parts.knees[0].rotation.x=pose.kneeBend[0];parts.knees[1].rotation.x=pose.kneeBend[1];
     parts.arms[0].rotation.x=pose.armSwing*.75-cue.bracing*.55;parts.arms[1].rotation.x=-pose.armSwing*.75-cue.bracing*.55;
     parts.torso.rotation.x=pose.torsoLean+cue.lean;}
   }}
   const b=bridge.world(f.ball);instance.ball.position.set(b.x,1.25+Math.sin(t*Math.PI)*Math.min(5,Math.abs(instance.state.ball.x-instance.state.origin.x)*.2),b.z);
   // Presentation-only rotation: no change to ball position or match events.
   instance.ball.rotation.z=t*Math.PI*2;
   if(cameraMode==='tv'){
    const focus=cameraGuide.target(b),desired=cameraGuide.tvPosition(focus);
    const dt=Math.min(100,Math.max(0,now-instance.last));
    instance.camera.position.set(cameraGuide.smooth(instance.camera.position.x,desired.x,dt),desired.y,cameraGuide.smooth(instance.camera.position.z,desired.z,dt));
    instance.camera.lookAt(focus.x,focus.y,focus.z);
   }
   if(instance.crowdAnimator)instance.crowdAnimator.tick(now);
   instance.last=now;
   instance.renderer.render(instance.scene,instance.camera);
   instance.raf=requestAnimationFrame(loop);
  }
  instance.raf=requestAnimationFrame(loop);
 }
 function update(i,next){
  if(i.state?.key===next.key&&i.state?.players.length===next.players.length)return;
  i.previous=i.state||{players:next.players,ball:next.origin};i.state=next;i.start=performance.now();
  i.contact=contact.plan(next);
  if(i.crowdAnimator)i.crowdAnimator.event(next,i.start);
  const ids=new Set(next.players.map(p=>p.id));
  for(const [id,obj] of i.players)if(!ids.has(id)){i.scene.remove(obj);i.players.delete(id);}
  for(const p of next.players)if(!i.players.has(p.id))i.players.set(p.id,makePlayer(i.scene,p));
 }
 const observer=new MutationObserver(()=>{if(mode==='3d'&&document.getElementById('cd3d-host')&&!scheduled){scheduled=true;requestAnimationFrame(()=>{scheduled=false;mount();});}else if(liveInstance&&!liveInstance.host.isConnected)dispose();});
 observer.observe(document.getElementById('app')||document.body,{subtree:true,childList:true});
})();
