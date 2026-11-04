'use strict';
/* MATCH 3D broadcast visuals: offline procedural turf and soft player contact shadows. */
(function(root,factory){
 const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 if(root)root.CDMatch3DBroadcast=api;
})(typeof globalThis!=='undefined'?globalThis:null,function(){
 const clamp=(v,a,b)=>Math.max(a,Math.min(b,Number.isFinite(v)?v:a));
 function hash(x,y,seed=0){
  let n=Math.imul(x+seed+1013,374761393)+Math.imul(y+seed+719,668265263);
  n=Math.imul(n^(n>>>13),1274126177);return ((n^(n>>>16))>>>0)/4294967295;
 }
 function pixels(kind,size=64){
  const n=Math.max(16,Math.min(128,Math.floor(size)||64));
  const out=new Uint8Array(n*n*4);
  for(let y=0;y<n;y++)for(let x=0;x<n;x++){
   const p=(y*n+x)*4;
   if(kind==='shadow'){
    const dx=(x+.5-n/2)/(n*.5),dy=(y+.5-n/2)/(n*.5);
    const falloff=Math.pow(Math.max(0,1-dx*dx-dy*dy),3);
    out[p]=7;out[p+1]=16;out[p+2]=12;out[p+3]=Math.round(falloff*178);
   }else{
    const coarse=hash(Math.floor(x/4),Math.floor(y/4),27);
    const fine=hash(x,y,7);
    const blade=(x*3+y*5)%11===0?15:0;
    const shade=Math.round((coarse-.5)*22+(fine-.5)*26+blade);
    out[p]=clamp(45+shade,23,95);
    out[p+1]=clamp(109+shade,65,166);
    out[p+2]=clamp(65+shade,34,113);
    out[p+3]=255;
   }
  }
  return out;
 }
 function texture(T,kind){
  const tex=new T.DataTexture(pixels(kind),64,64,T.RGBAFormat,T.UnsignedByteType);
  tex.needsUpdate=true;tex.magFilter=T.LinearFilter;tex.minFilter=T.LinearMipmapLinearFilter;
  tex.generateMipmaps=true;
  if(kind==='grass'){
   tex.wrapS=T.RepeatWrapping;tex.wrapT=T.RepeatWrapping;
   tex.repeat.set(32,23);tex.anisotropy=4;
  }
  return tex;
 }
 function grassMaterial(T){
  return new T.MeshLambertMaterial({color:0x346e46,map:texture(T,'grass')});
 }
 function create(scene,T){
  const map=texture(T,'shadow'),geometry=new T.PlaneGeometry(3.3,2.1);
  const material=new T.MeshBasicMaterial({color:0xffffff,map,transparent:true,
   depthWrite:false,opacity:.60,side:T.DoubleSide});
  const shadows=new Map();
  function sync(players){
   if(!players)return;
   for(const [id,rig] of players){
    if(!rig?.position)continue;
    let mesh=shadows.get(id);
    if(!mesh){
     mesh=new T.Mesh(geometry,material);mesh.rotation.x=-Math.PI/2;
     mesh.position.y=.029;scene.add(mesh);shadows.set(id,mesh);
    }
    mesh.position.x=Number.isFinite(rig.position.x)?rig.position.x:0;
    mesh.position.z=Number.isFinite(rig.position.z)?rig.position.z:0;
    const elevation=clamp(rig.position.y,0,1.5);
    mesh.scale.setScalar(1+elevation*.28);
   }
   for(const [id,mesh] of shadows)if(!players.has(id)){scene.remove(mesh);shadows.delete(id);}
  }
  function dispose(){
   for(const mesh of shadows.values())scene.remove(mesh);
   shadows.clear();geometry.dispose();material.dispose();map.dispose();
  }
  return Object.freeze({sync,dispose,count:()=>shadows.size});
 }
 return Object.freeze({pixels,grassMaterial,create});
});