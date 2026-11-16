'use strict';
// Championnats suivis en détail / suivis de loin (décision de Léo du 16/11/2026), carrière world-champ :
// - réglage par défaut : championnat du club, coupes d'Europe où il est engagé, phases finales et
//   clubs des joueurs suivis au recrutement toujours en détail ;
// - déterminisme : chaque rencontre de l'IA a son flux de hasard dès qu'un championnat est suivi de
//   loin ; changer le suivi d'un championnat ne touche pas les autres tant qu'ils ne se rencontrent pas ;
// - tout suivre en détail reste identique au comportement historique (flux unique, même empreinte).
// Quatre carrières l'une après l'autre (jamais deux en mémoire) : la mémoire d'une carrière fermée
// est rendue avant la suivante (machines de 8 Go partagées).
const test=require('node:test');
const assert=require('node:assert/strict');
const crypto=require('node:crypto');
const v8=require('node:v8');
v8.setFlagsFromString('--expose_gc');
const collect=require('node:vm').runInNewContext('gc');
const {context}=require('./monde-harness.cjs');

const ALL=['elite','accession','nationale','prem','champ','urc','srp','jlo-d1','jlo-d2'];
const hash=text=>crypto.createHash('sha256').update(text).digest('hex').slice(0,16);
// Résultats par compétition (rencontre, score, essais) et état complet hors réglage.
function trace(h){
 const leagues=JSON.parse(h.run(`JSON.stringify((()=>{const out={};for(const r of S.history)(out[r.competitionId]||(out[r.competitionId]=[])).push([r.fixtureId,r.score,r.tries]);return out;})())`));
 return {leagues:Object.fromEntries(Object.entries(leagues).map(([k,v])=>[k,hash(JSON.stringify(v))])),
  counts:Object.fromEntries(Object.entries(leagues).map(([k,v])=>[k,v.length])),
  own:hash(h.run('JSON.stringify(S.history.filter(r=>r.pair.includes(S.club)).map(r=>[r.score,r.stats]))')),
  state:hash(h.run('JSON.stringify({...S,leagueDetail:undefined})')),seed:h.seed()};
}
// Carrière du club 0 (Élite), `weeks` semaines avancées, puis `inspect(h)` avant fermeture.
function played(detailed,weeks,inspect=()=>null){
 const h=context(827381,{club:0,console:false,career:detailed?{detailedLeagues:detailed}:{}});
 try{
  const extra=inspect(h,'before');
  h.week(weeks,{validate:false});h.run('validateCareer(S)');
  return {...trace(h),salt:detailed?h.run('S.leagueDetail.salt'):null,extra,after:inspect(h,'after')};
 }finally{h.close();collect();}
}

test('Tout suivre en détail : même carrière, même flux de hasard que sans réglage',()=>{
 const legacy=played(null,3),all=played(ALL,3);
 for(const key of ['leagues','counts','own','state','seed'])assert.deepEqual(all[key],legacy[key],'identique au comportement historique : '+key);
});

// Règles de suivi, lues dans la carrière du réglage par défaut avant la première semaine.
const RULES=`JSON.stringify((()=>{
 const F=S.worldMode.fixtures,q=f=>CDLeagueDetail.quickFixture(S,f),cups=['champions','challenge'];
 const europe=cups.filter(id=>F.some(f=>f.competitionId===id&&(f.homeId===S.club||f.awayId===S.club)));
 const elite=S.worldMode.leagues.elite.members,premFixture=F.find(f=>f.competitionId==='prem'&&f.phase==='league');
 const prem=q(premFixture);
 if(!S.manager)S.manager={};const saved=S.manager.watch;
 S.manager.watch=[S.clubs[premFixture.homeId].players[0].id];const watched=q(premFixture);
 if(saved===undefined)delete S.manager.watch;else S.manager.watch=saved;
 return {europe,projected:CDLeagueDetail.project().europe,
  ownEurope:F.filter(f=>europe.includes(f.competitionId)&&f.phase==='pool').some(q),
  otherEurope:F.filter(f=>cups.includes(f.competitionId)&&!europe.includes(f.competitionId)&&f.phase==='pool').every(f=>q(f)===[f.homeId,f.awayId].every(id=>!elite.includes(id))),
  elite:F.filter(f=>f.competitionId==='elite').some(q),knockout:F.filter(f=>!['league','pool'].includes(f.phase)).some(q),
  prem,watched,separated:CDLeagueDetail.separated(S),detailed:CDLeagueDetail.project().leagues.filter(l=>l.detailed).map(l=>l.id)};
})())`;

test('Réglage par défaut, déterminisme entre réglages et migration de la version 1',()=>{
 // Huit semaines : aucune rencontre entre clubs de championnats différents (poules européennes en semaine 9).
 const base=played([],8,(h,when)=>{
  if(when==='before')return JSON.parse(h.run(RULES));
  // Réglage de la version 1 (13/11) : accepté tel quel, puis flux séparé au changement de saison.
  h.run("S.leagueDetail={version:1,policy:'league-detail-v1',detailed:['elite','urc'],pending:['elite']};validateCareer(S);CDLeagueDetail.applyPending(S);validateCareer(S)");
  const st=JSON.parse(h.run('JSON.stringify(S.leagueDetail)'));
  // Une carrière sans réglage (anciennes sauvegardes) reste entièrement en détail, au flux unique.
  h.run('delete S.leagueDetail;validateCareer(S)');
  return {st,legacy:h.run('CDLeagueDetail.separated(S)||S.worldMode.fixtures.some(f=>CDLeagueDetail.quickFixture(S,f))')};
 });
 const rules=base.extra;
 assert.deepEqual(rules.detailed,['elite'],'liste vide : le championnat du club reste suivi en détail');
 assert.ok(rules.europe.length>0,'le club de l’Élite est engagé en coupe d’Europe');
 assert.deepEqual(rules.projected,rules.europe,'coupes d’Europe du club annoncées à l’interface');
 assert.equal(rules.ownEurope,false,'coupe d’Europe du club : toutes ses poules en détail');
 assert.equal(rules.otherEurope,true,'autre coupe : en détail seulement pour les clubs d’un championnat suivi');
 assert.equal(rules.elite,false);assert.equal(rules.knockout,false,'phases finales jamais suivies de loin');
 assert.equal(rules.prem,true,'PREM suivie de loin');
 assert.equal(rules.watched,false,'club d’un joueur suivi au recrutement : rencontre en détail');
 assert.equal(rules.separated,true,'flux séparés dès qu’un championnat est suivi de loin');
 assert.equal(base.after.st.version,2);assert.deepEqual(base.after.st.detailed,['elite']);assert.equal(base.after.st.pending,null);
 assert.ok(Number.isInteger(base.after.st.salt)&&base.after.st.salt>=0,'graine du flux attribuée à la migration');
 assert.equal(base.after.legacy,false,'sans réglage : tout en détail');

 const prem=played(['elite','prem'],8);
 assert.equal(prem.salt,base.salt,'même graine de carrière, même graine de flux');
 assert.ok(base.counts.prem>0&&base.counts.elite>0&&base.counts.urc>0,'championnats joués');
 assert.equal(base.counts.champions,undefined,'pas encore de coupe d’Europe');
 for(const id of Object.keys(base.leagues)){
  if(id==='prem')assert.notEqual(prem.leagues.prem,base.leagues.prem,'la PREM passe au moteur complet');
  else assert.equal(prem.leagues[id],base.leagues[id],'résultats inchangés : '+id);
 }
 assert.equal(prem.own,base.own,'matchs et statistiques du club du manager inchangés');
 assert.equal(prem.seed,base.seed,'le flux principal n’avance pas avec les matchs de l’IA');
});
