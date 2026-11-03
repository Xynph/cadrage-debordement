'use strict';
// Additive V60 interactive press conference, leaves legacy V60 state intact.
(function(root){
const bank=root.CDPressQuestionBank;
if(!bank)return;
let pending=null,answers=[];
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const current=()=>typeof S==='undefined'?null:S;
const toneEffect={confident:{morale:2,media:-1,fans:3,pressure:2},honest:{morale:1,media:3,fans:1,pressure:-1},aggressive:{morale:-2,media:-3,fans:2,pressure:3},cautious:{morale:0,media:1,fans:-1,pressure:-2}};
function snapshot(s){const v=s.pressConference;return v&&Array.isArray(v.history)?v:{version:1,history:[]};}
function validate(s){
if(!s.pressConference)return true;
const v=s.pressConference;if(v.version!==1||!Array.isArray(v.history)||v.history.length>500)throw Error('Historique de presse invalide');
for(const h of v.history)if(!h||!bank.questions.some(q=>q.id===h.id)||!Number.isInteger(h.season)||!Number.isInteger(h.week)||!['r0','r1','r2','r3'].includes(h.answerId))throw Error('Choix de presse invalide');
return true;
}
function chooseThemes(s){const t=['avant_match','attaque','defense','joueurs','supporters','calendrier','carriere'];
if((s.trust??50)<40)t.unshift('direction','crise');
if((s.morale??50)<45)t.unshift('vestiaire','rotation','blessures');
if((s.round??0)>19)t.unshift('classement','phase_finale');
return [...new Set(t)];}
function prepare(s){
if(!s||s.live)return null;
validate(s);
const old=snapshot(s),season=s.season,week=s.round;
if(old.history.some(h=>h.season===season&&h.week===week))return null;
return bank.pick({season,week,history:old.history,context:{themes:chooseThemes(s)},count:2+((week+season)%3),seed:s.club});
}
function apply(s,selected){
if(!s||s.live||!Array.isArray(selected)||selected.length<2||selected.length>4)throw Error('Conférence invalide');
validate(s);const original=JSON.stringify(s),questions=prepare(s);
if(!questions||questions.length!==selected.length)throw Error('Conférence déjà réalisée');
for(let i=0;i<questions.length;i++)if(!questions[i].answers.some(a=>a.id===selected[i]))throw Error('Réponse invalide');
try {
let state=s.pressRelations||root.CDPressRelations.create('club-'+s.club);
while(state.season<s.season)state=root.CDPressRelations.nextSeason(state);
let moraleDelta=0,trustDelta=0;
for(let i=0;i<questions.length;i++){
const q=questions[i],choice=q.answers.find(a=>a.id===selected[i]),fx=toneEffect[choice.tone];
const mod=(q.theme==='crise'||q.theme==='direction')?2:1;
state.mediaTrust=Math.max(0,Math.min(100,state.mediaTrust+fx.media*mod));
state.fanTrust=Math.max(0,Math.min(100,state.fanTrust+fx.fans*mod));
state.boardPressure=Math.max(0,Math.min(100,state.boardPressure+fx.pressure*mod));
state.morale=Math.max(0,Math.min(100,state.morale+fx.morale*mod));
moraleDelta+=fx.morale*mod;trustDelta-=fx.pressure*mod;
}
s.pressConference={version:1,history:questions.reduce((hist,q,i)=>bank.appendHistory(hist,q,s.season,s.round,selected[i]),snapshot(s).history)};
s.pressRelations=state;s.morale=Math.max(0,Math.min(100,(s.morale??50)+moraleDelta));s.trust=Math.max(0,Math.min(100,(s.trust??50)+trustDelta));
validate(s);if(typeof save==='function')save();if(typeof lastSaveError!=='undefined'&&lastSaveError)throw Error('Échec sauvegarde');
if(typeof render==='function')render();return true;
}catch(error){const old=JSON.parse(original);for(const k of ['pressConference','pressRelations','morale','trust']){if(Object.prototype.hasOwnProperty.call(old,k))s[k]=old[k];else delete s[k];}throw error;}
}
function view(){const s=current();if(!s||!root.managerOffice)return '';if(!pending||pending.season!==s.season||pending.week!==s.round||pending.club!==s.club){pending={season:s.season,week:s.round,club:s.club,questions:prepare(s)};answers=[];}
const qs=pending.questions;if(!qs)return '<section class="card"><h3>Conférence interactive</h3><p>Conférence déjà tenue cette semaine ou rencontre en cours.</p></section>';
return '<section class="card" id="cd-v60-rich"><h3>Conférence de presse interactive</h3><p>Questions fictives de simulation : aucune citation réelle ni affiliation officielle des journalistes.</p><p>'+qs.length+' questions. Choisissez une des quatre réponses pour chacune.</p>'+qs.map((q,i)=>'<fieldset><legend>'+esc(q.journalist.name)+' ('+esc(q.journalist.outlet)+') : '+esc(q.question)+'</legend>'+q.answers.map(a=>'<label style="display:block;margin:.4em 0"><input type="radio" name="v60-answer-'+i+'" value="'+esc(a.id)+'" '+(answers[i]===a.id?'checked':'')+' data-v60-answer="'+i+'"> '+esc(a.text)+'</label>').join('')+'</fieldset>').join('')+'<button type="button" data-v60-submit '+(qs.every((_,i)=>answers[i])?'':'disabled')+'>Publier mes réponses</button></section>';
}
if(typeof document!=='undefined'){
document.addEventListener('change',e=>{const el=e.target;if(!el||!el.hasAttribute?.('data-v60-answer'))return;answers[Number(el.getAttribute('data-v60-answer'))]=el.value;const b=document.querySelector('#cd-v60-rich [data-v60-submit]');if(b)b.disabled=!pending.questions.every((_,i)=>answers[i]);});
document.addEventListener('click',e=>{if(!e.target?.matches?.('#cd-v60-rich [data-v60-submit]'))return;try{apply(current(),answers);pending=null;answers=[];}catch(error){if(typeof toast==='function')toast(error.message);}});
}
function install(){if(typeof root.managerOffice!=='function'||root.managerOffice.__richV60)return false;const previous=root.managerOffice;const wrapped=function(){return previous()+view();};wrapped.__richV60=true;root.managerOffice=wrapped;return true;}
const api=Object.freeze({validate,prepare,apply,install});
root.CDV60RichPress=api;if(typeof module==='object'&&module.exports)module.exports=api;install();
})(typeof globalThis==='object'?globalThis:window);
