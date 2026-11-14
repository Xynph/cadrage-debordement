'use strict';
// Composition du staff (carrière Monde) : « Sélection du staff » et feuille des clubs de l'ordinateur.
// Avant la correction, le jumelage des six maillots de première ligne (position-aptitudes.cjs) laissait
// la meilleure place du XV à un pilier ou talonneur plus faible dès qu'une place de banc préférait le
// meilleur : le meilleur pilier gauche finissait remplaçant (Leclerc 79 au banc, Rivero 73 titulaire).
// Règle vérifiée ici, sur le club du manager au début de carrière et après quelques journées, puis sur un
// échantillon de clubs IA : aucun poste de 1 à 15 vide s'il existe un joueur disponible, le n°1, 2 et 3 sont
// les meilleurs disponibles (pondérés par la condition), pas de joueur sous 40 au poste quand un spécialiste
// frais est disponible, banc complet dont la première ligne.
const {test}=require('node:test'),assert=require('node:assert/strict');
const {context}=require('./monde-harness.cjs');

// Joueur disponible : valide et non libéré en sélection nationale à la date du prochain match du club.
const AUDIT=`(function(ci,own){
 const c=S.clubs[ci],NP=nativePositionAptitudes,fx=CDWorldCareer.fixtures(S).find(f=>f.homeId===ci||f.awayId===ci);
 const sheet=own?{lineup:S.lineup,bench:S.reserves}:buildSheet(c);
 const pool=c.players.filter(p=>!p.injury&&!(fx&&CDWorldCareer.clubReleaseOn(S,p.id,fx.date)));
 const byId=new Map(c.players.map(p=>[p.id,p])),inPool=new Set(pool.map(p=>p.id));
 const weighted=(p,slot)=>NP.rating(p,slot)*(.5+p.condition*.005);
 const problems=[],inXV=new Set(sheet.lineup.filter(Boolean)),inGroup=new Set([...sheet.lineup,...sheet.bench].filter(Boolean));
 const name=id=>{const p=byId.get(id);return p?p.name+' ('+p.pos+')':'vide'};
 if(sheet.lineup.length!==15||sheet.bench.length!==8)problems.push('feuille de '+sheet.lineup.length+'+'+sheet.bench.length);
 if(inGroup.size!==sheet.lineup.filter(Boolean).length+sheet.bench.filter(Boolean).length)problems.push('joueur en double');
 for(const id of inGroup)if(!inPool.has(id))problems.push(name(id)+' indisponible dans la feuille');
 sheet.lineup.forEach((id,i)=>{
  const p=byId.get(id);
  if(!p){const free=pool.find(q=>!inXV.has(q.id)&&slotEligible(q,i));if(free)problems.push('n°'+(i+1)+' vide alors que '+free.name+' est disponible');return;}
  const better=pool.filter(q=>q.id!==id&&!inXV.has(q.id)&&(i<3?slotEligible(q,i):q.fam===FAMILIES[i]));
  if(i<3){
   // Clubs de l'ordinateur : la forme récente et la règle JIFF pondèrent aussi leur choix, seul le club du manager est strict.
   if(!own)return;
   const top=better.filter(q=>slotEligible(q,i)&&weighted(q,i)>weighted(p,i)+1e-9)[0];
   if(top)problems.push('n°'+(i+1)+' '+p.name+' ('+Math.round(NP.rating(p,i))+') derrière '+top.name+' ('+Math.round(NP.rating(top,i))+', '+(sheet.bench.includes(top.id)?'au banc':'hors groupe')+')');
  }else{
   const r=NP.rating(p,i);
   const spec=better.filter(q=>q.condition>=60&&(r<40&&NP.rating(q,i)>=40||weighted(q,i)>=weighted(p,i)+15))[0];
   if(spec)problems.push('n°'+(i+1)+' '+p.name+' ('+p.pos+', '+Math.round(r)+') alors que '+spec.name+' ('+Math.round(NP.rating(spec,i))+') est disponible');
  }
 });
 sheet.bench.forEach((id,i)=>{
  if(byId.get(id))return;
  const free=pool.find(q=>!inGroup.has(q.id)&&benchEligible(q,i));
  if(free)problems.push('banc '+(i+16)+' vide alors que '+free.name+' est disponible');
 });
 return {club:c.name,problems,front:[0,1,2].map(i=>sheet.lineup[i]),benchFront:[0,1,2].map(i=>sheet.bench[i])};
})`;

function audit(h,ids,own=-1){
 const rows=h.run('JSON.stringify(('+AUDIT+')&&['+ids.join(',')+'].map(ci=>('+AUDIT+')(ci,ci==='+own+')))');
 return JSON.parse(rows);
}
const failures=rows=>rows.filter(r=>r.problems.length).map(r=>r.club+' : '+r.problems.join(' ; '));
const sample=(h,step=3)=>{const n=h.run('S.clubs.length');return Array.from({length:Math.ceil(n/step)},(_,i)=>i*step);};

test('Monde : la sélection du staff du club du manager est complète et place les meilleurs, dès le début de carrière',()=>{
 const h=context(827381,{club:0,console:false});
 try{
  const club=h.run('S.club');
  h.run('autoLineup()');
  assert.deepEqual(failures(audit(h,[club],club)),[],'sélection initiale');
  // Régression : le meilleur pilier gauche, talonneur et pilier droit ouvrent le match, les suivants sont au banc.
  const front=JSON.parse(h.run(`JSON.stringify((()=>{const NP=nativePositionAptitudes,c=club();
   const ok=p=>!p.injury;return [0,1,2].map(i=>{const spec=c.players.filter(p=>ok(p)&&slotEligible(p,i)).sort((a,b)=>NP.rating(b,i)-NP.rating(a,i));
    return {best:spec[0]?.id,starter:S.lineup[i],bestRating:NP.rating(spec[0],i),starterRating:NP.rating(c.players.find(p=>p.id===S.lineup[i]),i)};});})())`));
  front.forEach((row,i)=>assert.equal(row.starter,row.best,'n°'+(i+1)+' : le meilleur disponible ouvre le match ('+row.starterRating+' contre '+row.bestRating+')'));
  const groupe=h.run('[...S.lineup,...S.reserves].filter(Boolean).length');
  assert.equal(groupe,23,'23 joueurs sélectionnés');
  // Départ du coordinateur : un troisième ligne posé à l'ouverture à la main, « Sélection du staff » le remplace
  // par l'ouvreur du groupe (poste naturel, frais) au lieu de le laisser à 14 au poste.
  h.run('{const c=club(),NP=nativePositionAptitudes,back=c.players.find(p=>p.fam===3&&!S.lineup.includes(p.id));S.lineup[9]=back.id;autoLineup();}');
  const ouvreur=JSON.parse(h.run('JSON.stringify((()=>{const c=club(),p=c.players.find(x=>x.id===S.lineup[9]);return {fam:p.fam,rating:nativePositionAptitudes.rating(p,9),best:Math.max(...c.players.filter(q=>!q.injury&&q.fam===5).map(q=>nativePositionAptitudes.rating(q,9)))};})())'));
  assert.equal(ouvreur.fam,5,'un ouvreur occupe le n°10');
  assert.ok(ouvreur.rating>=ouvreur.best-15,'l\'ouvreur retenu est parmi les meilleurs ('+ouvreur.rating+' contre '+ouvreur.best+')');
  // Le n°1 blessé : le suivant le remplace, aucun poste ne reste vide.
  h.run('{const c=club();c.players.find(p=>p.id===S.lineup[0]).injury=3;autoLineup();}');
  assert.deepEqual(failures(audit(h,[club],club)),[],'après la blessure du n°1');
  assert.ok(h.run('S.lineup[0]&&!club().players.find(p=>p.id===S.lineup[0]).injury'),'le n°1 est pourvu par un joueur valide');
 }finally{h.close();}
});

test('Monde : la composition reste complète après quelques journées, club du manager et échantillon de clubs IA',()=>{
 const h=context(827381,{club:0,console:false});
 try{
  const club=h.run('S.club'),ids=sample(h);
  assert.deepEqual(failures(audit(h,ids,club)),[],'échantillon au début de carrière');
  for(const weeks of [3,4]){
   h.week(weeks,{validate:false});
   h.run('autoLineup()');
   assert.deepEqual(failures(audit(h,ids,club)),[],'échantillon à la journée '+h.run('S.round'));
  }
 }finally{h.close();}
});

test('Monde : la composition du staff est déterministe',()=>{
 const trace=()=>{const h=context(827381,{club:0,console:false});
  try{h.run('autoLineup()');return h.run('JSON.stringify([S.lineup,S.reserves,S.clubs.filter((c,i)=>i%7===0).map(c=>buildSheet(c))])');}finally{h.close();}};
 assert.equal(trace(),trace());
});

test('Monde : après l\'attribution optimale des postes, un club français respecte toujours le seuil JIFF de la feuille',()=>{
 const h=context(827381,{club:0,console:false});
 try{
  h.week(2,{validate:false});
  assert.equal(h.run('typeof CDJiff!=="undefined"&&typeof CDJiff.comply==="function"'),true,'CDJiff.comply est accessible depuis le moteur');
  // Les statuts s'initialisent à la 1re journée validée ; on les pose ici pour auditer toutes les feuilles.
  h.run('CDJiff.initialize(S)');
  // La feuille du manager date d'avant ces statuts : « Sélection du staff » la recompose.
  h.run('autoLineup()');
  assert.equal(h.run('!!S.jiff&&S.jiff.version===1'),true,'la règle JIFF est active en carrière Monde');
  const rows=JSON.parse(h.run(`JSON.stringify(Object.values(CDJiff.subjectLeagues(S)).flat().map(ci=>{
   const c=S.clubs[ci],sheet=ci===S.club?{lineup:S.lineup,bench:S.reserves}:buildSheet(c);
   const ids=[...sheet.lineup,...sheet.bench].filter(Boolean),byId=new Map(c.players.map(p=>[p.id,p]));
   const pool=c.players.filter(p=>!p.injury&&CDJiff.isJiff(S,p)).length;
   return {club:c.name,count:ids.filter(id=>CDJiff.isJiff(S,byId.get(id))).length,pool};}))`));
  assert.ok(rows.length>=28,'les clubs soumis à la règle sont contrôlés');
  const bad=rows.filter(r=>r.count<Math.min(16,r.pool));
  assert.deepEqual(bad,[],'chaque feuille compte au moins 16 JIFF (ou tous ceux disponibles)');
 }finally{h.close();}
});
