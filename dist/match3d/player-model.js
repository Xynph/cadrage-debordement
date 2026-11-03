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
 function build(T,player){
  const look=appearance(player);
  const group=new T.Group();
  const material=(color,roughness=.88)=>new T.MeshStandardMaterial({color,roughness});
  const kit=material(look.shirt),trim=material(look.trim),shorts=material(look.shorts),
   socks=material(look.socks),skin=material(look.skin),boots=material(0x171d20,.68);
  function mesh(geo,mat,parent,x,y,z){const obj=new T.Mesh(geo,mat);obj.position.set(x,y,z);parent.add(obj);return obj;}
  // Tapered body, shoulder yoke, visible collar and seams.
  const torso=mesh(new T.CylinderGeometry(.48,.64,1.18,12),kit,group,0,1.68,0);
  mesh(new T.SphereGeometry(.53,12,8),kit,group,0,2.15,0).scale.set(1.22,.34,.80);
  mesh(new T.CylinderGeometry(.19,.24,.12,12),trim,group,0,2.34,0);
  mesh(new T.CylinderGeometry(.16,.17,.25,10),skin,group,0,2.44,0);
  const head=mesh(new T.SphereGeometry(.36,12,10),skin,group,0,2.77,0);
  head.scale.set(.92,1.13,.92);
  const hair=material(0x262523);
  const cap=mesh(new T.SphereGeometry(.34,12,8,0,Math.PI*2,0,Math.PI*.38),hair,group,0,2.85,0);
  cap.scale.set(.95,.9,.95);
  // Front is negative Z. Kit markings remain geometrical, offline and cheap.
  mesh(new T.BoxGeometry(.28,.28,.035),trim,group,0,1.78,-.57);
  for(const x of [-.38,.38]){
   mesh(new T.BoxGeometry(.07,.74,.035),trim,group,x,1.80,-.48);
  }
  const legs=[],arms=[],knees=[];
  for(const sign of [-1,1]){
   const shoulder=new T.Group();shoulder.position.set(sign*.69,2.14,0);group.add(shoulder);
   mesh(new T.CylinderGeometry(.24,.19,.42,9),kit,shoulder,sign*.07,-.19,0);
   mesh(new T.CylinderGeometry(.145,.12,.60,9),skin,shoulder,sign*.09,-.69,0);
   mesh(new T.SphereGeometry(.145,8,7),skin,shoulder,sign*.09,-1.01,0);
   mesh(new T.BoxGeometry(.065,.27,.05),trim,shoulder,sign*.26,-.18,-.02);
   arms.push(shoulder);
   const hip=new T.Group();hip.position.set(sign*.32,1.11,0);group.add(hip);
   mesh(new T.CylinderGeometry(.32,.255,.48,10),shorts,hip,0,-.23,0);
   mesh(new T.CylinderGeometry(.205,.17,.48,9),skin,hip,0,-.70,0);
   const knee=new T.Group();knee.position.set(0,-.95,0);hip.add(knee);
   mesh(new T.CylinderGeometry(.165,.145,.53,9),socks,knee,0,-.28,0);
   const shoe=mesh(new T.BoxGeometry(.30,.17,.56),boots,knee,0,-.58,-.14);
   shoe.rotation.x=-.06;
   legs.push(hip);knees.push(knee);
  }
  group.userData.motionParts={legs,arms,knees,torso};
  const ring=mesh(new T.CircleGeometry(.94,20),new T.MeshBasicMaterial({
   color:player?.featured?0xffd07d:look.side===0?0xffb27a:0x9adfff,transparent:true,opacity:.28
  }),group,0,.045,0);
  ring.rotation.x=-Math.PI/2;
  return group;
 }
 return Object.freeze({appearance,build});
});