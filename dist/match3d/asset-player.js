'use strict';
/* Optional local skinned asset adapter. Procedural renderer remains the fallback. */
(function(root){
  const state={ready:false,error:null};
  root.CDMatch3DAssetPlayer=Object.freeze({
    status:()=>({ready:state.ready,error:state.error}),
    load:()=>Promise.resolve(false),
    build:()=>null
  });
})(typeof window!=='undefined'?window:globalThis);
