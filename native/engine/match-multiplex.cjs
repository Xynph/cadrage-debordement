'use strict';
// Multiplex des autres matchs de la journée et classement en direct « si ça finit ainsi »
// (carrière Monde), affichés dans `live.direct.journee` (match-direct.cjs).
//
// Déroulé anticipé : au premier affichage du direct après le coup d'envoi, chaque autre
// rencontre de notre compétition et de notre journée est jouée par le même chemin qu'à la
// validation (`simulate` de world-career.cjs, donc CDLeagueDetail.play), sur une copie de la
// carrière : blessures, moral, fatigue et feuilles de l'IA ne touchent pas `S`. Le hasard de
// chaque rencontre est isolé (flux propre à la rencontre, Math.random rendu ensuite) : le flux
// principal n'avance pas, notre match se joue comme sans multiplex. Le déroulé (score et essais
// minute par minute) reste dans la mémoire du moteur, jamais dans la sauvegarde.
//
// Validation (finishWeek) : une rencontre au déroulé connu est rejouée sur la vraie carrière
// avec le même flux (effets appliqués une seule fois, comme avant) ; son résultat officiel est
// celui du déroulé affiché. Quand un championnat est suivi de loin (CDLeagueDetail.separated),
// le flux est déjà propre à chaque rencontre : avec ou sans multiplex, les résultats sont
// identiques. Sans déroulé (ancienne carrière, match délégué, reprise), rien ne change.
const files=Object.freeze([]),commands=Object.freeze([]);

function factory(){
 // `preparing` : déroulé anticipé en cours sur la copie de la carrière (les fonctions du moteur appelées
 // pendant ce temps travaillent sur la copie ; un observateur des effets réels doit les ignorer).
 let enabled=true,cache=null,preparing=false;
 const counters={prepared:0,consumed:0,divergences:0};
 const world=s=>!!s&&typeof CDWorldCareer!=='undefined'&&CDWorldCareer.active(s)&&!!s.worldMode;
 const copy=x=>typeof nativeJsonCopy==='function'?nativeJsonCopy(x):JSON.parse(JSON.stringify(x));
 // Brassage 32 bits (même recette que league-detail.cjs) : graine du flux d'une rencontre.
 function mix(text){
  let h=0x811c9dc5;for(let i=0;i<text.length;i++){h^=text.charCodeAt(i);h=Math.imul(h,0x01000193)>>>0;}
  h^=h>>>16;h=Math.imul(h,0x85ebca6b)>>>0;h^=h>>>13;h=Math.imul(h,0xc2b2ae35)>>>0;h^=h>>>16;return h>>>0;
 }
 const seedOf=(s,f)=>mix('cd-multiplex|'+s.club+'|'+s.season+'|'+f.id+'|'+f.competitionId);
 function withStream(seed,fn){
  let x=seed;const prior=Math.random;
  Math.random=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296;};
  try{return fn();}finally{Math.random=prior;}
 }
 const keyOf=(s,own)=>[s.season,s.round,s.club,own.id].join('|');
 function ownFixture(s){
  if(!world(s))return null;
  try{return CDWorldCareer.userFixture(s);}catch{return null;}
 }
 const others=(s,own)=>CDWorldCareer.fixtures(s).filter(f=>f.competitionId===own.competitionId&&f.id!==own.id&&!s.history.some(r=>r.fixtureId===f.id));
 // Score et essais relevés après chaque minute jouée, à l'horloge du direct (match-highlights.cjs,
 // normaliser : en seconde période, 40 + minute - minute de la mi-temps).
 function recorder(){
  let fin=null,seen=0,end=0,steps=0;const rows=[[0,0,0,0,0]];
  return {
   step(l){
    steps++;
    for(;seen<l.events.length;seen++){const e=l.events[seen];if(fin===null&&(e?.type==='break'||e?.scene?.kind==='break'))fin=Number.isFinite(e.min)?e.min:l.minute;}
    const m=fin===null?l.minute:40+l.minute-fin,last=rows[rows.length-1];
    if(l.score[0]!==last[1]||l.score[1]!==last[2]||l.tries[0]!==last[3]||l.tries[1]!==last[4])rows.push([m,l.score[0],l.score[1],l.tries[0],l.tries[1]]);
    end=Math.max(end,m);
   },
   done(r,seed){
    // Rencontre suivie de loin (sans moteur minute par minute) : points répartis sur le match.
    if(!steps)return synthetic(r,seed);
    const last=rows[rows.length-1];
    if(last[1]!==r.score[0]||last[2]!==r.score[1]||last[3]!==r.tries[0]||last[4]!==r.tries[1])rows.push([end,r.score[0],r.score[1],r.tries[0],r.tries[1]]);
    return {rows,end:Math.max(end,80)};
   }
  };
 }
 function synthetic(r,seed){
  let x=seed^0x5bd1e995;const next=()=>{x=(Math.imul(x,1664525)+1013904223)>>>0;return x/4294967296;};
  const units=[];
  for(const side of [0,1]){
   const st=r.stats?.[side]||{},tries=r.tries[side],conv=Math.min(tries,st.conversions||0);
   let rest=r.score[side]-tries*5-conv*2;
   for(let i=0;i<tries;i++)units.push({side,points:i<conv?7:5,try:1});
   while(rest>=3){units.push({side,points:3,try:0});rest-=3;}
   if(rest>0)units.push({side,points:rest,try:0});
  }
  const timed=units.map(u=>({...u,minute:1+Math.floor(next()*79)})).sort((a,b)=>a.minute-b.minute);
  const rows=[[0,0,0,0,0]],acc=[0,0,0,0];
  for(const u of timed){acc[u.side]+=u.points;acc[2+u.side]+=u.try;rows.push([u.minute,acc[0],acc[1],acc[2],acc[3]]);}
  return {rows,end:80};
 }
 // Déroulé anticipé des autres rencontres de notre compétition (copie de la carrière, hasard isolé).
 function prepare(){
  const s=typeof S==='undefined'?null:S;
  if(!enabled||!world(s)||!s.live||s.live.finished)return null;
  if(typeof nativePayload!=='undefined'&&nativePayload&&nativePayload.delegated===true)return null;
  const own=ownFixture(s);
  if(!own||!Array.isArray(s.live.pair)||s.live.pair[0]!==own.homeId||s.live.pair[1]!==own.awayId)return null;
  const key=keyOf(s,own);
  if(cache?.key===key)return cache;
  const list=others(s,own),matchs=new Map(),real=s,shadow=copy(real);
  S=shadow;preparing=true;
  try{
   const W=CDWorldCareer.multiplex(shadow);
   for(const f of list){
    const seed=seedOf(real,f),rec=recorder();
    const result=withStream(seed,()=>W.simulate(f,rec.step));
    matchs.set(f.id,{fixture:copy(f),result,timeline:rec.done(result,seed)});
   }
  }finally{S=real;preparing=false;}
  counters.prepared++;
  cache={key,ownId:own.id,competitionId:own.competitionId,phase:own.phase,matchs};
  return cache;
 }
 // Validation : résultat officiel = déroulé affiché ; la rencontre est rejouée sur la vraie
 // carrière avec le même flux pour en appliquer les effets une fois.
 function official(s,f,run){
  const own=ownFixture(s);
  if(!cache||!own||cache.key!==keyOf(s,own)||!cache.matchs.has(f.id))return run();
  const x=cache.matchs.get(f.id);cache.matchs.delete(f.id);if(!cache.matchs.size)cache=null;
  const r=withStream(seedOf(s,f),run);
  if(JSON.stringify(r)===JSON.stringify(x.result)){counters.consumed++;return r;}
  counters.divergences++;return copy(x.result);
 }
 function stateAt(rows,minute){let row=rows[0];for(const r of rows){if(r[0]<=minute)row=r;else break;}return row;}
 // Multiplex et classement à la minute montrée de notre match (`minute`, `score`, `essais` lus
 // dans le journal déjà montré ; `fini` : tout le match a été montré).
 function journee(minute,fini,score,essais){
  const s=typeof S==='undefined'?null:S;
  if(!enabled||!world(s)||!s.live)return null;
  const own=ownFixture(s);if(!own)return null;
  const c=cache?.key===keyOf(s,own)?cache:prepare();
  if(!c)return null;
  const m=Math.max(0,Number(minute)||0),W=CDWorldCareer.multiplex(s);
  const club=id=>({id,abbr:s.clubs[id]?.abbr||'',nom:s.clubs[id]?.name||''});
  const matchs=[],provisional=[];
  for(const x of c.matchs.values()){
   const over=fini===true||m>=x.timeline.end,row=over?x.timeline.rows[x.timeline.rows.length-1]:stateAt(x.timeline.rows,m);
   const sc=[row[1],row[2]],tr=[row[3],row[4]],f=x.fixture;
   matchs.push({id:f.id,home:{...club(f.homeId),score:sc[0],essais:tr[0]},away:{...club(f.awayId),score:sc[1],essais:tr[1]},minute:over?x.timeline.end:Math.min(m,x.timeline.end),fini:over});
   provisional.push(W.entry(f,{...x.result,score:sc,tries:tr}));
  }
  let classement=[];
  if(c.phase==='league'&&Object.hasOwn(s.worldMode.leagues,c.competitionId)){
   const ours=[Math.max(0,score?.[0]|0),Math.max(0,score?.[1]|0)],ourTries=[Math.max(0,essais?.[0]|0),Math.max(0,essais?.[1]|0)];
   provisional.push(W.entry(own,{...W.live(),score:ours,tries:ourTries}));
   const before=new Map(CDWorldCareer.rows(s,c.competitionId).map((r,i)=>[r.clubId,i+1]));
   classement=W.rows(c.competitionId,provisional).map((r,i)=>({rang:i+1,clubId:r.clubId,abbr:club(r.clubId).abbr,nom:club(r.clubId).nom,joues:r.played,points:r.points,diff:r.diff??(r.pf-r.pa),
    bonusOff:r.offensiveBonus??null,bonusDef:r.defensiveBonus??null,rangOfficiel:before.get(r.clubId)??null,delta:before.has(r.clubId)?before.get(r.clubId)-(i+1):0,nous:r.clubId===s.club}));
  }
  return {minute:m,matchs,classement};
 }
 return {
  project(){return null;},validate(){return true;},execute(){throw Error('Multiplex : aucune commande.');},installHooks(){return true;},
  prepare,official,journee,preparing(){return preparing;},
  // Essais et mesures : interrupteur (référence « sans multiplex ») et compteurs.
  setEnabled(value){if(typeof value!=='boolean')throw Error('Multiplex : drapeau invalide.');enabled=value;if(!value)cache=null;},
  counters(){return {...counters,cached:cache?cache.matchs.size:0};}
 };
}
module.exports={files,commands,factory};
