'use strict';
(function(root){
 if(!root||typeof root.render!=='function'||root.__cdV101V116DashboardBridge)return;
 root.__cdV101V116DashboardBridge=true;
 const previous=root.render;
 // The native Bureau du manager uses view='dashboard', not view='bureau'.
 // Preserve the original modules and only bridge their existing read-only panel renderers.
 root.render=function(){
  const result=previous.apply(this,arguments);
  if(typeof document==='undefined'||typeof view==='undefined'||view!=='dashboard')return result;
  const state=typeof S!=='undefined'?S:root.S;
  const target=document.querySelector('#app .layout .main');
  if(!state||!target||typeof target.insertAdjacentHTML!=='function')return result;
  for(const name of ['CDSportingDirectorV105V110','CDFanExperienceV111V116']){
   const api=root[name];
   if(!api||typeof api.panel!=='function')continue;
   const content=api.panel(state);
   if(content)target.insertAdjacentHTML('beforeend',content);
  }
  return result;
 };
})(typeof globalThis==='object'?globalThis:this);
