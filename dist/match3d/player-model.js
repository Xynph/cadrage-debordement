'use strict';
/* Procedural player art, offline and render-only. No assets, no game-state writes. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DPlayerModel=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 const palette=Object.freeze([
  Object.freeze({shirt:0xed8134,trim:0xffe7bb,shorts:0x19312c,socks:0x19312c}),
  Object.freeze({shirt:0x5bb6e0,trim:0xf7f6eb,shorts:0xe5e6df,socks:0x25617a})
 ]);
 const skinTones=Object.freeze([0x8a5239,0xb87c57,0xd5a47e,0xf0c6a2]);
 function appearance(player){
  const side=player&&player.side===1?1:0;
  const slot=Number.isFinite(player?.slot)?Math.max(0,Math.floor(player.slot)):0;
  return Object.freeze({...palette[side],skin:skinTones[(slot*7+side)%skinTones.length],number:slot%15+1,side});
 }
 const glyphs=Object.freeze({
  '0':'abcefd', '1':'bc', '2':'abged', '3':'abgcd', '4':'fgbc',
  '5':'afgcd', '6':'afgecd', '7':'abc', '8':'abcdefg', '9':'abcdfg'
 });
 function jerseyDigits(number){
  const n=Number.isFinite(number)?Math.max(1,Math.min(99,Math.floor(number))):1;
  return String(n).split('').map(d=>glyphs[d]||glyphs['1']);
 }
 function addJerseyNumber(T,group,number,ink){
  const digits=jerseyDigits(number);
  const bars=Object.freeze({
   a:[0,.24,.20,.045],b:[.115,.125,.045,.19],c:[.115,-.125,.045,.19],
   d:[0,-.24,.20,.045],e:[-.115,-.125,.045,.19],f:[-.115,.125,.045,.19],
   g:[0,0,.20,.045]
  });
  const width=digits.length===2?.32:0;
  const root=new T.Group();root.position.set(0,1.81,.63);group.add(root);
  for(let i=0;i<digits.length;i++){
   const digit=new T.Group();digit.position.set((i-(digits.length-1)/2)*width,0,0);root.add(digit);
   for(const key of digits[i]){
    const b=bars[key],segment=new T.Mesh(new T.BoxGeometry(b[2],b[3],.025),ink);
    segment.position.set(b[0],b[1],.015);digit.add(segment);
   }
  }
  return root;
 }
 function build(T,player){
  const look=appearance(player);
  const group=new T.Group();
  const material=(color,roughness=.88)=>new T.MeshStandardMaterial({color,roughness});
  const kit=material(look.shirt),trim=material(look.trim),shorts=material(look.shorts),
   socks=material(look.socks),skin=material(look.skin),boots=material(0x171d20,.68);
  function mesh(geo,mat,parent,x,y,z){const obj=new T.Mesh(geo,mat);obj.position.set(x,y,z);parent.add(obj);return obj;}
  // Tapered body, shoulder yoke, visible collar and seams.
  const torso=mesh(new T.CylinderGeometry(.43,.57,1.18,16),kit,group,0,1.68,0);
  // Gentle V-shape and a narrower waist: keep lightweight primitives for thirty players.
  mesh(new T.SphereGeometry(.37,12,8),shorts,group,0,1.12,0).scale.set(1.42,.43,1.02);
  mesh(new T.SphereGeometry(.52,16,10),kit,group,0,2.15,0).scale.set(1.32,.36,.83);
  mesh(new T.CylinderGeometry(.19,.24,.12,12),trim,group,0,2.34,0);
  mesh(new T.CylinderGeometry(.16,.17,.25,10),skin,group,0,2.44,0);
  const head=mesh(new T.SphereGeometry(.32,14,12),skin,group,0,2.77,0);
  head.scale.set(.91,1.15,.92);
  mesh(new T.SphereGeometry(.105,9,7),skin,group,0,2.73,-.29).scale.set(.77,.72,.78);
  const hair=material(0x262523);
  const cap=mesh(new T.SphereGeometry(.315,12,8,0,Math.PI*2,0,Math.PI*.38),hair,group,0,2.85,0);
  cap.scale.set(.95,.9,.95);
  // Front is negative Z. Kit markings remain geometrical, offline and cheap.
  mesh(new T.BoxGeometry(.28,.28,.035),trim,group,0,1.78,-.57);
  for(const x of [-.38,.38]){
   mesh(new T.BoxGeometry(.07,.74,.035),trim,group,x,1.80,-.48);
  }
  const jerseyNumber=addJerseyNumber(T,group,look.number,trim);
  const legs=[],arms=[],knees=[],elbows=[];
  for(const sign of [-1,1]){
   const shoulder=new T.Group();shoulder.position.set(sign*.69,2.14,0);group.add(shoulder);
   mesh(new T.SphereGeometry(.235,10,8),kit,shoulder,sign*.07,-.09,0).scale.set(1.05,.86,1.02);
   mesh(new T.CylinderGeometry(.225,.17,.43,10),kit,shoulder,sign*.07,-.27,0);
   const elbow=new T.Group();elbow.position.set(sign*.09,-.49,0);shoulder.add(elbow);
   mesh(new T.SphereGeometry(.15,10,8),skin,elbow,0,0,0);
   mesh(new T.CylinderGeometry(.155,.11,.54,10),skin,elbow,0,-.30,0);
   mesh(new T.SphereGeometry(.14,10,8),skin,elbow,0,-.59,0);
   mesh(new T.BoxGeometry(.065,.27,.05),trim,shoulder,sign*.26,-.18,-.02);
   arms.push(shoulder);elbows.push(elbow);
   const hip=new T.Group();hip.position.set(sign*.32,1.11,0);group.add(hip);
   mesh(new T.SphereGeometry(.31,10,8),shorts,hip,0,-.08,0).scale.set(1.05,.84,1.04);
   mesh(new T.CylinderGeometry(.29,.235,.48,12),shorts,hip,0,-.27,0);
   mesh(new T.CylinderGeometry(.22,.175,.48,10),skin,hip,0,-.70,0);
   const knee=new T.Group();knee.position.set(0,-.95,0);hip.add(knee);
   mesh(new T.SphereGeometry(.185,9,8),skin,knee,0,-.02,0);
   mesh(new T.CylinderGeometry(.18,.135,.53,10),socks,knee,0,-.28,0);
   const shoe=mesh(new T.BoxGeometry(.30,.17,.56),boots,knee,0,-.58,-.14);
   shoe.rotation.x=-.06;
   legs.push(hip);knees.push(knee);
  }
  group.userData.motionParts={legs,arms,knees,elbows,torso};
  group.userData.premiumAthleteRig=true;
  group.userData.jerseyNumber=jerseyNumber;
  const ring=mesh(new T.CircleGeometry(.94,20),new T.MeshBasicMaterial({
   color:player?.featured?0xffd07d:look.side===0?0xffb27a:0x9adfff,transparent:true,opacity:.28
  }),group,0,.045,0);
  ring.rotation.x=-Math.PI/2;
  return group;
 }
 return Object.freeze({appearance,jerseyDigits,build});
});