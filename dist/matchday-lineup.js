'use strict';
// MATCHDAY-02 : propositions consultatives de feuille à 23, sans moteur de match parallèle.
let matchday02Mode='equilibre';
const MATCHDAY02_MODES={
 equilibre:'Équilibrée',
 fraicheur:'Fraîcheur',
 performance:'Performance'
};
function matchday02Allowed(){
 return !!S&&!S.live&&S.phase!=='ended'&&!!nextMatch();
}
function matchday02Fingerprint(){
 if(!S)return '';
 const data=[S.club,S.season,S.round,S.phase,!!S.live,S.lineup,S.reserves,
  club().players.map(p=>[p.id,p.fam,p.pos,p.rating,p.condition,p.injury,
   physicalLoadValue(p),p.skills])];
 let hash=2166136261;
 for(const ch of JSON.stringify(data)){
  hash^=ch.charCodeAt(0);hash=Math.imul(hash,16777619);
 }
 return (hash>>>0).toString(36);
}
function matchday02Eligible(p,slot){
 return !!p&&!p.injury&&(slot<15?slotEligible(p,slot):benchEligible(p,slot-15));
}
function matchday02Score(p,slot,mode){
 const role=roleNote(p,slot<15?FAMILIES[slot]:p.fam);
 const load=physicalLoadValue(p);
 if(mode==='fraicheur')return role*.55+p.condition*.52-load*.72;
 if(mode==='performance')return role*1.1+p.condition*.12-load*.14;
 return fitScore(p,slot<15?FAMILIES[slot]:p.fam)-load*.08;
}
function matchday02Check(sheet){
 const errors=[];
 if(!sheet||!Array.isArray(sheet.lineup)||!Array.isArray(sheet.bench)||
    sheet.lineup.length!==15||sheet.bench.length!==8)
  return ['La proposition ne comporte pas 15 titulaires et 8 remplaçants.'];
 const ids=[...sheet.lineup,...sheet.bench].filter(Boolean);
 if(ids.length!==23)errors.push('Effectif insuffisant : '+(23-ids.length)+' poste(s) non pourvu(s).');
 if(new Set(ids).size!==ids.length)errors.push('Un joueur apparaît plusieurs fois.');
 [...sheet.lineup,...sheet.bench].forEach((id,slot)=>{
  const p=club().players.find(x=>x.id===id);
  if(!matchday02Eligible(p,slot))
   errors.push('Poste '+(slot+1)+' : aucun joueur admissible et disponible.');
 });
 return errors;
}
function matchday02Proposal(mode='equilibre'){
 if(!Object.hasOwn(MATCHDAY02_MODES,mode)||!matchday02Allowed())return null;
 let sheet;
 if(mode==='equilibre'){
  sheet=buildSheet(club());
 }else{
  // Affectation prioritaire des postes rares, suivie de la réparation native.
  const preferred=Array(15).fill(null),preferredBench=Array(8).fill(null),used=new Set();
  const slots=Array.from({length:23},(_,i)=>i).sort((a,b)=>
   club().players.filter(p=>matchday02Eligible(p,a)).length-
   club().players.filter(p=>matchday02Eligible(p,b)).length||a-b);
  for(const slot of slots){
   const candidates=club().players.filter(p=>!used.has(p.id)&&matchday02Eligible(p,slot))
    .sort((a,b)=>matchday02Score(b,slot,mode)-matchday02Score(a,slot,mode)||
     String(a.id).localeCompare(String(b.id)));
   if(candidates.length){
    const id=candidates[0].id;used.add(id);
    if(slot<15)preferred[slot]=id;else preferredBench[slot-15]=id;
   }
  }
  sheet=buildSheet(club(),preferred,preferredBench);
 }
 const errors=matchday02Check(sheet);
 const old=[...S.lineup,...S.reserves],next=[...sheet.lineup,...sheet.bench];
 const changes=next.map((id,i)=>id!==old[i]?i+1:null).filter(Boolean);
 const selected=next.map(id=>club().players.find(p=>p.id===id)).filter(Boolean);
 const atRisk=selected.filter(p=>p.condition<65||physicalLoadValue(p)>=55);
 const average=selected.length?Math.round(selected.reduce((total,p,i)=>
   total+matchday02Score(p,i,mode),0)/selected.length):0;
 return {mode,label:MATCHDAY02_MODES[mode],sheet,errors,changes,
  risk:atRisk.length,average,fingerprint:matchday02Fingerprint()};
}
function matchday02Select(mode){
 if(!Object.hasOwn(MATCHDAY02_MODES,mode)||!matchday02Allowed())return;
 matchday02Mode=mode;render();
}
function matchday02Apply(mode,fingerprint){
 if(!matchday02Allowed()||!Object.hasOwn(MATCHDAY02_MODES,mode)){
  toast('Composition indisponible pendant le match ou hors préparation.');return false;
 }
 if(fingerprint!==matchday02Fingerprint()){
  toast('La feuille ou l’effectif a changé : actualisez la proposition.');render();return false;
 }
 const suggestion=matchday02Proposal(mode);
 if(!suggestion||suggestion.errors.length||suggestion.fingerprint!==fingerprint){
  toast('Proposition incomplète : vérifiez la couverture des postes.');render();return false;
 }
 // Une seule transaction cohérente et une seule sauvegarde, jamais 23 écritures.
 S.lineup=[...suggestion.sheet.lineup];
 S.reserves=[...suggestion.sheet.bench];
 save();render();toast('Composition du staff appliquée aux 23 joueurs.');
 return true;
}
function matchday02View(){
 if(!matchday02Allowed())return '';
 const options=Object.entries(MATCHDAY02_MODES).map(([mode,label])=>
  '<button type="button" class="small '+(mode===matchday02Mode?'dark':'')+
  '" aria-pressed="'+(mode===matchday02Mode)+'" onclick="matchday02Select(\''+mode+'\')">'+label+'</button>').join('');
 const p=matchday02Proposal(matchday02Mode);
 if(!p)return '';
 const esc=typeof visualEscape==='function'?visualEscape:(value=>
  String(value).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])));
 const list=[...p.sheet.lineup,...p.sheet.bench];
 const rows=list.map((id,i)=>{
  const person=club().players.find(x=>x.id===id);
  const old=club().players.find(x=>x.id===(i<15?S.lineup[i]:S.reserves[i-15]));
  const label=i<15?POS[i]:BENCH_LABELS[i-15];
  return '<tr><td>'+(i+1)+'</td><td>'+esc(label)+'</td><td>'+esc(person?.name||'Non pourvu')+
   '</td><td>'+esc(old?.name||'—')+'</td><td>'+esc(person?Math.round(person.condition)+' % / charge '+physicalLoadValue(person):'—')+
   '</td></tr>';
 }).join('');
 const changes=p.changes.length+' changement(s) de poste';
 const errors=p.errors.length?'<div class="notice danger" role="alert">'+
  p.errors.slice(0,5).map(esc).join(' ')+'</div>':'';
 return '<section class="card cd-lineup" aria-label="Assistant de composition">'+
  '<div class="cardtitle"><h2>Assistant de composition · XV + 8</h2><span class="tag">VOTRE DÉCISION</span></div>'+
  '<p class="help">Le staff propose trois approches. Aucune composition n’est modifiée sans votre confirmation. Les notes sont des indications de jeu.</p>'+
  '<div class="cd-lineup-modes" role="group" aria-label="Approche de sélection">'+options+'</div>'+
  '<div class="cd-lineup-kpis"><div><strong>'+changes+'</strong><small>Par rapport à votre feuille</small></div>'+
  '<div><strong>'+p.risk+'</strong><small>Joueur(s) à ménager</small></div>'+
  '<div><strong>'+p.average+'</strong><small>Indice indicatif du profil</small></div></div>'+
  errors+'<div class="cd-lineup-scroll"><table><thead><tr><th>#</th><th>Poste</th><th>Proposition</th>'+
  '<th>Actuel</th><th>Condition / charge</th></tr></thead><tbody>'+rows+'</tbody></table></div>'+
  '<div class="cd-lineup-actions"><button type="button" class="dark" onclick="matchday02Apply(\''+
  p.mode+'\',\''+p.fingerprint+'\')"'+(p.errors.length?' disabled':'')+
  '>Appliquer cette composition</button>'+
  '<button type="button" onclick="prepareSquad(\'sheet\')">Modifier les 23 manuellement →</button></div>'+
  (p.errors.length?'<p class="help">Aucun joueur fictif ni promotion automatique. Corrigez votre effectif avant toute application.</p>':'')+
  '</section>';
}
