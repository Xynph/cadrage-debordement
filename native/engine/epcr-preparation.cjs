'use strict';

const eligibility = require('./epcr-eligibility.cjs');
const competitions = ['champions', 'challenge'];
const labels = {
 'unsupported-season':'Ce diagnostic couvre uniquement la saison 2026/27.',
 'unsupported-competition':'Compétition européenne non prise en charge.',
 'registration-size':'La liste proposée dépasse 42 joueurs.',
 'registration-front-row':'La liste doit compter au moins dix joueurs qualifiés de première ligne.',
 'sheet-size':'La feuille doit comporter quinze titulaires et de 19 à 23 joueurs au total.',
 'sheet-unregistered-player':'Un joueur de la feuille est absent de la liste proposée.',
 'sheet-duplicate-player':'Un joueur apparaît plusieurs fois sur la feuille.',
 'sheet-front-row':'La feuille doit compter au moins six premières lignes qualifiées.',
 'starter-front-row-LH':'La qualification du pilier gauche titulaire est à vérifier.',
 'starter-front-row-HK':'La qualification du talonneur titulaire est à vérifier.',
 'starter-front-row-TH':'La qualification du pilier droit titulaire est à vérifier.',
 'replacement-front-row':'Trois remplaçants distincts doivent couvrir pilier gauche, talonneur et pilier droit.',
 'sheet-qualification-mismatch':'La feuille ne peut pas ajouter une qualification absente de la liste.'
};
function describe(result) {
 return {...result,messages:result.violations.map(i=>labels[i.code]||'Données de liste invalides.'),
  pendingMessages:result.unknowns.map(i=>labels[i.code]||'Une qualification reste à confirmer.')};
}
function memberships(model) {
 if(model?.meta?.mode!=='world'||!model.club||!Array.isArray(model.leagues))return [];
 return model.leagues.filter(c=>competitions.includes(c.id)&&
  ((c.pools||[]).some(p=>(p.rows||[]).some(r=>r.id===model.club.id))||(c.transfers||[]).includes(model.club.id))).map(c=>c.id);
}
function project(model,payload) {
 const entered=memberships(model);
 if(!entered.length){if(payload!==undefined)throw Error('Votre club ne participe pas à une coupe européenne.');return null;}
 if(payload!==undefined&&(!payload||typeof payload!=='object'||Array.isArray(payload)||Object.keys(payload).some(k=>!['registeredIds','competitionId'].includes(k))))throw Error('Paramètres de préparation européenne invalides.');
 const competitionId=payload?.competitionId??(entered.includes(model.next?.competitionId)?model.next.competitionId:entered[0]);
 if(!entered.includes(competitionId))throw Error('Votre club ne participe pas à cette coupe européenne.');
 // A playing position is not a club/Union attestation. The current career
 // schema has no certification field; never manufacture evidence from fam/pos.
 const candidates=model.squad.map(p=>({id:p.id,name:p.name,pos:p.pos,frontRow:null,qualificationKnown:false}));
 const owned=new Set(candidates.map(p=>p.id));
 const registeredIds=payload===undefined?candidates.map(p=>p.id):payload.registeredIds;
 if(!Array.isArray(registeredIds)||(payload!==undefined&&registeredIds.length>100)||registeredIds.some(id=>typeof id!=='string'||!id.length||id.length>256||!owned.has(id))||new Set(registeredIds).size!==registeredIds.length)throw Error('La liste proposée doit contenir des identifiants uniques de votre effectif (100 au maximum).');
 const registered=registeredIds.map(id=>candidates.find(p=>p.id===id));
 const selected=ids=>(ids||[]).map(id=>candidates.find(p=>p.id===id)||{id,frontRow:null});
 const startYear=2025+model.meta.season,season=startYear+'/'+String(startYear+1).slice(-2),options={season,competitionId};
 const profile=eligibility.profile(options);
 return {season,competitionId,competitionName:competitionId==='champions'?'Coupe des champions':'Challenge européen',supported:profile.covered,
  notice:profile.covered?'Brouillon de préparation, sans inscription officielle. Les qualifications de première ligne et les conditions contractuelles restent à confirmer auprès du club et de la fédération.':'Cette saison ne dispose pas d’un profil EPCR vérifié ; aucune inscription ni règle nouvelle n’est appliquée.',
  source:profile.source,sourceScope:profile.sourceScope,candidates,registeredIds:registeredIds.slice(),
  registration:describe(eligibility.registration(registered,options)),
  teamSheet:describe(eligibility.teamSheet(selected(model.lineup),selected(model.reserves),registered,options))};
}
module.exports={project,memberships};
