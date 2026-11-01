'use strict';
// LNR-02: données sourcées en lecture seule ; décisions par moteur natif.
let lnr05Filter='all',lnr05Selected=null;
const LNR05_LOOKUP=new Map(LNR05_EVIDENCE.players.map(p=>[p[0],p]));
function lnr05Enabled(){return typeof S!=='undefined'&&!!S&&typeof lnrCareerMode==='function'&&lnrCareerMode(S)}
function lnr05Proof(id){return LNR05_LOOKUP.get(id)||null}
function lnr05Escape(v){return typeof lnrEscape==='function'?lnrEscape(v):String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function lnr05Measure(v,suffix){return v==null?'Non renseigné':v+suffix}
function lnr05Locked(){return !S||!!S.live||S.phase==='ended'}
function lnr05Token(){
 if(!lnr05Enabled())return '';
 const data=[S.club,S.season,S.round,S.phase,!!S.live,S.lineup,S.reserves,club().players.map(p=>[p.id,p.injury,p.condition,p.pos,p.fam])];
 let h=2166136261;for(const ch of JSON.stringify(data)){h^=ch.charCodeAt(0);h=Math.imul(h,16777619)}
 return (h>>>0).toString(36);
}
function lnr05FilterBy(mode){
 if(!lnr05Enabled()||!['all','evidence','missing','physical'].includes(mode))return false;
 lnr05Filter=mode;render();return true;
}
function lnr05Pick(id){if(!lnr05Enabled()||!player(id))return false;lnr05Selected=id;render();return true}
function lnr05Proposal(id){
 if(!lnr05Enabled()||lnr05Locked())return null;
 const p=player(id);if(!p||!lnr05Proof(id)||p.injury)return null;
 const prior=[...S.lineup,...S.reserves],already=prior.indexOf(id),token=lnr05Token();
 if(already!==-1)return {already:true,slot:already,token};
 const slot=Array.from({length:23},(_,i)=>i).find(i=>i<15?slotEligible(p,i):benchEligible(p,i-15));
 if(slot===undefined)return null;
 const pref=S.lineup.slice(),bench=S.reserves.slice();
 if(slot<15)pref[slot]=id;else bench[slot-15]=id;
 const sheet=buildSheet(club(),pref,bench),next=[...sheet.lineup,...sheet.bench];
 const valid=next.length===23&&next.every(Boolean)&&new Set(next).size===23&&next.includes(id)&&
  next.every((key,i)=>{const q=club().players.find(p=>p.id===key);return !!q&&!q.injury&&(i<15?slotEligible(q,i):benchEligible(q,i-15))});
 const changes=next.filter((key,i)=>key!==prior[i]).length;
 return {token,id,slot,changes,valid,sheet};
}
function lnr05Apply(id,token){
 if(!lnr05Enabled()||lnr05Locked()||token!==lnr05Token()){
  toast('Composition périmée ou match en cours : actualisez le choix.');render();return false;
 }
 const p=lnr05Proposal(id);
 if(!p||!p.valid||p.token!==token){toast('Aucune feuille valide à 23 pour ce joueur.');render();return false}
 S.lineup=p.sheet.lineup.slice();S.reserves=p.sheet.bench.slice();
 save();render();toast('Feuille à 23 confirmée avec les règles natives.');return true;
}
function lnr05Compare(id){if(!lnr05Enabled()||!player(id))return false;toggleCompare(id);return true}
function lnr05Sheet(){if(lnr05Enabled()){squadTab='sheet';render()}}
function lnr05Health(){if(lnr05Enabled()){squadTab='health';render()}}
// Conseils fondes sur les aptitudes du moteur ; aucune statistique sportive officielle inferee.
function lnr05AdviceCandidates(limit=3){
 if(!lnr05Enabled()||lnr05Locked())return [];
 const chosen=new Set([...S.lineup,...S.reserves]);
 return club().players.filter(p=>p.id.startsWith('lnr:')&&!chosen.has(p.id)&&!p.injury&&lnr05Proof(p.id))
  .map(p=>{
   const proposal=lnr05Proposal(p.id);
   if(!proposal?.valid||!Number.isInteger(proposal.slot)||proposal.slot>=15)return null;
   const index=proposal.slot,old=club().players.find(q=>q.id===S.lineup[index]);
   if(!old)return null;
   const family=FAMILIES[index],load=physicalLoadValue(p),oldLoad=physicalLoadValue(old);
   const positional=fitScore(p,family)-fitScore(old,family);
   const physical=Math.round(p.condition-old.condition);
   const fatigue=oldLoad-load;
   // Seuil fixe, reproductible et explicable ; il sert uniquement au tri de suggestions.
   const score=positional+physical*0.25+fatigue*0.15;
   if(score<=0)return null;
   return {id:p.id,name:p.name,slot:index,score,proposal,
    positional,physical,fatigue,condition:p.condition,load};
  }).filter(Boolean).sort((a,b)=>b.score-a.score||a.id.localeCompare(b.id)).slice(0,limit);
}
function lnr05AdviceView(){
 if(!lnr05Enabled())return '';
 const advice=lnr05AdviceCandidates();
 const rows=advice.map(a=>'<li><button type="button" onclick="lnr05Pick(\''+lnr05Escape(a.id)+'\')">'+
  lnr05Escape(a.name)+'</button> · poste '+(a.slot+1)+
  ' · adaptation au poste '+(a.positional>=0?'+':'')+Math.round(a.positional)+
  ', condition '+(a.physical>=0?'+':'')+Math.round(a.physical)+' points'+
  ', charge évitée '+(a.fatigue>=0?'+':'')+Math.round(a.fatigue)+
  ' · '+a.proposal.changes+' changement(s) prévus</li>').join('');
 return '<section class="lnr05-advice" aria-label="Conseils avant-match à 23">'+
  '<h3>Options de rotation avant-match</h3>'+
  '<p class="help">Suggestions calculées à partir des notes au poste, de la condition et de la charge du jeu (toutes simulées). Les compatibilités de poste viennent des règles natives ; aucun bonus tactique chiffré non attesté. Le score ne prédit pas le résultat du match. Le XV reste inchangé jusqu’à confirmation.</p>'+
  (rows?'<ol>'+rows+'</ol><p class="help">Sélectionnez une option pour prévisualiser la feuille et confirmer manuellement.</p>':
   '<p class="help">Aucun remplacement titulaire améliorant ces critères et validé par la feuille native, ou match verrouillé.</p>')+
  '</section>';
}
function lnr05View(){
 if(!lnr05Enabled())return '';
 const roster=club().players.filter(p=>typeof p.id==='string'&&p.id.startsWith('lnr:'));
 const measured=roster.filter(p=>lnr05Proof(p.id)).length;
 const filtered=roster.filter(p=>lnr05Filter==='evidence'?!!lnr05Proof(p.id):
  lnr05Filter==='missing'?!lnr05Proof(p.id):
  lnr05Filter==='physical'?(p.injury||p.condition<70||physicalLoadValue(p)>=55):true);
 const buttons=[['all','Tous'],['evidence','Mesures sourcées'],['missing','Sans mesures'],['physical','À ménager']]
  .map(([key,label])=>'<button type="button" aria-pressed="'+(lnr05Filter===key)+'" class="'+(lnr05Filter===key?'dark':'')+
   '" onclick="lnr05FilterBy(\''+key+'\')">'+label+'</button>').join('');
 const table=filtered.map(p=>{
  const e=lnr05Proof(p.id);
  return '<tr><td><button type="button" class="textbutton" onclick="lnr05Pick(\''+lnr05Escape(p.id)+'\')">'+
   lnr05Escape(p.name)+'</button><small>'+lnr05Escape(p.lnrGroup||p.pos)+'</small></td>'+
   '<td>'+(e?'Fiche LNR':'Groupe LNR seul')+'</td><td>'+lnr05Escape(e?lnr05Measure(e[1],' ans'):'—')+
   '</td><td>'+lnr05Escape(e?lnr05Measure(e[2],' cm'):'—')+
   '</td><td>'+lnr05Escape(e?lnr05Measure(e[3],' kg'):'—')+'</td>'+
   '<td>'+Math.round(p.condition)+' %</td><td>'+physicalLoadValue(p)+'/100</td>'+
   '<td>'+(p.injury?'Blessé':S.lineup.includes(p.id)?'XV':S.reserves.includes(p.id)?'Banc':'Réserve')+'</td></tr>';
 }).join('');
 const selected=lnr05Selected?player(lnr05Selected):null,proof=selected?lnr05Proof(selected.id):null;
 let detail='';
 if(selected){
  const url=proof&&/^https:\/\/(?:top14|prod2)\.lnr\.fr\/joueur\//.test(proof[4])?proof[4]:null;
  const proposal=lnr05Proposal(selected.id);
  const source=url?'<a href="'+lnr05Escape(url)+'" target="_blank" rel="noopener noreferrer">Fiche LNR individuelle</a>':
   'Mesures individuelles non renseignées';
  const status=proposal?.already?'Déjà sur la feuille, poste '+(proposal.slot+1)+'.':
   proposal?.valid?'Proposition native : '+proposal.changes+' place(s) modifiée(s), aucune sauvegarde avant confirmation.':
   'Aucune composition applicable : blessure, indisponibilité ou couverture insuffisante.';
  const accept=proposal?.valid?'<button type="button" class="dark" onclick="lnr05Apply(\''+
   lnr05Escape(selected.id)+'\',\''+proposal.token+'\')">Confirmer la composition à 23</button>':'';
  detail='<div class="lnr05-detail" aria-label="Décision de composition LNR"><h3>'+
   lnr05Escape(selected.name)+'</h3><p>'+source+'</p>'+
   '<p><strong>Faits LNR (31/10/2026) :</strong> âge rapporté '+lnr05Escape(proof?lnr05Measure(proof[1],' ans'):'inconnu')+
   ', taille '+lnr05Escape(proof?lnr05Measure(proof[2],' cm'):'inconnue')+
   ', poids '+lnr05Escape(proof?lnr05Measure(proof[3],' kg'):'inconnu')+'.</p>'+
   '<p><strong>Simulation de carrière :</strong> poste attribué '+lnr05Escape(selected.pos)+
   ', âge de jeu '+selected.age+', note estimée '+roleNote(selected)+', condition '+Math.round(selected.condition)+
   ' %, charge '+physicalLoadValue(selected)+'/100.</p>'+
   '<p class="help">'+lnr05Escape(status)+' Les mesures réelles ne déterminent jamais une aptitude de première ligne ni la note sportive.</p>'+
   '<div class="lnr05-actions">'+accept+
   '<button type="button" onclick="lnr05Compare(\''+lnr05Escape(selected.id)+'\')">Comparer deux joueurs</button>'+
   '<button type="button" onclick="lnr05Sheet()">Ouvrir la feuille à 23</button>'+
   '<button type="button" onclick="lnr05Health()">Gérer la charge</button></div></div>';
 }
 return '<section class="card lnr05-center" aria-label="Cellule LNR de preuves et rotation">'+
  '<div class="cardtitle"><h2>Cellule LNR · preuves et rotation</h2><span class="tag">MODE OPTIONNEL</span></div>'+
  '<p class="help">Dossiers individuels rapprochés : 240 / 1 592 joueurs LNR ; dans ce club : '+measured+
  ' joueurs mesurés. LNR = photographie du 31/10/2026, non certification au 01/07/2026. Notes, poste détaillé, condition, charge et contrats restent simulés.</p>'+
  lnr05AdviceView()+'<div class="lnr05-filters" role="group" aria-label="Filtrer les preuves">'+buttons+'</div>'
  '<div class="lnr05-scroll"><table><thead><tr><th>Joueur</th><th>Source</th><th>Âge LNR</th><th>Taille</th><th>Poids</th><th>Condition*</th><th>Charge*</th><th>Statut*</th></tr></thead><tbody>'+
  table+'</tbody></table></div>'+
  '<p class="help">* Donnée simulée. Cliquez sur un joueur pour comparer, étudier la feuille et demander un remplacement volontaire.</p>'+detail+
  (typeof comparePanel==='function'&&compareIds.length?comparePanel():'')+'</section>';
}
