'use strict';
/* MATCH 3D: optional, render-only Three.js scene fed by the existing matchScene(). */
(function(){
 if(typeof match2D!=='function'||typeof matchScene!=='function'||!window.CDMatch3DAdapter)return;
 const original2D=match2D,bridge=window.CDMatch3DAdapter;
 let mode='2d',cameraMode='tv',sceneData=null,liveInstance=null,scheduled=false;
 const objects=[],previous=new Map();
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
  const T=window.THREE,group=new T.Group();
  const shirt=new T.MeshStandardMaterial({color:p.side===0?0xed8134:0x5bb6e0,roughness:.85});
  const skin=new T.MeshStandardMaterial({color:0xbd8e6d,roughness:1});
  const shorts=new T.MeshStandardMaterial({color:p.side===0?0x19312c:0xe5e6df});
  const torso=new T.Mesh(new T.CylinderGeometry(.65,.72,1.45,10),shirt);torso.position.y=1.5;group.add(torso);
  const head=new T.Mesh(new T.SphereGeometry(.39,9,7),skin);head.position.y=2.56;group.add(head);
  for(const s of [-1,1]){
   const leg=new T.Mesh(new T.CylinderGeometry(.21,.24,1,7),shorts);leg.position.set(s*.31,.5,0);group.add(leg);
   const arm=new T.Mesh(new T.CylinderGeometry(.19,.18,1.08,7),skin);arm.rotation.z=s*.25;arm.position.set(s*.82,1.55,0);group.add(arm);
  }
  const flat=new T.Mesh(new T.CircleGeometry(.95,16),new T.MeshBasicMaterial({color:p.featured?0xffd07d:p.side===0?0xffb27a:0x9adfff,transparent:true,opacity:.32}));
  flat.rotation.x=-Math.PI/2;flat.position.y=.06;group.add(flat);
  scene.add(group);return group;
 }
 function dispose(){
  if(!liveInstance)return;const i=liveInstance;liveInstance=null;cancelAnimationFrame(i.raf);
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
  scene.add(new T.HemisphereLight(0xe6fbff,0x3e4436,2.2));
  const sun=new T.DirectionalLight(0xffffff,2.4);sun.position.set(30,80,10);scene.add(sun);
  const camera=new T.PerspectiveCamera(48,16/9,.1,500);positionCamera(camera);
  renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,1.5));
  renderer.setSize(Math.max(300,host.clientWidth),Math.max(180,Math.floor(host.clientWidth*9/16)));
  renderer.outputEncoding=T.sRGBEncoding;
  host.append(renderer.domElement);
  const ball=new T.Mesh(new T.SphereGeometry(.58,12,8),new T.MeshStandardMaterial({color:0xf8e9c6}));
  ball.scale.set(1.4,.7,.85);scene.add(ball);
  const instance={host,renderer,scene,camera,ball,players:new Map(),raf:0,last:performance.now(),state:null,start:performance.now()};
  liveInstance=instance;update(instance,sceneData);
  function loop(now){
   if(liveInstance!==instance)return;
   const t=Math.min(1,(now-instance.start)/750),f=bridge.frame(instance.previous,instance.state,t);
   for(const p of f.players){const object=instance.players.get(p.id);if(object){const w=bridge.world(p);object.position.set(w.x,0,w.z);}}
   const b=bridge.world(f.ball);instance.ball.position.set(b.x,1.25+Math.sin(t*Math.PI)*Math.min(5,Math.abs(instance.state.ball.x-instance.state.origin.x)*.2),b.z);
   instance.renderer.render(instance.scene,instance.camera);
   instance.raf=requestAnimationFrame(loop);
  }
  instance.raf=requestAnimationFrame(loop);
 }
 function update(i,next){
  if(i.state?.key===next.key&&i.state?.players.length===next.players.length)return;
  i.previous=i.state||{players:next.players,ball:next.origin};i.state=next;i.start=performance.now();
  const ids=new Set(next.players.map(p=>p.id));
  for(const [id,obj] of i.players)if(!ids.has(id)){i.scene.remove(obj);i.players.delete(id);}
  for(const p of next.players)if(!i.players.has(p.id))i.players.set(p.id,makePlayer(i.scene,p));
 }
 const observer=new MutationObserver(()=>{if(mode==='3d'&&document.getElementById('cd3d-host')&&!scheduled){scheduled=true;requestAnimationFrame(()=>{scheduled=false;mount();});}else if(liveInstance&&!liveInstance.host.isConnected)dispose();});
 observer.observe(document.getElementById('app')||document.body,{subtree:true,childList:true});
})();
