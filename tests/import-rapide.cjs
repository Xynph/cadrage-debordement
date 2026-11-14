'use strict';
// Import d'une carrière Monde par-dessus la carrière ouverte (recette Windows du vrai EXE : chaque réponse du
// moteur ≤ 20 s). Chemins accélérés de l'import, sans affaiblir ses contrôles :
// - la copie « bdt-before-import » reprend le document de reprise déjà créé par le worker (protectCurrent) au lieu
//   de recréer un second document de la même carrière ;
// - la confirmation ne refait pas la validation complète d'un document validé par parseSaveDocument dont
//   l'empreinte prouve que l'état n'a pas changé ; tout autre document reste validé, et l'empreinte reste contrôlée ;
// - createSaveDocument sérialise l'état une seule fois (empreinte, preuve, taille) : mêmes documents qu'avant.
const assert=require('node:assert/strict');
const {context}=require('./monde-harness.cjs');

const h=context(4242,{club:0});
try{
 h.week(3);
 // Empreinte sur texte : identique à l'empreinte historique, y compris avec des caractères hors ASCII.
 const empreintes=JSON.parse(h.run(`JSON.stringify([S,{a:'é😀\\u2028'},[1,null,'x'],''].map(v=>[saveChecksum(v),saveChecksumText(JSON.stringify(v))]))`));
 for(const [a,b] of empreintes)assert.equal(b,a,'saveChecksumText = saveChecksum');

 // Document créé : même document qu'une sérialisation directe (taille et empreinte).
 const doc=JSON.parse(h.run('JSON.stringify(createSaveDocument())'));
 assert.equal(doc.checksum,h.run('saveChecksum(JSON.parse(JSON.stringify(S)))'),'empreinte de l’état exporté');

 const avant=h.run('JSON.stringify(S)');
 const texte=h.command('export').meta.exportText;
 h.week(2);
 const ouverte=h.run('JSON.stringify(S)');
 assert.notEqual(ouverte,avant);
 // Import par le worker par-dessus la carrière ouverte : la copie de secours est celle de la carrière ouverte.
 h.command('import',{text:texte});
 assert.equal(h.run('JSON.stringify(S)'),avant,'carrière importée exacte');
 const secours=JSON.parse(h.store['bdt-before-import']);
 const relu=JSON.parse(h.run('JSON.stringify(parseSaveDocument(nativeSecours))'.replace('nativeSecours',JSON.stringify(h.store['bdt-before-import']))));
 assert.equal(JSON.stringify(relu.state),ouverte,'copie avant import : la carrière ouverte, relisible');
 assert.equal(typeof secours.exportedAt,'string');
 assert.equal(h.run("typeof nativeBeforeImportText"),'undefined','texte de reprise retiré après l’import');
 // Export après import : aller-retour exact.
 const apres=JSON.parse(h.command('export').meta.exportText),initial=JSON.parse(texte);
 assert.deepEqual([apres.checksum,apres.format,apres.exportVersion],[initial.checksum,initial.format,initial.exportVersion]);
 assert.equal(JSON.stringify(apres.state),JSON.stringify(initial.state),'état exporté identique');

 // Confirmation : un document validé puis modifié est refusé ; un document non issu de parseSaveDocument est validé.
 h.ctx.importTexte=texte;
 assert.equal(h.run("pendingSave=parseSaveDocument(importTexte);pendingSave.state.round=pendingSave.state.round+1;confirmSaveImport()"),false,'état modifié après vérification refusé');
 assert.equal(h.run('JSON.stringify(S)'),avant,'carrière conservée après refus');
 assert.equal(h.run("(()=>{const d=parseSaveDocument(importTexte);d.state.clubs[d.state.club].cash='invalide';d.checksum=saveChecksum(d.state);pendingSave={...d};return confirmSaveImport();})()"),false,'document recopié non validé : validation complète, refusé');
 assert.equal(h.run('JSON.stringify(S)'),avant,'carrière conservée');
 assert.equal(h.run("pendingSave=parseSaveDocument(importTexte);confirmSaveImport()"),true,'document validé inchangé accepté');
 assert.equal(h.run('JSON.stringify(S)'),avant);
 delete h.ctx.importTexte;
 console.log('import rapide : copie de secours reprise, validation non répétée, contrôles conservés');
}finally{h.close();}
