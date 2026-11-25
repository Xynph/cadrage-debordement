'use strict';
// Signe un export de carrière modifié par un test, comme le jeu le vérifie (dist/saves.js, parseSaveDocument) :
// l'empreinte porte sur l'état complet. Une carrière Monde dont l'état dépasse le plafond d'export sort au format
// réduit (exportVersion 2 ou 3 : marché et joueurs renvoyés au registre et au vivier par identifiant, depuis #1225
// dès les premières journées). parseSaveDocument reconstruit alors l'état avant de vérifier l'empreinte : on le
// reconstruit ici avec les fonctions du jeu, dans la VM du pont (createBridge({testVm:true}).vm).
function empreinte(text){
 let h=2166136261;
 for(let i=0;i<text.length;i++)h=Math.imul(h^text.charCodeAt(i),16777619);
 return (h>>>0).toString(16).padStart(8,'0');
}
// `doc` : document d'export (objet), modifié en place comme les anciens `signed(doc)` ; renvoie le texte à importer.
function signerExport(doc,vm){
 if(doc.exportVersion!==2&&doc.exportVersion!==3){doc.checksum=empreinte(JSON.stringify(doc.state));return JSON.stringify(doc);}
 if(!vm||typeof vm.run!=='function'||!vm.ctx)throw Error('Export réduit (exportVersion '+doc.exportVersion+') : passer bridge.vm, pont créé avec testVm:true.');
 vm.ctx.__signatureExport=JSON.stringify(doc);
 try{
  doc.checksum=vm.run(`(()=>{const d=JSON.parse(__signatureExport);
   if(d.exportVersion===3){expandSaveReferences(d.state);if(Array.isArray(d.state.market)&&d.state.market.some(p=>typeof p==='string'))d.state.market=expandChampMarket(d.state);}
   else d.state.market=expandChampMarket(d.state);
   return saveChecksum(d.state);})()`);
 }finally{delete vm.ctx.__signatureExport;}
 return JSON.stringify(doc);
}
module.exports={signerExport,empreinte};
